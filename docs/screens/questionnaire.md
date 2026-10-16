# Questionnaire

**Purpose.** Collect compatibility answers (single / multi / scale, importance, optional deal-breaker). Special-category questions are optional and ask for consent first (CLAUDE.md rule 4).

**Routes.** `/questionnaire`.

**API.** `GET /questions`, `GET /me/answers`, `PUT /me/answers` (all-or-nothing, <= 60), `POST /me/consents` (`special_religion`, `special_finance`). A special answer without consent -> 422 `validation_error` + `missing_consent`.

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner | `profile_track/questionnaire_test.dart: screen states loading` |
| data | dimensions, progress, optional section; importance and deal-breaker only after an answer; Done only when core complete and saved | `questionnaire_test.dart: data: dimensions ...`, `answering`, `Done is only enabled ...`; contract `profile_contract_test.dart: questionnaire ...` |
| empty | no questions | `questionnaire_test.dart: screen states empty` |
| error | save failure keeps answers; consent failure leaves the answer unset | `questionnaire_test.dart: save failure shows friendly copy`, `if recording consent fails the answer is not set` |
| restricted | consent sheet before any special answer; server-side `missing_consent` has its own copy | `questionnaire_test.dart: special questions ...`, `the server refusing for missing consent`; contract (real refusal + grant) |
| offline | offline then retry | `questionnaire_test.dart: offline then retry` |

**GAP.** Stale answers (`stale: true`, question changed since answered) are parsed but no test asserts the UI asks again.
