# Discovery

**Purpose.** One ranked card at a time; pass, "not for me", or send an interest. Shows why a person was suggested and what to talk about. Online-only (Bible §5.4).

**Routes.** `/discovery`, `/discovery/profile/:id` (public profile).

**API.** `GET /discovery?cursor=`, `POST /discovery/feedback` (`pass`, `not_relevant`), `GET /profiles/<id>`, `GET/PUT /me/preferences` (filters). Browsing needs the `browse` capability (403 `entitlement_required`).

| State | Behaviour | Test |
| --- | --- | --- |
| loading | spinner then card | `social/discovery_test.dart: DiscoveryScreen states loading then card` |
| data | card with badges and band; why sheet; swipe left/right; filters sheet; photo loading respects data saver | `discovery_test.dart: why sheet ...`, `swiping left passes ...`, `swiping right opens the send-interest sheet`, `filters sheet ...`, `ProgressiveImage / data saver`; contract `profile_contract_test.dart: discovery ...` |
| empty | nothing at all; out of candidates | `discovery_test.dart: empty (nothing at all)`, `after the last card` |
| error | server error; daily limit; profile failures | `discovery_test.dart: error state (server) and daily limit state`, `ProfileScreen failure ...` |
| restricted | entitlement; profile incomplete explains what to do | `discovery_test.dart: restricted (entitlement) state`, `profile incomplete ...`; contract `restricted_contract_test.dart` (real 403 `browse`) |
| offline | retry | `discovery_test.dart: offline state retries` |

Controller: prefetch, dedupe, expired cursor restart, feedback rollback (`DiscoveryController` tests). Preloading of the next photo: `device_track/screens_test.dart: discovery preloads the next card`.

**GAP.** Cursor expiry against the real server is not exercised (contract only checks the first page and `profile`).
