---
name: codex-triage
description: Triage Codex (chatgpt-codex-connector) review comments on a PR. Use when the user asks to review/triage Codex comments on a PR and decide which apply.
---

# Codex Review Triage

1. Fetch ALL Codex feedback (bot user is `chatgpt-codex-connector[bot]`):
   - Review bodies: `gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
   - Inline comments: `gh api repos/{owner}/{repo}/pulls/{N}/comments --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
   - Do NOT rely on `gh pr view --comments` (might miss inline review comments).
2. For each finding, read the referenced file/lines in the current branch (it may already be fixed).
3. Verdict per finding: APPLIES / DOES NOT APPLY / PARTIAL, with a one-line justification grounded in the actual code. Follow KISS: reject suggestions that add complexity without clear value.
4. Output a summary table: file:line | finding | verdict | reason. Do not implement fixes unless explicitly asked.
