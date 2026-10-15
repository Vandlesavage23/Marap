import asyncio
import uuid

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from config.asgi import application
from mc.accounts import services as account_services
from mc.common import presence
from mc.messaging.models import Message

from .helpers import matched

pytestmark = [pytest.mark.django_db(transaction=True), pytest.mark.asyncio]
HOST = [(b"host", b"api.mc.test")]


def token(who) -> str:
    return who[1].json()["access"]


async def connect(who=None, *, auth=True, headers=None):
    comm = WebsocketCommunicator(application, "/ws/chat", headers=headers or HOST)
    ok, _ = await comm.connect()
    assert ok
    if who is not None and auth:
        await comm.send_json_to({"type": "auth", "token": token(who)})
        assert (await comm.receive_json_from())["type"] == "auth.ok"
    return comm


async def make_match():
    return await database_sync_to_async(matched)()


async def test_auth_required_within_timeout(settings):
    settings.WS_AUTH_TIMEOUT_SECONDS = 0.2
    comm = await connect()
    out = await comm.receive_output(timeout=2)
    assert out["type"] == "websocket.close" and out["code"] == 4401


async def test_bad_token_and_non_auth_first_frame_close_4401():
    comm = await connect()
    await comm.send_json_to({"type": "auth", "token": "garbage"})
    assert (await comm.receive_output(timeout=2))["code"] == 4401
    comm2 = await connect()
    await comm2.send_json_to({"type": "msg.send", "match_id": str(uuid.uuid4())})
    assert (await comm2.receive_output(timeout=2))["code"] == 4401


async def test_unknown_host_rejected():
    comm = WebsocketCommunicator(application, "/ws/chat", headers=[(b"host", b"evil.example.com")])
    ok, code = await comm.connect()
    assert not ok and code == 4400


async def test_revoked_session_token_rejected():
    m, f, mid = await make_match()
    sess = m[1].json()["access"]
    await database_sync_to_async(account_services.revoke_all_sessions)(account=m[2])
    comm = await connect()
    await comm.send_json_to({"type": "auth", "token": sess})
    assert (await comm.receive_output(timeout=2))["code"] == 4401


async def test_send_ack_and_delivery_to_recipient():
    m, f, mid = await make_match()
    cm, cf = await connect(m), await connect(f)
    cid = str(uuid.uuid4())
    await cm.send_json_to(
        {
            "type": "msg.send",
            "match_id": mid,
            "client_msg_id": cid,
            "kind": "text",
            "body": "Habari!",
        }
    )
    ack = await cm.receive_json_from()
    assert (
        ack["type"] == "msg.ack"
        and ack["client_msg_id"] == cid
        and ack["id"]
        and ack["created_at"].endswith("Z")
    )
    new = await cf.receive_json_from()
    assert new["type"] == "msg.new"
    assert (
        new["message"]["body"] == "Habari!"
        and new["message"]["sender"] == "them"
        and new["message"]["id"] == ack["id"]
    )
    msg = await database_sync_to_async(Message.objects.get)(id=ack["id"])
    assert msg.delivered_at is not None  # marked when pushed to the recipient's live socket
    await cm.disconnect()
    await cf.disconnect()


async def test_retry_over_socket_acks_same_id_without_duplicate():
    m, f, mid = await make_match()
    cm = await connect(m)
    cid = str(uuid.uuid4())
    frame = {
        "type": "msg.send",
        "match_id": mid,
        "client_msg_id": cid,
        "kind": "text",
        "body": "once",
    }
    await cm.send_json_to(frame)
    a = await cm.receive_json_from()
    await cm.send_json_to(frame)
    b = await cm.receive_json_from()
    assert a["id"] == b["id"]
    assert await database_sync_to_async(Message.objects.filter(kind="text").count)() == 1
    await cm.disconnect()


