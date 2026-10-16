"""Phase 5 extension points (Bible §18, CLAUDE.md rule 12): INTERFACES ONLY.

Nothing here has models, migrations, endpoints, tasks or consumers, and nothing outside this package may
import it (import-linter contract + `tests/test_architecture.py`). The three feature flags are locked off
(`mc.flags.registry.LOCKED_OFF`), so every default implementation answers "not enabled". Building any of
these needs a new backlog epic approved after counsel's review."""
