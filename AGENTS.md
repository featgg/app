# AGENTS.md

Canonical source of truth for this repo. When anything conflicts with this file, this file wins.

## Stack

Pinned versions in `pubspec.yaml`. Rules:

- Riverpod codegen only — no legacy `StateNotifier`.
- All backend calls return `Either<Failure, T>` via fpdart.
- Env via `--dart-define-from-file`, selecting a per-environment file (`env.staging.json` or `env.production.json`). No `flutter_dotenv`.
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

A stage is complete only when its run-dir artifact exists with the handoff footer — never on the strength of the subagent's final chat message; a subagent can be cut off mid-task and still be reported as completed. Pipeline subagents run in the foreground. If a stage returns without its artifact, the stage is not done: when the harness exposes a resume capability, continue that same agent from where it stopped (cheapest — its context is intact); otherwise re-spawn it fresh against the existing working tree and partial artifact, or finish the stage inline.

Codex (or any other AI tool) auto-reviews every PR on GitHub
outside the repo; its findings arrive as PR comments after Stage 4.
The human triages them per § AI review triage — applies? → severity →
decision (fix / dismiss / file an issue / defer). Agents never act on
an AI review comment without that triage.

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

Run exactly what the plan's "Verification commands" section lists for your stage — no more, no less. Plans scope the Stage-2 `flutter test` to the suites the change touches; the full suite runs once, at Stage 3.

Run the sequence in the foreground in one shell, each command to its real exit code before the next — it is a dependency chain, not parallel work; do not background-and-poll. A genuinely long-lived process (a dev server) is the exception and may background. Stay in that shell: switch only if the shell itself cannot run the command (unrecognized syntax, shell unavailable), never because a command failed on its own merits — a failing test or `analyze` error is a real result, not a shell fault. After switching, stay in the new shell until it also fails.

## Testing

Tests accompany behavior changes; pick the lowest level that proves the behavior. Golden tests when visual regressions matter. Coverage not enforced as a number. PRs missing tests for testable behavior are blocked at review.

Each plan declares `testing_policy`: `none`, `existing`, or `required`. Default by work type: documentation/research → `none`; fix/feature → `required`. Tests assert what the spec requires, not what the code currently does.

Tests never assert hard-coded user-facing or localized copy. A translated string is owned by its ARB file and edited freely; assert against the l10n key or structural behavior (a locale resolves, two locales differ, a value is non-empty) — never a literal translation. A copy edit must never break a test.

**Green tests prove logic, not integration.** Unit and widget tests run against fakes (hand-rolled SDK/repository/picker/data-source fakes), below the real integration boundary — they exercise neither a deployed backend endpoint, the client SDK against a live service, nor device/platform capabilities (camera, image codecs, file pickers, permissions, deep links). A feature whose behavior depends on any of those is **not "working" or "done" on green tests + `analyze` alone** — that only means its logic is sound. Claiming such a path works requires a real run on a target device/platform against the deployed backend; absent that, it ships explicitly marked "not integration-validated; blocked on `<dependency>`". No agent, report, or summary claims a backend-, SDK-, or device-dependent path "works" on the strength of green fakes — and a plan that depends on a backend surface must name the deploy/provisioning prerequisite in its smoke test, not assume it.

## Language

Respond in the human's language. Anything committed — code, comments, docs, commit and PR text — is English only.

## Public-repo discipline

Nothing about backend internals belongs in this repo — code, comments, commits, docs, fixtures, branch names, issue/PR text.

- No paths reaching outside this repo root.
- No internal function names, schema namespaces, migration filenames, cron job names, or backend env var names.
- Frontend integration runs against documented HTTPS endpoints in `docs/integration/`.

**Until `docs/integration/` exists**, do not write code that hits the backend.

## Code comments

Comments earn their place by saying what the code cannot say for itself — keep them few and high-signal.

- Explain *why*, not *what*: justify a non-obvious choice, record an assumption or constraint, or flag something that looks out of place on purpose. The code already shows what it does.
- Don't restate the code or comment the obvious — a comment that paraphrases the line below it is noise that drifts out of date.
- No references to ephemeral or external locations: no chat, no issue/PR numbers, no `.ai/runs/*`, no doc paths or section/line numbers (e.g. not "see docs/architecture.md § X"). State the justification inline. Docs reference code, not the reverse.
- Doc-comments (`///`) on public APIs are welcome — scope them to the caller's contract, not the implementation.

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