async def test_policy_errors_come_back_as_msg_error():
    m, f, mid = await make_match()
    cm = await connect(m)
    cid = str(uuid.uuid4())
    await cm.send_json_to(
        {
            "type": "msg.send",
            "match_id": mid,
            "client_msg_id": cid,
            "kind": "text",
            "body": "call me on 0772123456",
        }
    )
    assert await cm.receive_json_from() == {
        "type": "msg.error",
        "client_msg_id": cid,
        "code": "contact_details_blocked",
    }
    await cm.send_json_to(
        {
            "type": "msg.send",
            "match_id": str(uuid.uuid4()),
            "client_msg_id": str(uuid.uuid4()),
            "kind": "text",
            "body": "x",
        }
    )
    assert (await cm.receive_json_from())["code"] == "not_found"
    await cm.send_json_to({"type": "msg.send", "client_msg_id": "not-a-uuid"})
    assert (await cm.receive_json_from())["code"] == "validation_error"
    await cm.disconnect()


async def test_non_member_cannot_send_into_someone_elses_match():
    from mc.interests.tests.helpers import member

    m, f, mid = await make_match()
    stranger = await database_sync_to_async(member)("female")
    cs = await connect(stranger)
    await cs.send_json_to(
        {
            "type": "msg.send",
            "match_id": mid,
            "client_msg_id": str(uuid.uuid4()),
            "kind": "text",
            "body": "hi",
        }
    )
    assert (await cs.receive_json_from())["code"] == "not_found"
    await cs.disconnect()


async def test_read_receipt_frame_reaches_sender():
    m, f, mid = await make_match()
    cm, cf = await connect(m), await connect(f)
    await cm.send_json_to(
        {
            "type": "msg.send",
            "match_id": mid,
            "client_msg_id": str(uuid.uuid4()),
            "kind": "text",
            "body": "read me",
        }
    )
    ack = await cm.receive_json_from()
    await cf.receive_json_from()  # msg.new
    await cf.send_json_to({"type": "msg.read", "match_id": mid, "up_to_message_id": ack["id"]})
    receipt = await cm.receive_json_from()
    assert (
        receipt["type"] == "msg.read"
        and receipt["up_to_message_id"] == ack["id"]
        and receipt["match_id"] == mid
    )
    assert str(m[2].id) not in str(receipt) and str(f[2].id) not in str(
        receipt
    )  # profile id, never account id
    await cm.disconnect()
    await cf.disconnect()


async def test_match_ended_frame_to_both_without_reason():
    from mc.matches import services as match_services

    m, f, mid = await make_match()
    cm, cf = await connect(m), await connect(f)
    await database_sync_to_async(match_services.unmatch)(match_id=uuid.UUID(mid), by=m[2].id)
    for comm in (cm, cf):
        assert await comm.receive_json_from() == {"type": "match.ended", "match_id": mid}
    await cm.disconnect()
    await cf.disconnect()


async def test_ping_pong_and_presence_lifecycle(settings):
    settings.WS_PING_SECONDS = 0.2
    m, f, mid = await make_match()
    cm = await connect(m)
    assert await database_sync_to_async(presence.is_online)(m[2].id) is True
    await cm.send_json_to({"type": "ping"})
    assert (await cm.receive_json_from())["type"] == "pong"
    assert (await cm.receive_json_from(timeout=2))["type"] == "ping"  # server heartbeat
    await cm.send_json_to({"type": "pong"})
    await cm.disconnect()
    await asyncio.sleep(0.05)
    assert await database_sync_to_async(presence.is_online)(m[2].id) is False


async def test_session_revoked_mid_connection_closes_socket(settings):
    settings.WS_PING_SECONDS = 0.2
    m, f, mid = await make_match()
    cm = await connect(m)
    await database_sync_to_async(account_services.revoke_all_sessions)(account=m[2])
    out = await cm.receive_output(timeout=2)
    assert out["type"] == "websocket.close" and out["code"] == 4403
