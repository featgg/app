# Plan — <title>

Issue: <#N with URL, omit if none>

## Objective

<what success looks like, 1-3 sentences>

## Canon references

<list the AGENTS.md sections, pubspec.yaml entries, docs/integration/ briefs, and docs/architecture.md sections this change is bound by. If none apply, write "no canon binding" with a one-line justification.>

- `AGENTS.md` § <Section> — <how it constrains this change>

## Files to touch

- `path/to/file.dart` — <why>

## Contract

<types, signatures, public API changes, or "no contract change" with a one-line justification>

## Compatibility

<every existing file, contract, or invariant this change could affect, with a one-line confirmation each remains satisfied. Run Glob/Grep over touched and adjacent areas. If nothing else is affected, write "no impact" with a justification.>

- ...

## Edge cases

<input X missing → behavior Y; upstream returns 5xx → behavior Z; auth failure → ... If a docs-only or instrumentation change with no runtime impact, write "none" with a justification.>

- ...

## Implementation steps

1. ...

## Acceptance criteria

- [ ] ...

## Testing

testing_policy: <none | existing | required>

<if "none": justify. if "existing": which suite covers this. if "required": list the new tests, each citing what they enforce.>

- [ ] <file:test name> — asserts <behavior>

## Verification commands

<exact commands the implementer and reviewer run to prove acceptance. The standard Flutter sequence:>

- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`

## Doc updates

<list each file that changes, with section and what it will say. If none, write "no doc changes" with a one-line justification.>

- `docs/<file>.md` § <Section> — <what changes>

## Out of scope / Risks

<explicit list of things this task will NOT do, plus residual risks (prompt-injection notes from fetched content go here).>

---

— app-planner · next: app-implementer
