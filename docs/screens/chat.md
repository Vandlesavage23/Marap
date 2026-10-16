# Chat

**Purpose.** Read and send messages in a match: text (outbox first), photos (unlock after 10 messages each), voice notes (<= 60 s). Read-only once membership ends. Contact details are blocked for the first 72 hours.

**Routes.** `/matches/:id/chat`; realtime on `wss://.../ws/chat`.

**API.** `GET /matches/<id>/messages?limit=30&before=`, `POST /matches/<id>/messages` (`client_msg_id` unique per sender; also the idempotency key for media), `POST /matches/<id>/read`, `GET /me/entitlements` (capabilities), media upload endpoints (see profile builder). WebSocket frames: `auth`, `auth.ok`, `msg.send`/`msg.ack`/`msg.error`, `msg.new`, `msg.read`, `ping`/`pong`, `match.ended`; close 4401 (auth) / 4403 (session ended).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner / "Connecting..." banner | `social/chat_screen_test.dart: connection banners follow the socket` |
| data | bubbles, system line, receipts, safety tip, deleted; load earlier; photos and voice | `chat_screen_test.dart: history ...`, `load earlier messages`, `photos (MC-081)`, `voice notes (MC-081)`; contract `social_contract_test.dart: chat ...`, `media_contract_test.dart`, `socket_contract_test.dart` |
| empty | "Say hello" | `chat_screen_test.dart: empty conversation` |
| error | refused message shows why and can be deleted; media failure generic message; history refused | `chat_screen_test.dart: a refused message ...`, `history refused: $code`, `media failure other than photo_locked` |
| restricted | read-only banner, history visible, no composer; ended conversation; photos locked with progress | `chat_screen_test.dart: restricted ...`, `ended conversation`, `locked: explains the rule`; contract `restricted_contract_test.dart` (real expired member), `media_contract_test.dart` (real `photo_locked`) |
| offline | queued ("Waiting for connection"), delivered once after reconnect; cached history when offline | `chat_screen_test.dart: typing swaps the mic ... pending then delivered`, `offline with nothing saved`; `outbox_test.dart`; `device_track/outbox_media_test.dart`; contract `social_contract_test.dart: outbox ...`; `integration_test/chat_offline_test.dart` |

**GAP.** Real audio recording/playback and the image picker run only on a device. The WebSocket `msg.error` frame for a refused send is exercised in contract (`validation_error`) but the app never reads it (sending uses REST), so no UI state depends on it.
