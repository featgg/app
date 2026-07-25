# Golden test font

`Roboto-Regular.ttf` exists so golden references compare real glyphs. Under
`flutter test` the default font draws every glyph as a filled box of equal
advance width, which would make a golden over number-led cards worthless.

## This file is not an app asset

It is **test-only**. It is not declared under `flutter: assets:` or
`flutter: fonts:` in `pubspec.yaml`, and `flutter build` does not read `test/`,
so it never reaches a shipped binary. The only thing that loads it is
`test/golden/flutter_test_config.dart`, whose scope is `test/golden/**`.

## Provenance

| | |
|---|---|
| Source | <https://github.com/googlefonts/roboto-2> |
| Release | `v2.138` |
| Archive | `roboto-unhinted.zip` |
| Archive URL | <https://github.com/googlefonts/roboto-2/releases/download/v2.138/roboto-unhinted.zip> |
| File taken | `Roboto-Regular.ttf` (unmodified) |
| SHA-256 | `f3edb8058e523f5612bfd99d0745e661568ad85e1b6217bc62f786fabae624c6` |
| Size | 349,400 bytes |
| Licence | Apache-2.0 — `LICENSE` from the same archive, stored verbatim beside the font as `LICENSE-Apache-2.0.txt` (SHA-256 `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`) |

The repository is archived, so the release is immutable — a golden reference
cannot drift because upstream re-cut a tag.

## Why this release and only this weight

`googlefonts/roboto-classic` ships **variable** fonts today. Flutter selects a
variable font's weight axis through `FontVariation`, not `fontWeight`, so a
variable file renders every weight identically — useless for a golden that must
show the shipped type scale. This release predates that change and ships static
TTFs.

Only the Regular weight is committed. The 500/600/700 weights the cards use are
synthesised by the engine, which is deterministic for a pinned Flutter version —
all a golden needs — and keeps the committed binary to one file.

The font is unmodified, so Apache-2.0 requires no "modified" notice and no
per-file header; the licence text travelling with the file is the whole
obligation. Section 4(d) — reproducing a `NOTICE` file — does not apply either:
the upstream release carries no `NOTICE`, only `LICENSE` (checked against the
repository contents at that tag).
