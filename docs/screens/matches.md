# Matches

**Purpose.** List mutual matches, cached for offline use; open a chat; unmatch.

**Routes.** `/matches`; `/matches/:id/chat` opens the chat.

**API.** `GET /matches?limit=50&cursor=` (followed up to 20 pages), `POST /matches/<id>/unmatch`. Server also sends `last_message_*` and `unread_count`, which the client ignores (no unread badge).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | saved copy at once, then synced list | `social/matches_test.dart: MatchesScreen states loading, then the list` |
| data | list; tap opens chat | `matches_test.dart: loading, then the list; tapping opens the chat`; contract `social_contract_test.dart: matches ...` (real sync, cache) |
| empty | "No matches yet" | `matches_test.dart: empty state` |
| error | failure with nothing saved | `matches_test.dart: failure $code with nothing saved` |
| restricted | entitlement refusal shown even with a copy | `matches_test.dart: a refusal (entitlement) is shown ...` (controller) |
| offline | stale banner over the saved copy; error if nothing saved | `matches_test.dart: offline with a saved list shows the stale banner`, `controller: offline ...` |

Ended matches (`match.ended`) disappear locally with their messages (`MatchesController` + `ApiMatchesRepository` tests).

**GAP.** The unmatch confirmation dialog (menu -> confirm) has controller and repository tests only; no widget test drives the UI. A member whose membership ended still lists matches (contract `restricted_contract_test.dart`) but no widget test shows that state. Unread badge: not implemented.
