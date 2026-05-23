# AGENTS.md

Canonical source of truth for this repo. When anything conflicts with this file, this file wins.

## Stack

Pinned versions in `pubspec.yaml`. Rules:

- Riverpod codegen only — no legacy `StateNotifier`.
- All backend calls return `Either<Failure, T>` via fpdart.
- Env via `--dart-define-from-file=env.json`. No `flutter_dotenv`.
- Mobile-first (Android + iOS). Desktop best-effort. Web TBD.

## Core principles

- Minimal patch. No opportunistic refactors.
- KISS. No abstractions for a single caller.
- Never invent endpoints, contracts, or backend behavior.
- No commits with secrets.
- When you find a problem, fix the error — do not add a "never do X" clause to docs or comments. A correction removes the bad behavior; it does not document the prohibition unless asked.

## Pipeline

Work runs four stages, each with its own agent file in `.claude/agents/`:

1. **Plan** → `app-planner` → `plan.md`
2. **Implement** → `app-implementer` → `implementation-report.md`
3. **Review** → `app-reviewer` → `review-report.md`
4. **Git** → `app-git` → branch + PR

Each agent file owns its own contract — tools, prompt, output.

Stage artifacts live in `.ai/runs/<YYYY-MM-DD>-<slug>/`. They are local working notes: gitignored, never committed. The pipeline reads them across stages within one task; once the PR merges they have no canonical value.

## Handoff convention

Every agent ends its report with a one-line footer on its own line:

`— <agent-name> · next: <agent-name | human | done>`

The git stage has no run-dir file on success, so its handoff footer goes in chat. This is the audit trail. Stage rotation must be unambiguous.

## Workflow

- **PR title** = squash commit subject, Conventional Commits (`type(scope): subject`, `!` for breaking).
- **Branch**: `type/scope-subject` mirroring the PR title.
- **Squash merge only**, PR required, linear history, signed, no force push. Head branches auto-delete.
- **PR body**: Scope, Changeset, Verification, Smoke test (`N/A` where it doesn't apply). Off-template context goes in ONE custom named section with a descriptive header.
- **Commits inside a branch**: free-form. Only the squash subject matters.
- **Issues**: agents never merge PRs; they may close issues only with explicit human permission.

## Commands

Verification sequence, run from the repo root:

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Run exactly what the plan's "Verification commands" section lists — no more, no less.

## Testing

Tests accompany behavior changes; pick the lowest level that proves the behavior. Golden tests when visual regressions matter. Coverage not enforced as a number. PRs missing tests for testable behavior are blocked at review.

Each plan declares `testing_policy`: `none`, `existing`, or `required`. Default by work type: documentation/research → `none`; fix/feature → `required`. Tests assert what the spec requires, not what the code currently does.

## Language

Respond in the human's language. Anything committed — code, comments, docs, commit and PR text — is English only.

## Public-repo discipline

Nothing about backend internals belongs in this repo — code, comments, commits, docs, fixtures, branch names, issue/PR text.

- No paths reaching outside this repo root.
- No internal function names, schema namespaces, migration filenames, cron job names, or backend env var names.
- Frontend integration runs against documented HTTPS endpoints in `docs/integration/`.

**Until `docs/integration/` exists**, do not write code that hits the backend.

### Naming hygiene

PR bodies, issue bodies, and commit messages reference only identifiers with a URL in this repo (issue #, PR #, file path, commit SHA). Internal planning names, epic IDs, sub-task numbers, roadmap milestones do not appear in public artifacts. **If a reference does not have a URL in this repo, do not write it.**

Use single quotes in commit messages (plain text); backticks elsewhere.

The Claude Code auto-memory system is not used.

## Source precedence

1. **`AGENTS.md`** — workflow and discipline.
2. **`pubspec.yaml`** — pinned versions and dependencies.
3. **`docs/integration/`** — API canon.
4. **`docs/architecture.md`** — Flutter patterns.
5. **Code in this repo** — what it actually does.

Anything outside this repo is not a valid source.

## Enforcement

Prompts do not enforce themselves. Three layers do:

1. Each agent file's `tools` allowlist (YAML frontmatter).
2. Per-subagent `PreToolUse` hooks. The planner uses `.claude/hooks/validate-plan-write.mjs` to block writes outside `.ai/runs/<run>/plan.md` — critical because the planner consumes external content via `WebFetch`.
3. `.claude/settings.json` — the `deny` and `ask` permission lists.

The git stage cannot be fully tool-restricted (Bash is needed for git itself), so its scope is verified post-hoc by a pre/post diff equality check inside the agent.

Denied, do not retry: file deletion (`rm`, `del`, `rmdir`, …), destructive git (`push --force`, `reset --hard`, `clean`, `checkout --`, `restore`), `gh pr merge`, reading or writing `env.json` and `.env*`, and editing `.claude/settings.json`. Git writes (`push`, `reset`, `merge`, `rebase`) and `gh issue close` prompt the human before running.

## Defect protocol

Off-scope defects don't get patched ad-hoc. File a new issue (`Sub-issue` template) linking the source PR; re-scope deliberately.
