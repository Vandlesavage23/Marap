# Playbook — Building Marriage Connect with Claude Code

This is for the humans steering the work. Claude Code writes and runs code; you choose the ticket,
approve the plan, review the result and merge. Official docs: https://code.claude.com/docs/

## 1. One-time setup

1. **Accounts:** a paid Claude subscription (or an Anthropic Console account), a GitHub account and
   organisation, and the vendor sandbox accounts from backlog M0.
2. **Install tools on your computer:** Git, Docker Desktop, Python 3.12 + `uv`, Flutter via FVM,
   Android Studio (emulator), and Xcode on a Mac for iOS builds.
3. **Install Claude Code** (pick one):
   - Terminal, macOS/Linux/WSL: `curl -fsSL https://claude.ai/install.sh | bash`
   - Windows PowerShell: `irm https://claude.ai/install.ps1 | iex`
   - Or the **Claude desktop app** → **Code** tab, or the **VS Code / Cursor extension** ("Claude Code"),
     or in the browser at https://claude.ai/code.
   - Check: open a new terminal and run `claude --version`.
4. **Create the repository:**
   ```bash
   mkdir marriage-connect && cd marriage-connect
   git init
   # copy CLAUDE.md and the docs/ folder from this starter pack into it
   git add . && git commit -m "Planning docs and Claude Code rules"
   ```
5. **Start Claude Code in the repo:** `claude` (log in on first run). It reads `CLAUDE.md` automatically
   at the start of every session.

## 2. The working loop (every ticket)

1. **Pick the next ticket** in `docs/BACKLOG.md` whose dependencies are merged.
2. **Ask for a plan first, no code:**
   > Read CLAUDE.md, then the Bible sections listed in ticket MC-013 and the ticket itself. Write a plan:
   > files to create or change, models/migrations, tests you will write first, and any questions.
   > Do not write code yet.
3. **Review the plan.** Correct anything that conflicts with the Bible. Answer its questions.
4. **Let it implement:**
   > Approved. Create branch feat/MC-013-common-foundations, write the tests first, implement,
   > run the full check commands from CLAUDE.md, and fix failures until all pass.
5. **Review the diff yourself** (or in the desktop app / VS Code diff view). Check: acceptance criteria,
   no secrets, no PII in logs, tests meaningful, no scope creep.
6. **Commit and PR:**
   > Commit with message "MC-013: …", push, and open a PR using the template. List how each acceptance
   > criterion is demonstrated.
7. **CI green + human review → merge.** Tick the ticket in BACKLOG.md.
8. **Start a fresh session for the next ticket** so the context stays focused.

## 3. Starter prompts by milestone

**M1 kickoff (first session):**
> Read CLAUDE.md, docs/BUILD_BIBLE.md sections 2–4 and tickets MC-010 to MC-016. Plan MC-010 only.

**Flutter foundation:**
> Plan MC-017 and MC-018 together. Follow Bible §5 exactly: packages from the table only, folder
> structure in §5.3, interceptors in §5.4. Include the tests listed in the acceptance criteria.

**Risky business rules (interests, billing, blocks):**
> Before implementing MC-065, write the failing tests for every rule in Bible §10.4 and scenario 03,
> show me the test names, and wait for approval.

**Security review of a finished milestone:**
> Act as a security reviewer. Review the diff of milestone M2 against Bible §12 and CLAUDE.md hard rules.
> List concrete findings with file and line, most severe first. Do not change code.

**Consistency check:**
> Compare the OpenAPI schema, the Bible §8.2 table and the Flutter repositories. List mismatches.

## 4. Guardrails

- Never paste real user data, production secrets or vendor live keys into a Claude Code session.
  Use sandbox keys in `.env` locally; production secrets live only in the cloud secrets manager.
- Keep humans as the approvers for: database migrations on staging/prod, billing and entitlement code,
  safety/moderation logic, anything touching special personal data, and every production deploy.
- If Claude Code proposes a new library, framework or service not in CLAUDE.md §3, ask for an ADR first.
- If the plan and the code drift, update the Bible in the same PR (with a reference to the decision).
- Large tickets: ask it to split into sub-tasks and do one per session.

## 5. Useful Claude Code features for this project

- **CLAUDE.md** (already written): the binding project rules, loaded every session.
- **Hooks:** run commands automatically, e.g. format after every edit or run lint before a commit.
  See https://code.claude.com/docs/en/hooks
- **Skills:** package repeatable workflows such as `/review-pr` or `/new-module`.
  See https://code.claude.com/docs/en/skills
- **Subagents:** let a lead session split work (e.g. backend API + Flutter screen) across parallel agents.
  See https://code.claude.com/docs/en/sub-agents
- **GitHub Actions:** automated PR review in CI. See https://code.claude.com/docs/en/github-actions
- **Non-interactive mode:** `claude -p "…"` for scripted tasks, e.g. reviewing changed files.

## 6. Team shape that works well with Claude Code

Even with AI doing much of the typing, keep accountable people: a tech lead who approves plans and owns
architecture, one senior Flutter and one senior backend engineer who review every PR in their area, a
designer, and QA. Claude Code speeds them up; it does not replace review, security testing, legal
review or store-policy judgement.
