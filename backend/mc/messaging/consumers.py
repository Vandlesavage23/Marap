"""Realtime chat over WebSocket (Bible §9.1).

1. Client connects and must send `{"type":"auth","token":"<access_jwt>"}` within WS_AUTH_TIMEOUT_SECONDS,
   else the socket is closed with 4401.
2. Authenticated sockets join group `user.<account_id>`; server events arrive as group messages.
3. Frames: msg.send / msg.read from the client; msg.ack / msg.error / msg.new / msg.read / match.ended
   from the server; ping/pong both ways (server pings every WS_PING_SECONDS and re-validates the session).
"""

import asyncio
import contextlib
import uuid
from typing import Any

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.conf import settings

from mc.common import presence
from mc.common.errors import DomainError, TokenExpired, Unauthenticated

CLOSE_UNAUTHENTICATED = 4401
CLOSE_SESSION_ENDED = 4403


def group_name(account_id: uuid.UUID | str) -> str:
    return f"user.{account_id}"


class ChatConsumer(AsyncJsonWebsocketConsumer):
    account: Any = None
    session_id: uuid.UUID | None = None
    socket_id: str = ""

    async def connect(self) -> None:
        self.socket_id = uuid.uuid4().hex
        await self.accept()
        self._auth_task = asyncio.create_task(self._auth_deadline())

    async def _auth_deadline(self) -> None:
        await asyncio.sleep(settings.WS_AUTH_TIMEOUT_SECONDS)
        if self.account is None:
            await self.close(code=CLOSE_UNAUTHENTICATED)

    async def disconnect(self, code: int) -> None:
        for task in ("_auth_task", "_ping_task"):
            t = getattr(self, task, None)
            if t:
                t.cancel()
                with contextlib.suppress(asyncio.CancelledError, Exception):
                    await t
        if self.account is not None:
            await self.channel_layer.group_discard(group_name(self.account.id), self.channel_name)
            await database_sync_to_async(presence.remove)(self.account.id, self.socket_id)

    async def receive_json(self, content: dict[str, Any], **kwargs: Any) -> None:
        kind = content.get("type") if isinstance(content, dict) else None
        if self.account is None:
            if kind != "auth":
                await self.close(code=CLOSE_UNAUTHENTICATED)
                return
            await self._authenticate(content.get("token"))
            return
        await database_sync_to_async(presence.touch)(self.account.id, self.socket_id)
        if kind == "ping":
            await self.send_json({"type": "pong"})
        elif kind == "pong":
            return
        elif kind == "msg.send":
            await self._handle_send(content)
        elif kind == "msg.read":
            await self._handle_read(content)
        else:
            await self.send_json({"type": "error", "code": "validation_error"})

    async def _authenticate(self, token: Any) -> None:
        from mc.accounts import selectors as account_selectors

        try:
            if not isinstance(token, str):
                raise Unauthenticated()
            self.account, session = await database_sync_to_async(
                account_selectors.authenticate_access_token
            )(token)
        except (Unauthenticated, TokenExpired):
            await self.close(code=CLOSE_UNAUTHENTICATED)
            return
        self.session_id = session.id
        self._auth_task.cancel()
        await self.channel_layer.group_add(group_name(self.account.id), self.channel_name)
        await database_sync_to_async(presence.touch)(self.account.id, self.socket_id)
        self._ping_task = asyncio.create_task(self._ping_loop())
        await self.send_json({"type": "auth.ok"})

    async def _ping_loop(self) -> None:
        from mc.accounts import selectors as account_selectors

        while True:
            await asyncio.sleep(settings.WS_PING_SECONDS)
            live = await database_sync_to_async(account_selectors.session_is_live)(self.session_id)
            if not live:
                await self.close(
                    code=CLOSE_SESSION_ENDED
                )  # logout / revoke / suspension ends the socket
                return
            await database_sync_to_async(presence.touch)(self.account.id, self.socket_id)
            await self.send_json({"type": "ping"})

    # ---- client → server ------------------------------------------------------------------------
    async def _handle_send(self, c: dict[str, Any]) -> None:
        cid = c.get("client_msg_id")
        try:
            result = await database_sync_to_async(self._send_sync)(c)
        except DomainError as exc:
            await self.send_json({"type": "msg.error", "client_msg_id": cid, "code": exc.code})
            return
        except (ValueError, TypeError, KeyError):
            await self.send_json(
                {"type": "msg.error", "client_msg_id": cid, "code": "validation_error"}
            )
            return
        await self.send_json({"type": "msg.ack", **result})

    def _send_sync(self, c: dict[str, Any]) -> dict[str, Any]:
        from mc.messaging import services

        msg, _ = services.send_message(
            sender=self.account,
            match_id=uuid.UUID(str(c["match_id"])),
            client_msg_id=uuid.UUID(str(c["client_msg_id"])),
            kind=c.get("kind", ""),
            body=c.get("body"),
            media_id=uuid.UUID(str(c["media_id"])) if c.get("media_id") else None,
        )
        return {
            "client_msg_id": str(msg.client_msg_id),
            "id": str(msg.id),
            "created_at": msg.created_at.isoformat().replace("+00:00", "Z"),
        }

    async def _handle_read(self, c: dict[str, Any]) -> None:
        try:
            await database_sync_to_async(self._read_sync)(c)
        except DomainError as exc:
            await self.send_json({"type": "error", "code": exc.code})
        except (ValueError, TypeError, KeyError):
            await self.send_json({"type": "error", "code": "validation_error"})

    def _read_sync(self, c: dict[str, Any]) -> None:
        from mc.messaging import services

        services.mark_read(
            account=self.account,
            match_id=uuid.UUID(str(c["match_id"])),
            up_to_message_id=uuid.UUID(str(c["up_to_message_id"])),
        )

    # ---- server → client (channel-layer group messages) ---------------------------------------------
    async def chat_message(self, event: dict[str, Any]) -> None:
        await self.send_json({"type": "msg.new", "message": event["message"]})
        await database_sync_to_async(self._delivered_sync)(event["message"]["id"])

    @staticmethod
    def _delivered_sync(message_id: str) -> None:
        from mc.messaging import services

        services.mark_delivered(message_id=uuid.UUID(message_id))

    async def chat_read(self, event: dict[str, Any]) -> None:
        await self.send_json({"type": "msg.read", **event["data"]})

    async def chat_match_ended(self, event: dict[str, Any]) -> None:
        await self.send_json({"type": "match.ended", "match_id": event["match_id"]})
