# Profile builder

**Purpose.** Eight guided steps (basics, about, intention, location, photos, description, questions, preview) that end with "Go live". Resumes at the first step the server reports incomplete.

**Routes.** `/profile/builder` (single route, step state inside).

**API.** `GET/PATCH /me/profile`, `GET/PUT /me/preferences`, `GET/POST /me/photos`, `PUT /me/photos/order`, `DELETE /me/photos/<id>`, `GET/POST /me/descriptions` (Idempotency-Key), `POST /me/profile/go-live`, `POST /media/uploads` (Idempotency-Key) -> presigned POST to storage (no bearer) -> `POST /media/<id>/complete` -> poll `GET /media/<id>`.

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner | `profile_track/profile_screens_test.dart: builder shell loading` |
| data | each step validates, saves, moves on; photo grid with statuses; live guidance on description; preview shows only public fields | `profile_screens_test.dart: steps`, `photos step`, `description step`, `preview and go live`; contract `profile_contract_test.dart`, `media_contract_test.dart` (real upload) |
| empty | no photos (+ data-saver note); preview placeholders | `profile_screens_test.dart: photos step empty state`, `preview without a photo or description` |
| error | refused save keeps data; failed upload with retry/dismiss; rejected photo/description explained; preferences load failure retry | `profile_screens_test.dart: basics: a refused save`, `a failed upload ...`, `a rejected photo ...`, `a rejected description ...`, `location: preferences load failure` |
| restricted | go-live refused lists what is missing; photo limit disables add; gender locked once set. Unverified accounts get 403 `not_verified` (the guard keeps them out) | `profile_screens_test.dart: go live ... a refusal lists what is missing`, `the add button is disabled at the limit`, `basics: gender is locked`; contract `onboarding_contract_test.dart` (403 `not_verified`) |
| offline | offline then retry; failed upload resumes without a new ticket | `profile_screens_test.dart: offline then retry`; `profile_logic_test.dart: a failed upload resumes ...` |

**GAP.** Photo drag-reorder has controller coverage only (`photos controller: reorder moves a photo`); no widget test drives it. Camera capture and the image compressor run only on a device.
