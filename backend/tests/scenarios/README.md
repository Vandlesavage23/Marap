# Scenario tests (Bible §13.2)

Run them all: `uv run pytest -k test_scenario`.

| # | Where |
| --- | --- |
| 01, 02 (retry), 03, 04 | `tests/scenarios/test_scenarios.py` |
| 02 (review + appeal) | `mc/verification/tests/test_review.py` |
| 05 | `mc/billing/tests/test_apple.py`, `test_google.py` (these need local PKI / OIDC fixtures) |
| 06, 14 | `tests/scenarios/test_scenarios_06_14.py` |
| 07 | `mc/billing/tests/test_apple.py` |
| 08–11 | skipped in `test_scenarios_06_14.py` (Phase 5, not built) |
| 12 | `mc/adminportal/tests/test_portal.py` |
| 13 | `mc/privacy/tests/test_deletion.py` |
