# Settings

**Purpose.** Account controls: privacy and consents, signed-in devices, data saver, notification opt-in, export, delete account (code re-auth), beta feedback.

**Routes.** `/settings`, `/settings/privacy`, `/settings/sessions`, `/settings/data-saver`, `/settings/notifications`, `/settings/export`, `/settings/delete`, `/settings/feedback`, `/settings/membership`.

**API.** `POST /me/consents`, `GET /me/sessions`, `DELETE /me/sessions/<id>`, `POST /me/reauth/start`, `DELETE /me` (`code`), `POST /me/export`, `GET /me/export/<id>`, `POST /beta/feedback`; `GET /config/flags` (data saver default). Known client gap: `AccountRepository.consents()` is a stub returning an empty snapshot although `GET /me/consents` exists (contract finding C3).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | consents and sessions loading | `membership_track/settings_screens_test.dart: privacy and consents error and loading` |
| data | settings home entries; consents withdraw; sessions (this device has no sign-out); export request -> pending -> ready; delete flow; data saver switches | `settings_screens_test.dart: settings home ...`, `lists consents and withdraws one`, `sessions`, `data export`, `delete account`, `beta feedback`; `device_track/data_saver_test.dart`; contract `account_contract_test.dart: AccountRepository ...` |
| empty | **GAP** (no empty consents/sessions state test) |  |
| error | sessions error; wrong deletion code; feedback failure keeps text | `settings_screens_test.dart: sessions error`, `wrong code shows a clear message`, `beta feedback failure keeps the text` |
| restricted | **GAP** (settings are reachable by suspended accounts; no test asserts it) |  |
| offline | deletion code request offline; data saver tolerates an unreachable flags endpoint | `settings_screens_test.dart: code request offline error`; `data_saver_test.dart: an unreachable flags endpoint is tolerated` |

**GAP.** Consents screen cannot show the member's current choices (stub), so the "data" state for privacy is partly wrong against the real server; the test uses a fake that returns values.
