# Safety

**Purpose.** Block (immediate, silent), report (three taps), the safety centre (bundled content), blocked-people list, and appeals against enforcement. Blocks are absolute server-side.

**Routes.** `/safety/centre`, `/safety/blocked`, `/safety/report`, `/safety/appeal`; block/report are menu actions on profiles and chats.

**API.** `POST /blocks`, `GET /blocks`, `DELETE /blocks/<profile_id>`, `POST /reports` (Idempotency-Key; 11 categories, 3 contexts, `also_block`), `GET /me` (`enforcement`), `POST /safety/appeals`. Content: `assets/safety_centre.json`.

| State | Behaviour | Test |
| --- | --- | --- |
| loading | blocked list loading | `membership_track/safety_screens_test.dart: blocked list error and loading` |
| data | blocked list with unblock; safety centre sections; report receipt | `safety_screens_test.dart: report flow`, `blocked list data, unblock, empty`, `safety centre renders bundled content`; contract `membership_safety_contract_test.dart: safety ...` (real block, report replay, every category) |
| empty | no blocked people; empty safety content | `safety_screens_test.dart: blocked list data, unblock, empty`, `safety centre empty and error` |
| error | report failure keeps the form and reuses the key; block failure copy | `safety_screens_test.dart: failure keeps the form and retry reuses the key`, `block failure shows friendly copy` |
| restricted | suspended member can appeal (10+ characters); banned / already appealed / none | `safety_screens_test.dart: appeals ...` |
| offline | **GAP** (no safety-specific offline widget test; failures use the generic failure copy) |  |

**GAP.** Report contexts `interest` and `message` (with `context_id`) and free-text-less reports are covered only by the contract suite (`membership_safety_contract_test.dart: reports with message and interest context ids`); the widget tests only send `context_type: profile`. Appeal against a real enforcement action cannot be set up from the fixture (needs staff actions).
