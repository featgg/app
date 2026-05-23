---
name: Sub-issue
about: An atomic unit of work tied to a parent epic. One sub-issue closes with one PR.
title: "<type>(<scope>): <one-line subject>"
labels: []
---

<!--
Each sub-issue is one atomic change that closes when its PR merges. The title
follows Conventional Commits subject format and matches the commit message. The
body describes what to do, not how the decision was reached.
-->

## Parent epic

_Issue number or epic identifier of the parent._

<!-- #5  or  EPIC-FE-AUTH -->

## Goal

_What closes when this PR merges. One short paragraph._

<!-- Add the email OTP entry screen with Resend cooldown and navigation to the OTP code screen on submit. -->

## Files to touch (high-level)

_Directories or files this sub-issue is expected to change. The concrete file list belongs in the sub-issue's plan, not the issue body._

<!--
- lib/src/features/auth/presentation/email_screen.dart (new)
- lib/src/features/auth/data/auth_repository.dart (extend)
-->

## Acceptance criteria

_Checkbox list of what proves this sub-issue is done._

<!--
- [ ] Email input validates format client-side
- [ ] Submit triggers OTP send
- [ ] Resend button shows cooldown countdown
- [ ] Submit navigates to OTP code screen on success
-->

## Verification

_Commands run locally before requesting review._

<!--
- flutter analyze
- dart format --set-exit-if-changed .
- flutter test test/features/auth
-->

## Suggested branch + commit

_Branch name and Conventional Commits subject. The branch matches the scope; the commit subject becomes the PR title._

<!-- feat/auth-email-screen + feat(auth): add email OTP entry screen -->

## Public-repo discipline

- [ ] No backend paths, internal function names, schema namespaces, or backend env var names appear in this issue body.
