# Feat.gg App 🎮

**The official frontend client for the Feat.gg app.**

> _Building the future of gaming with transparency._

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
[![License: FSL-1.1-ALv2](https://img.shields.io/badge/License-FSL--1.1--ALv2-blue.svg)](https://fsl.software)

## ⚡ About

This repository hosts the source-available client for **Feat.gg**.

We believe in **Building in public**. While our backend infrastructure remains
private to protect user data and business logic, our client-side code is open
for the community to audit, learn from, and trust.

## 🛠️ Tech stack & architecture

We use a scalable stack focused on performance and developer experience:

- **Framework:** Flutter
- **State Management:** Riverpod
- **Backend:** Supabase
- **Architecture:** Feature-first / Clean architecture

## Agent workflow

This repository is maintained through a four-agent agentic
pipeline (Plan, Implement, Review, Git). See
[OPERATING.md](OPERATING.md) for the operator
guide.

## Git hooks

This repo uses [lefthook](https://github.com/evilmartians/lefthook)
to run local git hooks. On every commit (`pre-commit`):

- `dart format --output=none --set-exit-if-changed .` on the working tree
- `gitleaks protect --staged` to scan staged content for secrets

On every push (`pre-push`):

- `gitleaks detect` to scan the full commit history for secrets
- `flutter analyze` on the working tree
- `flutter test` on the working tree

The analyzer and test suite run on push rather than on every commit so
individual commits stay fast while each push is still gated. The same
format / analyze / test checks also run in CI; the local hooks catch
them earlier. Secret scanning runs locally on commit (staged diff) and
on push (full history) — the last gate before anything leaves the
machine — and again in CI (full history) as defense in depth.

### Install

Install lefthook and gitleaks once per machine, then wire the hooks
into `.git/hooks/` from the repo root.

**macOS:**

```sh
brew install lefthook gitleaks
lefthook install
```

**Windows:**

```powershell
winget install -e --id evilmartians.lefthook
winget install -e --id Gitleaks.Gitleaks
lefthook install
```

**Linux (apt / snap):**

```sh
sudo snap install lefthook
# gitleaks: download the latest binary from
# https://github.com/gitleaks/gitleaks/releases and place it in $PATH
lefthook install
```

Other install methods (npm, scoop, chocolatey, `go install`) are
listed in each tool's upstream docs. If you installed the hooks
before the `pre-push` hook existed, re-run `lefthook install` to wire
it into `.git/hooks/`.

### Skipping a hook

If you absolutely must bypass a hook, use `git commit --no-verify`
(skips the commit-time checks) or `git push --no-verify` (skips the
push-time checks). Skipping is discouraged: the same
format / analyze / test checks run in CI and will block the PR, and
the CI secret scan runs against full history.

## Project setup

Run this after a fresh clone, after `flutter clean`, or when `flutter analyze`
or a build fails because generated code (`*.g.dart`) or l10n output is missing
(both are gitignored and absent until regenerated):

```sh
dart run tool/setup.dart
```

What it does: `flutter clean` → `flutter pub get` (also regenerates l10n) →
`dart run build_runner build --delete-conflicting-outputs`.

If the script itself cannot launch (no Dart on PATH, no package resolution at
all), run the three steps manually:

```sh
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Refreshing generated code

After switching branches or editing a provider/DTO, regenerate the `*.g.dart`
without a full clean rebuild:

```sh
dart run tool/gen.dart
```

It runs `dart run build_runner build --delete-conflicting-outputs` only —
build_runner is incremental, so it regenerates just what changed (seconds). It
skips `flutter pub get`; if dependencies changed, run that (or `setup.dart`)
first. Reach for `setup.dart` when you need a clean rebuild from scratch.

## License

This project is source-available under the [Functional Source License, Version 1.1, Apache 2.0 Future License (FSL-1.1-ALv2)](https://fsl.software). Each version automatically converts to the Apache License, Version 2.0 two years after its publication. See [LICENSE](LICENSE.md) for the full text.
