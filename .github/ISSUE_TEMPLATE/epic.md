---
name: Epic
about: A large initiative that groups multiple sub-issues toward one milestone goal.
title: "[EPIC] EPIC-FE-<DOMAIN>: <one-line goal>"
labels: []
---

<!--
Use this template for epics that group several sub-issues. Each epic should have
a clear first vertical slice gate that proves the whole stack works end-to-end.
The body describes what the epic delivers, not how the decision was reached —
discussion context belongs in PR descriptions or planning docs.
-->

## Epic identifier

_Stable identifier used across commits, branches, and PR descriptions._

<!-- EPIC-FE-AUTH -->

## Goal

_What the epic delivers in one short paragraph. End-user perspective._

<!-- Login with email OTP, Google, and Discord; persistent session; auto-routing post-auth. -->

## Scope — in

_What is included. Bullet list._

<!--
- Email OTP flow
- Google OAuth flow
- Session restoration
-->

## Scope — out

_What is explicitly excluded so future contributors don't expand scope silently._

<!--
- Apple Sign-In (deferred)
- Magic-link auth
-->

## Sub-issues

_Checklist of sub-issues. Link them as they are filed._

<!--
- [ ] #N — Email OTP entry screen
- [ ] #N — OAuth providers
- [ ] #N — Session restoration
-->

## Success criteria

_Checkbox list of what proves the epic is done. The first item must be the first vertical slice gate._

<!--
- [ ] First vertical slice: email OTP -> session -> land on profile (gate)
- [ ] All planned providers integrated
- [ ] Session survives app restart
-->

## Dependencies

_External or cross-epic blockers._

<!--
- Depends on EPIC-FE-INFRA completion
- Requires integration snapshot at app/docs/integration/
-->

## Public-repo discipline

- [ ] No backend paths, internal function names, schema namespaces, or backend env var names appear in this issue body.
