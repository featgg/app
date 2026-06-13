---
name: codex-triage
description: Triage Codex (chatgpt-codex-connector) review findings — a GitHub PR review or a local pass — per AGENTS.md § AI review triage. Use when the user asks to review/triage Codex comments and decide which apply.
---

# Codex Review Triage

Triage Codex findings per `AGENTS.md` § AI review triage. The flow is identical
for a GitHub PR review and a local pass (the `code-review` skill / codex-companion);
only how the findings are gathered differs.

## Gather the findings

- **PR review** — fetch ALL Codex feedback (bot user `chatgpt-codex-connector[bot]`)
  from all three surfaces. Do NOT rely on `gh pr view --comments` — it can miss
  inline review comments.
  - Review bodies: `gh api repos/{owner}/{repo}/pulls/{N}/reviews --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
  - Inline comments: `gh api repos/{owner}/{repo}/pulls/{N}/comments --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
  - Top-level PR comments: `gh api repos/{owner}/{repo}/issues/{N}/comments --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
- **Local review** — use the findings the local pass printed (the `code-review`
  skill output, or the codex-companion review file). There is nothing to fetch.

## Triage each finding (AGENTS.md § AI review triage)

1. **Applies?** Read the referenced file/lines on the current branch and check
   the finding against the actual code, the `docs/integration/` brief, and canon
   — not against the comment's wording. It may already be fixed, be a false
   positive, rest on a misread, or contradict a deliberate scope split the
   reviewer cannot see. KISS: reject suggestions that add complexity without
   clear value. A finding that does not apply is dismissed here and never
   reaches step 2.
2. **Severity.** P0/P1/P2 per `AGENTS.md` § Review guidelines (P0 = Blocker,
   P1 = Major, P2 = Minor/Nit).
3. **Decision.** Exactly one: **fix now** (valid, in scope) · **dismiss**
   (doesn't apply) · **file an issue + re-scope** (valid but off-scope — see
   § Defect protocol) · **defer** (valid but owned by a planned later sub-issue).

Output a table: finding (file:line) | applies? | severity | decision | reason.
Do not implement fixes unless explicitly asked.
