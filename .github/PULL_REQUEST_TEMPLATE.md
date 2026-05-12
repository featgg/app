## Scope
<1 paragraph: what closes when this PR merges>

## Type
<feat | fix | refactor | docs | chore | test | ci | build — append '!' to the type or scope to signal a breaking change, and describe the break + migration steps in Scope>

## Changeset
<numbered bullets enumerating the logical sub-changes the squash combines; mirrors the atomic commits on this branch and replaces what 'git log main' loses under squash merge>
1. <first change>
2. <second change>

## Verification
- [ ] 'flutter analyze' green
- [ ] 'dart format --set-exit-if-changed .' green
- [ ] 'flutter test' green
- [ ] Secret scanner ran clean (or N/A pre-hook-setup)
- [ ] No backend references in this diff (paths, function names, schemas, env vars)

## Smoke test
<numbered steps to verify runtime behavior end-to-end; write 'N/A' if this PR has no runtime impact>
