# Agent workflow

This repository is maintained through a four-stage agentic
pipeline. Each stage is owned by a single subagent with a narrow
remit; the operator drives the rotation between stages, reviews
each artifact, and approves the gates the harness raises. The full
contract for each stage lives in `.claude/agents/`. When this guide
and `AGENTS.md` disagree, `AGENTS.md` wins. Canon precedence:
`AGENTS.md` → `pubspec.yaml` → `docs/integration/` →
`docs/architecture.md` (forthcoming) → code. See `AGENTS.md`
§ Source precedence.

## The four stages

Work runs four stages in order:

1. **Plan** — `app-planner` produces `plan.md`.
2. **Implement** — `app-implementer` writes code and tests.
3. **Review** — `app-reviewer` re-runs verification and audits.
4. **Git** — `app-git` commits and opens the pull request.

Rationale: **auditability** (each stage produces a written
artifact — `plan.md`, `implementation-report.md`,
`review-report.md`, the pull request — so reasoning is
recoverable), **scope discipline** (planner owns scope; downstream
stages refuse to expand it per `AGENTS.md` § Defect protocol), and
**separation of concerns** (narrow tool surfaces; failures
localize).

## One issue, one plan, one pull request

The default loop:

1. Pick a GitHub issue.
2. Run the planner to produce one `plan.md`.
3. Run the implementer against the plan.
4. Run the reviewer; iterate with the implementer until `approve`.
5. Run the git stage to open one pull request.
6. Squash-merge to auto-close the issue via `Closes #N`.

The operator starts a fresh agent session per pull request to keep
context clean and the pipeline reproducible. Genuinely inseparable
issues may be bundled into one pull request (both numbers under
`## Closes`); otherwise the default is one issue per pull request.

## Per-stage responsibilities

### Plan — `app-planner`

Reads canon and touched code; writes a plan complete enough that
the implementer asks no clarifying question. Runs in **PLAN MODE**
or **CLARIFY MODE**. Declares a `testing_policy` (template at
`.ai/templates/plan.md`).

- **Artifact.** `.ai/runs/<run>/plan.md`.
- **Handoff footer.** `— app-planner · next: app-implementer`.

### Implement — `app-implementer`

Executes the plan verbatim — no scope expansion, no refactor, no
invented contracts, no git. Runs exactly the plan's "Verification
commands" (sequence at `AGENTS.md` § Commands). Out-of-scope
defects go under `## Pending` per § Defect protocol.

- **Artifact.** `.ai/runs/<run>/implementation-report.md`.
- **Handoff footer.** `— app-implementer · next: app-reviewer`.

### Review — `app-reviewer`

Re-runs every "Verification commands" entry from its own shell and
audits the diff against canon (scope, KISS, security, layering,
testing-vs-policy, public-repo discipline). Verdict is `approve`
or `changes-required`; an ad-hoc fix for an out-of-scope defect is
a blocker even when correct.

- **Artifact.** `.ai/runs/<run>/review-report.md`.
- **Handoff footer.** `— app-reviewer · next: app-implementer | app-git`.

### Git — `app-git`

Commits and pushes only — no edits to source, docs, tests, hooks,
workflows, or templates. Groups changes into atomic commits, opens
the pull request via `.github/PULL_REQUEST_TEMPLATE.md`. Operator
approves the `git push` `ask` prompt. No auto-generated footer in
commits or pull-request bodies (no `Co-Authored-By`, no `Generated
by an AI assistant`).

- **Artifact.** Pull request; handoff footer in chat.
- **Handoff footer.** `— app-git · next: done | human`.

## Run directory

Stage artifacts live in `.ai/runs/<YYYY-MM-DD>-<slug>/`, gitignored
and never committed. On `changes-required` iterations existing
artifacts are amended in place; a defect that forks a sub-issue
starts a fresh run directory.

## Operator role at each stage

Each agent ends with a handoff footer on its own line
(`— <agent-name> · next: <agent-name | human | done>`; see
`AGENTS.md` § Handoff convention). When `next` names an agent, the
operator starts it; `human` means the agent needs operator input;
`done` means the run is finished.

- **After Plan** — read `plan.md`; start the implementer.
- **After Implement** — read the implementation report; start the
  reviewer.
- **After Review** — on `approve`, start the git stage; on
  `changes-required`, restart the implementer with the reviewer's
  findings as scope.
- **At Git** — read pre-push output (staged files, commits, diff);
  approve the `git push` `ask` prompt.
- **After Git** — review the pull request on GitHub and squash-
  merge when satisfied. Agents never merge pull requests; agents
  close issues only with explicit human permission.

Pull-request titles are Conventional Commits, branches mirror
titles, squash-merge only, signed, linear history; bodies use
`.github/PULL_REQUEST_TEMPLATE.md`. Canonical rules at `AGENTS.md`
§ Workflow.

## Local pre-commit hooks

A local pre-commit hook runs the formatter, the analyzer, the test
suite, and a secret scan against staged content — the same checks
CI enforces, just earlier. The escape hatch `git commit --no-verify`
skips it; CI re-runs the checks against full history. Per-OS
install steps live in the
[Pre-commit hooks](README.md#pre-commit-hooks) section of
`README.md`.

## Continuous integration

CI runs two jobs on every pull request to `main` and every push to
`main`: a Flutter job that runs the canonical verification sequence
and a secrets job that scans full history. Branch protection
requires both green before merge. CI workflows are operator-
maintained; a workflow change is its own pull request.

## Manual operator steps

A few setup tasks live outside the agent pipeline because they
require interactive GitHub settings or per-machine installation:

- **Branch protection on `main`** — required status checks, PR
  review, signed commits, linear history, no force push, head-
  branch auto-delete.
- **Private vulnerability reporting** — enable the form so the
  channel `SECURITY.md` advertises is live.
- **Pre-commit hook installation** — per-machine; commands in the
  [Pre-commit hooks](README.md#pre-commit-hooks) section of
  `README.md`.
- **GitHub Project board automation** — the `issue closed → Done`
  rule moves cards on merge auto-close.
- **Secret-scanner provisioning** — local and CI scanners installed
  and updated by the operator.
- **Anything on github.com** — repository visibility, default
  branch, collaborator access, issue-template defaults, project-
  board columns.

GitHub renames settings pages occasionally; the wording above is
deliberately generic to survive a UI rename.

## Backend integration discipline

Frontend code that calls the backend runs against the documented
public HTTPS endpoints under [`docs/integration/`](docs/integration/) —
the API canon. `docs/integration/README.md` defines the receive
contract for briefs (what they MUST, MAY, and MUST NOT contain).
Until a brief exists for an endpoint, code that would call it is
stubbed at the data layer with a typed not-implemented failure (see
`AGENTS.md` § Public-repo discipline).
