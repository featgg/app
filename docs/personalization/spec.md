# Feat.gg Profile Personalization — Specification (v3.1)

> **Status:** Approved. v3.1 incorporates the pre-task audit decisions (2026-07-18). Supersedes v3 and all previous personalization stories/designs (iteration 1 "data tables", iteration 2 "mixed-platform cards", and the span-based grid model).
> **Normative visual contract:** `mockups/profile-view.html` (layout, hero, themes) and `mockups/layout-editor.html` (editor behavior). When prose and mockup disagree, flag it — do not silently pick one.

---

## 1. Product thesis

Profile customization is the primary feature of Feat.gg. A profile must feel like a **designed identity**, not a data dashboard. The reference is Steam profile showcases, generalized to 7 platforms.

Two user personas must both be served:
- **The aesthete**: curates art, colors, vibe (hero art, theme).
- **The achiever**: flexes verified data (ranks, milestones, collections).

A good profile is ~60–70% aesthetics legitimized by ~30–40% data.

## 2. Core principles (hard rules)

1. **One card = one platform.** Multi-platform identity emerges from profile composition, never from mixing platform *data* inside a card. (The Identity archetype is the sanctioned exception: it shows cross-platform *membership* — which platforms you're on — never merged stats.)
2. **Never a naked number.** Every stat is anchored to art or a visual grid. Data signs, art moves.
3. **Theme is profile-level.** All cards, background and placeholder art inherit the active theme palette. No per-card colors in v1.
4. **Size hierarchy is mandatory.** There is always one dominant hero card. Sizes come from placement, never from user free-resizing (see §5).
5. **Bounded free text.** Text cards exist but are hard-capped (140 chars) and never dominant. Free-text *editing* is gated on public-text moderation (§10).
6. **Composition is a contract.** Same proportions, same order, same grouping on every screen size. Only global scale changes. No responsive re-flow of the composition, ever.

Anti-patterns: uniform grids with no hierarchy; walls of text as protagonist; backgrounds that don't share a palette with the cards; numbers without art.

## 3. Layout system: the fixed center column

- The profile is a **single vertical column**, `width: min(600px, 100%)`, horizontally centered, side padding 14px.
- On desktop, the extra horizontal space is filled by **profile background art** (theme-derived gradients + subtle noise in v1). The column never stretches.
- Every card's internal proportions are constant across devices. Half cards range ~150px (320px phones) to ~285px (desktop). Design to the minimum.
- No horizontal scrolling under any circumstance.
- This replaces the legacy 1/2/3-column responsive grid (`maxContentWidth 1200`) entirely.

## 4. Hero Canvas (profile art)

- Upload standard: **4:5 portrait**. Single asset.
- Render rule (conditional fit): natural 4:5 height at full column width **unless** it exceeds the viewport budget; then the frame shortens, the art shows fully contained and centered, and the sides fill with the same art blurred (blur-extend).

```css
.hero-frame { height: min(78svh, calc((min(600px, 100vw) - 28px) * 1.25)); }
.hero-blur  { position:absolute; inset:-30px; filter: blur(34px) brightness(.65) saturate(1.2); }
.hero-art   { height:100%; aspect-ratio:4/5; margin:0 auto; }
```

- `svh` on web (URL-bar-proof); `MediaQuery`-computed budget in Flutter.
- The art is **always shown complete** (contained mode never crops). If any future crop applies, anchor top-center.
- Profile header above the hero has a fixed max height (~140px) so header + full hero fit the first paint.
- Backend: a dedicated hero upload + moderation path with **4:5 dimension validation**, rate-limited like the avatar upload; contract coordinated via the integration brief.

## 5. Card sizes (v3.1 — replaces small/wide/large)

Exactly **two rendered sizes**: **`full`** (spans the column) and **`half`** (one slot of a pair row).

- **Size is not stored per card.** It derives from placement: card in a `full` row → full variant; card in a `pair` row → half variant. There is no size field in card settings.
- The legacy `size` token (`small`/`wide`/`large`) and its aspect-ratio mapping (1/1, 2/1, 3/4) are **retired**; remove from settings envelope, pickers, option menus and renderers (extend the legacy-cleanup issue accordingly).
- Each archetype declares its supported sizes in the **archetype registry**: `[full]`, `[half]`, or `[full, half]`. One designed variant per supported size — fixed anatomy per variant, no free ratios.
- An orphan (a `pair` row with one card) renders as a centered half. Designed state, not an error.
- Focal-point/reframing control for art (#182) survives, re-scoped: per designed variant, not per free size.

## 6. Card anatomy (from Steam)

Every card has three zones:
1. **Title bar** — card title (left) + platform tag (right, accent color).
2. **Content zone** — art, grid, or visual; the emotional part.
3. **Stat footer** — 2–4 big numbers with small uppercase labels; the proof part. Optional only for pure-art cards (Hero).

## 7. Card taxonomy

Three axes classify every card: **Archetype** (which question it answers), **Scope** (account vs activity: GW2 account/fractals/PvP/WvW/raids; LoL account/queue/champion; Chess time control; Hypixel network/minigame; WoW character/activity; Steam & Retro account/game), **Origin** (data-driven vs user-curated; auto-computed vs user-selected).

### Archetype catalog (v1)

| Archetype | Question | Sizes | Origin | Notes |
|---|---|---|---|---|
| Hero Canvas | "who am I" | full | curated upload (image/GIF) | 4:5; defines profile vibe; moderation applies |
| Identity | "where am I" | full | auto (linked platforms) | cross-platform *membership* collage + platform chips; evolves the shipped Passport card into v3 anatomy/theme |
| Rank | "how good am I" | half | auto | crest/piece visual + rating; per-scope |
| Main / Favorite | "what defines me" | full, half | curated | character/spec/game hero with emblem art |
| Milestone | "what did I conquer" | full, half | curated pick, auto data | game capsule + progress + medal; full variant = wider capsule; evolves the shipped Showcase card |
| Collection | "what do I own/chase" | full | curated | item/game panels with progress states; evolves the shipped Collection & Game Collector cards (Collector = variant) |
| Achievement Grid | "achievement flex" | full | curated icons, auto stats | letter-tile typography pattern + completion stats; the shipped Completionist card maps here as a variant |
| Text Note | "one line about me" | full, half | curated | ≤140 chars, muted styling; **editing gated on public-text moderation** (§10) — renders from seed/empty until then |

### Legacy card mapping (maximize reuse; art infra — scrim, on-art color, tint — carries over)

| Shipped card | v3 destination |
|---|---|
| showcase | Milestone (basis of the archetype) |
| collection | Collection |
| game_collector | Collection, "Collector" variant |
| completionist | Achievement Grid, "Completionist" variant |
| passport | Identity |
| platform / template / composed / data_menu | retired (legacy cleanup issue) |

Exact variant naming is planner latitude **within the registry**; the registry must make adding a new archetype/variant cheap (extensibility is a priority).

### Platform → data & canonical art sources

| Platform | Key data | Canonical art source |
|---|---|---|
| GW2 | AP, masteries, wallet, legendary armory, PvP/WvW ranks, fractal tier, raid clears, titles | official render service (item/skin icons), spec art; bespoke vector art issue applies |
| LoL | rank per queue, champion mastery | Data Dragon splash arts & portraits |
| WoW | ilvl, spec, mounts, pets, raid/M+ progress | armory character render + media API |
| Chess.com | rating per mode, puzzles, W/L/D | none — Feat.gg original piece art (bespoke vector issue) |
| Hypixel | Bedwars (beds, stars, FKDR), network level | Minecraft skin render + Feat.gg minigame icons |
| RetroAchievements | points, mastered games | retro box art + achievement badges |
| Steam | games, hours, perfect games, level, achievements | store capsules/headers CDN + achievement icons |

## 8. Theme system

- **6–8 curated themes** in v1 (no free picker — contrast/legibility guaranteed per theme only with a closed set).
- Token set per theme; everything derives from it:

```css
:root[data-theme="crimson"] {
  --accent:#BC3B4E; --accent-soft:rgba(188,59,78,.16);
  --art-a:#BC3B4E; --art-b:#5A1D2A; --art-c:#2A1016;
}
/* theme-independent base: --bg:#0A0A0D; --surface:rgba(21,21,27,.92);
   --surface2:#1C1C24; --line:#26262F; --text:#EFEFF2; --muted:#96969F; */
```

- Mandatory inheritance: card accents, tags, stat highlights, progress bars, background art, placeholder art all read theme tokens; switching re-tints the whole profile live.
- **The closed set (8 themes).** `theme_id` is one of these lowercase-ascii tokens, rendered in this order (default/brand first, then warm→cool). Each is built to the same recipe: `--art-a` = the bright accent, `--art-b` = a mid tone, `--art-c` = a deep tone, `--accent-soft` = the accent at ~16% alpha.

  | id | accent | art-b | art-c |
  |---|---|---|---|
  | crimson (default) | `#BC3B4E` | `#5A1D2A` | `#2A1016` |
  | ember | `#E8763B` | `#6F391C` | `#351B0E` |
  | solar | `#E0A82E` | `#6C5116` | `#34270B` |
  | chak | `#3BBC8E` | `#1D5A46` | `#0F2A21` |
  | frost | `#3BC7E8` | `#1C606F` | `#0E2E35` |
  | abyss | `#4C82EA` | `#243E70` | `#111E36` |
  | arcane | `#8E5CE8` | `#3E2775` | `#221540` |
  | rose | `#E85C9E` | `#6F2C4C` | `#351524` |

- **Contrast.** The theme-independent tokens carry body copy and stats, so those ratios hold for every theme: body text (`--text` on `--surface` over `--bg`) ≈ 16:1 and muted text (`--muted`) ≈ 6.4:1 both clear AA-normal (≥4.5); stat numbers (bold `--text`) ≈ 16:1 clear AA-large (≥3.0). The accent is an emphasis/UI and large-text color (tags, chip outlines) rather than body copy, so it is held to the ≥3.0 bar — the level the default accent meets:

  | id | accent : surface | ≥3.0 (UI/large) | ≥4.5 (normal) |
  |---|---|---|---|
  | crimson | ≈ 3.4:1 | pass | brand baseline |
  | ember | ≈ 6.3:1 | pass | pass |
  | solar | ≈ 8.7:1 | pass | pass |
  | chak | ≈ 7.8:1 | pass | pass |
  | frost | ≈ 9.1:1 | pass | pass |
  | abyss | ≈ 5.1:1 | pass | pass |
  | arcane | ≈ 4.3:1 | pass | brand baseline |
  | rose | ≈ 5.7:1 | pass | pass |

- **Migration note:** an earlier profile theme field carried a different closed list (`classic|immersive|retro|analyst`, stored but visually inert). Migrate to this list; those rows remap to `crimson`; unknown values fall back to `crimson` on read.
- Typography: Space Grotesk (display/numbers) + Inter (body/labels). Dark-first only in v1.
- Placeholder-art rule: bottom paint layer is a **solid mid-tone** (`--art-b`), never a gradient that can fall to black.

## 9. Row-based layout model

**The row is the object, not the card.** The profile layout is an ordered list of rows, persisted as JSON (new column; the legacy integer `position` + parking reorder is retired).

```ts
type Row =
  | { t: 'full'; c: [CardId] }
  | { t: 'pair'; c: [CardId | null, CardId | null] }; // at least one non-null

type Layout = Row[];
```

Invariants (these delete the legacy layout bugs by construction):
- Rendering a row never inspects other rows. **No auto re-flow, no auto-pairing, ever.**
- Orphan pair → single half card, centered.
- Mutations are local: at most origin row + destination row change.
- Size is a consequence of placement (§5); the editor only offers legal placements per the archetype registry.
- Server-side validation required (row shape, known card ids, each card at most once, size supported by archetype). The current direct-write model cannot express this, so it points to a new validated write path — mechanism decided at planning, coordinated via the integration brief.

### 9.1 Editor interaction (edit mode)

Single-gesture model: **size and position are one decision** — where you drop determines the size.

- Each card shows a drag handle in edit mode. Compact ghost (max ~240px) follows the pointer; auto-scroll near viewport edges. Touch + mouse.
- Drop zones:
  - **Gap between rows** → card becomes its own row (full variant; centered orphan if the archetype is half-only). Gap indicators appear while dragging.
  - **Beside another card** (including the empty half of an orphan row — "next to" counts, not just "on top of") → pair, both half. Drop side sets left/right order.
  - **Onto own pair partner** → swap left/right.
- Validity: both cards must support `half`; a full pair accepts no third card; full-only archetypes accept no side-drops. Invalid zones never light up.
- **Discoverability:** on lift, every valid pair destination glows (dashed accent outline) — the system explains itself at the moment of need. One-time tooltip optional.
- Complementary **⇆ size toggle** on dual-size archetypes: full → orphan half in place; half → new full row inserted after the origin row, ex-partner stays centered orphan.
- Reference implementation: `mockups/layout-editor.html` — its mutations (`removeCard`, `insertAsRow`, `pairWith`, `toggleSize`) and drop-zone semantics are normative. Port the behavior, not the code.

## 10. Deferred (explicitly out of v1, each with its own issue)

- **Media archetype** (user-uploaded screenshot galleries, 1 big + 3 small): requires a multi-image upload/moderation/storage pipeline no story covers. Reuses the hero pipeline when taken.
- **Recap / "Feat Replay"** (monthly wrapped card): requires historical aggregation (monthly stat snapshots) that does not exist. Own epic post-v1; high retention value, not a launch blocker.
- **Public-text moderation** (unblocks Text Note *editing*; one policy for note + display_name + bio, reusing the existing moderation provider seam with text input): lands together with the future card-content-editing story, not with Stories 1–3.
- Per-platform premium card art; user-derived palettes; multi-asset hero; animated backgrounds.
- 3+ column layouts, vertical spans, free grid — **explicitly rejected**.

## 11. Rollout

Pre-task (investigation): **done 2026-07-18** — audit informed this v3.1.

Three demo-able stories, strictly ordered, each mergeable alone:
1. **Profile render (read-only)** — column, rows, archetypes+variants (full/half), hero, anatomy, seed data, layout read path. See #195.
2. **Theme system** — curated themes + full inheritance + migration from the legacy theme list. See #196.
3. **Composition editor** — edit mode, drag & drop, ⇆ toggle, validated persistence. See #197.

Legacy cleanup (retired cards, size token, span grid, parking reorder) rides the extended cleanup issue, sequenced with Story 1.
