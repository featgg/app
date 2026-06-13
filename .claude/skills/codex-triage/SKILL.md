---
name: codex-triage
description: Gather the evidence for triaging Codex (chatgpt-codex-connector) review findings — a GitHub PR review or a local pass — into a digest for the main agent to judge per AGENTS.md § AI review triage. Use when the user asks to review/triage Codex comments.
model: sonnet
allowed-tools: Read, Grep, Bash(gh:*)
---

# Codex Review Triage — gather the evidence

This skill **brings the data on a platter; it does not judge.** It fetches the
findings and quotes the exact code they point at, then hands a digest back to
the main agent, which makes the applies / severity / decision call per
`AGENTS.md` § AI review triage. Do **not** decide whether a finding applies, its
severity, or what to do about it, and never edit code — this is gather-only.

## 1. Gather the findings

- **PR review** — fetch ALL Codex feedback (bot user `chatgpt-codex-connector[bot]`)
  from all three surfaces. Do NOT rely on `gh pr view --comments` — it can miss
  inline review comments.
  - Review bodies: `gh api repos/{owner}/{repo}/pulls/{N}/reviews --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
  - Inline comments: `gh api repos/{owner}/{repo}/pulls/{N}/comments --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
  - Top-level PR comments: `gh api repos/{owner}/{repo}/issues/{N}/comments --paginate --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]")'`
- **Local review** — use the findings the local pass printed (the `code-review`
  skill output / codex-companion review file). Nothing to fetch.

## 2. Bring the evidence for each finding

For every finding, read the referenced file/lines **on the current branch** and
quote the actual code (plus the relevant `docs/integration/` brief lines if the
finding cites the contract). Add one mechanical, non-judgmental observation: does
the cited line still match the comment's claim, or does the code look
already-changed / the symbol no longer present? (This surfaces stale findings —
it is an observation, not a verdict.)

## Output — a digest, not a verdict

One block per finding:

- **Finding** — `file:line`, the severity Codex stated, and the claim.
- **Actual code** — the quoted lines on the current branch (+ brief excerpt if cited).
- **Mechanical note** — "line matches claim" / "looks already-changed" / "not found".

Do **not** add an applies / severity / decision column — the main agent fills
that in per `AGENTS.md` § AI review triage. Do not implement fixes.
