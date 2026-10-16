# Notifications

**Purpose.** Inbox of generic notifications (never names or message text), push opt-in with an honest explanation before any system prompt, device registration, tap-to-open routing.

**Routes.** `/notifications`; `/settings/notifications` (opt-in). Push taps route through `NotificationLinks` (only id-shaped values reach a path).

**API.** `GET /notifications?limit=30&cursor=` (items, `unread`), `POST /notifications/read` (`{ids}` or `{}` for all), `POST /me/devices` (upsert, Idempotency-Key; `push_token: null` is meant to clear the token, see contract finding C1), `GET /me/devices` (new in the backend; the client does not call it).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner | `device_track/notifications_test.dart: NotificationsScreen states loading` |
| data | generic copy per type; tap marks read and opens the destination; mark all read; show older | `notifications_test.dart: data ...`, `tap marks read ...`, `mark all as read`, `show older loads the next page`; contract `social_contract_test.dart: notifications ...` (real payload ids) |
| empty | no notifications | `notifications_test.dart: empty` |
| error | error with retry; failed mark keeps it unread | `notifications_test.dart: error with retry`, `a failed mark shows a message and keeps it unread` |
| restricted | opt-in off by default; permission refused / blocked in system settings explained; no Firebase config disabled | `device_track/screens_test.dart: NotificationSettingsScreen ...`, `push_test.dart: opt-in` |
| offline | offline with retry; disable works offline | `notifications_test.dart: offline with retry`, `push_test.dart: disable still works offline` |

**GAP.** Real FCM delivery and token rotation run only on a device. Server-side token clearing on opt-out does not work (finding C1), and its contract test is skipped with that reason until the backend distinguishes omitted from null.