Denied, do not retry: file deletion (`rm`, `del`, `rmdir`, …), destructive git (`push --force`, `reset --hard`, `clean`, `checkout --`, `restore`), `gh pr merge`, reading or writing `env.*.json` and `.env*`, and editing `.claude/settings.json`. Git writes (`push`, `reset`, `merge`, `rebase`) and `gh issue close` prompt the human before running.

## Defect protocol

Off-scope defects don't get patched ad-hoc. File a new issue (`Sub-issue` template) linking the source PR; re-scope deliberately.

## Review guidelines

Guidance for AI code review on GitHub PRs (Codex or any other
reviewer that reads this file). The Stage-3 reviewer subagent
remains the authoritative gate; this section tunes diff-level
review passes only. The P0/P1 lists below are repo-specific
additions, not a whitelist: genuine correctness or logic defects
remain reportable at the severity they merit. P0 maps to Blocker,
P1 to Major, and P2 to Minor/Nit in the Stage-3 reviewer's severity
buckets.

- P0: backend internals anywhere in the diff — internal function
  names, schema namespaces, migration filenames, cron job names,
  backend env var names, or paths reaching outside this repo root
  (this repo is public); hardcoded secrets, API keys, or tokens;
  committed `env.*.json` values.
- P1: backend calls not returning `Either<Failure, T>`; swallowed
  errors on network or auth paths; legacy `StateNotifier` instead
  of Riverpod codegen; `setState` holding non-ephemeral state —
  state that is shared, outlives the widget, or has any consequence
  beyond the widget's own rendering (navigation, a refresh, another
  screen. Use it as less as possible. Only as an exception if really needed) — instead of a Riverpod provider/`AsyncNotifier`; raw
  `Color(...)` / `Colors.*` literals,
  magic spacing, or ad-hoc `TextStyle` outside
  `lib/src/core/theme/`; imports violating the inward-only layer
  rule or cross-feature isolation (only `domain` crosses feature
  boundaries); tests asserting literal user-facing or localized
  copy; code that calls the backend while `docs/integration/` does
  not exist; internal planning identifiers (epic IDs, internal
  issue numbers) in the diff or PR text.
- When `docs/` covers the area the diff touches, read the relevant
  sections and flag any contradiction with the implementation as
  P1 (P0 if it falls under a P0 item above).
- Respect the minimal-patch policy: do not propose refactors,
  abstractions, or improvements beyond the diff's scope.
- Plan and run artifacts live outside the repo; do not flag their
  absence. Any file under `.ai/runs/` appearing in the diff is P0 —
  run artifacts must never be committed.

## AI review triage

When an AI review of a change comes back — a local pass (the `code-review`
skill / codex), the GitHub PR auto-review (Codex, arriving as comments after
Stage 4), or the Stage-3 `app-reviewer`'s own findings — the **main agent**
triages every finding in this fixed order, automatically, without being
re-prompted on the logic. Gathering the raw findings (fetching the comments,
quoting the referenced code) is mechanical and is delegated to the
`codex-triage` skill on a cheaper model; the judgment below is the agent's, on
that gathered evidence. The agent produces the verdict; the **human owns the
final action** — agents never fix, dismiss, file, or defer without that sign-off.

1. **Does it apply?** First and decisive — and the step most often skipped.
   Verify the finding against the actual code, the `docs/integration/` brief,
   and canon, not against the comment's wording. It may already be fixed, be a
   false positive, rest on a misread, or contradict a deliberate decision the
   reviewer cannot see (a scope split across sub-issues, a documented
   exception). A finding that does not apply is dismissed with a one-line
   reason and never reaches step 2.
2. **Severity.** For findings that apply, rate by the § Review guidelines
   buckets (P0 = Blocker, P1 = Major, P2 = Minor/Nit). A genuine correctness or
   logic defect keeps the severity it merits regardless of the P0/P1 lists.
3. **Decision.** Exactly one per finding:
   - **Fix now** — valid and inside the change's scope: fix it in this same
     branch/PR and re-verify.
   - **Dismiss** — did not apply (step 1): the one-line reason is the
     dismissal (and the reply, on a PR comment).
   - **File an issue + re-scope** — valid but off the change's scope: per
     § Defect protocol, open a `Sub-issue` linking the source PR; never patch
     off-scope work ad-hoc.
   - **Defer** — valid but already owned by a planned later sub-issue (the AI
     reviewer did not know the roadmap): note where it lands; no new issue.

Record the triage as a short table — finding (file:line) | applies? | severity
| decision — so the rotation is auditable. The flow is identical for a local
review and a PR review; only the gather differs (the `codex-triage` skill brings
the evidence). The Stage-3 reviewer is the authoritative gate and already
buckets its findings by severity; its `changes-required` items are resolved with
the same step-3 decision set.
