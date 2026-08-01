# Feat.gg Profile Personalization — Specification (v4)

> **Status:** Approved. Supersedes v3.1 and every earlier personalization
> design. The card model, formats, anatomy and catalog are the decision of
> record on #220.
> **Mockups.** `mockups/layout-editor.html` is normative for editor
> interaction only (§9.2). `mockups/profile-view.html` is a non-normative
> visual reference, kept for the background/theme treatment. Neither is
> normative for card anatomy. Where
> prose and a mockup disagree, the prose wins.

---

## 1. Product thesis

Profile customization is the primary feature of Feat.gg. A profile must feel like a **designed identity**, not a data dashboard. The reference is Steam profile showcases, generalized to 7 platforms.

Two user personas must both be served:
- **The aesthete**: curates art, colors, vibe (hero art, theme).
- **The achiever**: flexes verified data (ranks, milestones, collections).

A good profile is ~60–70% aesthetics legitimized by ~30–40% data.

## 2. Core principles (hard rules)

1. **A card answers one question, with one hero number and one image.** Anything else on the card exists only to explain that number (§6.2), never to compete with it.
2. **A complete datum is number + what it is + what it is about.** With real art, the art carries the subject; without art, the label carries it in full, platform included. A card whose subject cannot be named does not ship.
3. **One card = one platform.** The platform lives inside the sentence that gives the number meaning, never as a decorative tag. Cross-platform identity emerges from composition and from the profile header (§4), never from merging platform stats inside a card.
4. **Theme is profile-level.** All cards, background and placeholder art inherit the active theme palette. No per-card colors in v1.
5. **Hierarchy is mandatory.** Inside a card the hero number dominates; inside the column, full rows dominate pairs. Sizes come from placement (§5), never from user free-resizing.
6. **Bounded free text.** Text cards exist but are hard-capped (140 chars) and never dominant. Free-text *editing* is gated on public-text moderation (§10).
7. **Composition is a contract.** Same proportions, same order, same grouping on every screen size. Only global scale changes. No responsive re-flow of the composition, ever.

Anti-patterns: uniform grids with no hierarchy; walls of text as protagonist; backgrounds that don't share a palette with the cards; a number whose subject is not named; chrome at the top of a card.

## 3. Layout system: the fixed center column

- The profile is a **single vertical column**, `width: min(600px, 100%)`, horizontally centered, side padding 14px.
- On desktop, the extra horizontal space is filled by **profile background art** (theme-derived gradients + subtle noise in v1). The column never stretches.
- Every card's internal proportions are constant across devices. Half cards range ~150px (320px phones) to ~285px (desktop). Design to the minimum.
- No horizontal scrolling under any circumstance.
- This replaces the legacy 1/2/3-column responsive grid (`maxContentWidth 1200`) entirely.

### 3.1 Column metrics

These are the values the profile is designed to; the narrowest supported width (320px) is the width §6.2's no-truncation rule is measured at.

- Column width: `min(600px, 100%)`.
- Design floor: 320px.
- Side padding: 14px.
- Row gap: 14px.

## 4. Profile header

The header opens the profile and is the answer to "who I am": a wide, shallow **cover**, with the avatar straddling its lower edge and the display name, handle and platform marks on the surface beneath.

- **The cover is short on purpose.** The header frames the profile; the cards are the profile. A cover deep enough to fill a phone screen buys atmosphere with the thing people came for, so it is a fraction of the column it spans rather than a multiple of it.
- The cover art is the owner's to choose and change, and it defaults to the best real art already on the profile. Best means the platform the owner features — a choice they have already made about what represents them — and otherwise the first linked platform that publishes any art. A profile with nothing linked falls back to the theme's own fill. Uploading your own cover is deferred (§10).
- The cover **crops** what it is given rather than letterboxing it: it takes the middle of the art at its own proportions, the way a cover does.
- The marks are **text, never logos or brand colors**: they say which accounts stand behind the profile without turning the header into a sponsor wall.
- The identity sits on the theme's surface, not over the art, so nothing there depends on a scrim to stay legible.
- The header is a **visual surface, not a data card** (§6): it carries no datum.
- It is not part of the row model (§9): it cannot be moved, paired or removed.
- It reads as one designed block at the narrow and wide ends of §3.

A large, full-bleed art surface is still wanted — but as a **card the owner places**, not as a fixed block every profile is given. That belongs to the visual-card family (§6), not here.

## 5. Card sizes

Exactly **two rendered sizes**: **`full`** (spans the column) and **`half`** (one slot of a pair row).

- **Size is not stored per card.** It derives from placement: card in a `full` row → full variant; card in a `pair` row → half variant. There is no size field in card settings.
- The legacy `size` token (`small`/`wide`/`large`) and its aspect-ratio mapping (1/1, 2/1, 3/4) are **retired**: the client no longer writes it and ignores it on read. Rendered size is a property of the saved arrangement (§5), not of the widget row.
- Each archetype declares its supported sizes in the **archetype registry** (§7.1): `[full]`, `[half]`, or `[full, half]`. One designed variant per supported size — fixed anatomy per variant, no free ratios.
- An orphan (a `pair` row with one card) renders as a centered half. Designed state, not an error.
- Art placement within bleed cards is per designed variant, not per free size. Which part of the art the variant keeps is the owner's (§6.2).

## 6. Card formats and anatomy

Most cards in the catalog are **data cards**: they answer a question with a number. A second family — **visual cards**, which carry imagery and no datum — opens with **Art** (§7), added in one tap with nothing to choose: it falls back to the first linked platform that publishes artwork. Visual cards are placed, paired and moved exactly like data cards; the distinction surfaces only in the add catalog (§7), where the visual group sits last. User-uploaded imagery is a source the family will gain, not a second family (§10).

**The image rule**, shared by every surface that wants a picture (the cover §4, the avatar, the Art card): resolve a meaningful image if one exists; failing that, render the theme's own ground. No image surface is ever blocked, empty, or a broken-image tile — the fallback is the answer to having nothing to show.

The surfaces share the rule, **never a choice**. Each one's picture is its own: pinning the cover to a platform is a statement about the cover, and a card that moved with it would be a second edit its owner never made. Where a surface has no picture of its own yet, it falls back on its own terms and reads no other surface's preference.

The profile header (§4) is not a card of either family. It is a fixed surface outside the row model.

### 6.1 The two formats

- **Bleed** — real art fills the card edge to edge; a short bottom gradient plus a text shadow guarantees legibility over light art; the datum sits bottom-left, over the art. The designed variant accommodates the art's orientation; which part of the art the variant keeps is the owner's (§6.2).
- **Framed** — no art; the theme's own vertical fill grounds the card, with nothing drawn over it; the datum sits in its own band; a single line closes the card at the bottom; no side or top borders.
- **Nothing sits at the top of any card**: no card title, no platform tag, no date.
- Format is a registry property (§7.1), not per-card special-casing: bleed when real art exists for the card's subject (§7.2), framed otherwise.
- A framed card's ground carries no drawn figure — it is the theme's own vertical fill and nothing else, closing on the solid mid-tone §11 requires. Per-archetype motifs were tried and withdrawn: the shipped vocabulary repeated the shape of the content it sat behind — circles behind the orb shelf, tiles behind the letter shelf — so the two read as a collision rather than as texture. Giving each archetype its own character is still the goal and is taken up with the art work; until then a card earns its distinctiveness from its content, not from its background.

### 6.2 Anatomy rules

- The datum block's share of a card is a range, not a fixed fraction: roughly 23% at the narrowest supported width down to ~13% at the widest. It is largest where the card is smallest, because the label floor below does not scale down with the card — a minimum legible size is a floor in points, not a proportion. A single percentage cannot hold at both ends, and the narrow end is the one to design against.
- Half cards carry exactly one datum, with its subject. Nothing else.
- Full cards carry at most two supporting stats, placed to the right of the hero number, and only when they explain it.
- The hero number uses tabular figures so values do not reflow the layout as they change; labels are uppercase with wide tracking and a floor of 11pt (the `tag` size in `docs/design-system.md` § 6). Where the floor and the block's target share disagree, **the floor wins**: a block that meets a percentage with labels nobody can read has traded away the thing it exists for.
- Values are formatted compactly so a number is never truncated at the narrowest supported width (§3.1).
- Where a datum has no possible visual subject (a whole library, a lifetime count), the number itself becomes the graphic and centres.

**Framing.** A bleed card fills its frame with the art and crops the rest, so on any picture wider or taller than the frame something is lost — and the default middle crop is regularly the wrong thing to keep. The owner moves and sizes the art inside its frame, in edit mode, on the card itself, through an **explicit framing mode**: tap the mark on the card to enter it, drag freely with one finger — both axes — pinch to draw the picture larger or smaller, or use the two marks on the card's edge where there is no pinch, and tap the mark again, or anywhere outside the card, to leave. One card frames at a time.

The mode is what lets the card sit in a scrolling page. A drag on a picture and a scroll of the page are the same gesture, and the page wins that contest — so the mode does not enter it: **while a picture is being moved the page is held still**, and outside the mode the picture is inert and the page scrolls exactly as it always did. Competing for the gesture was tried first and lost on a device, where the drag simply scrolled the profile. Ownership, not delay — an earlier hold-to-drag answered the same conflict and was retired for it: the hold is the convention for picking a card *up*, not for moving a picture inside one, and it read as arbitrary. Shipped products frame either in a dedicated surface or through an explicit in-place mode; none holds. Pointer input gets the same mode for the same reason: there is no long-press convention on a pointer, and every desktop reference uses a visible mode plus a confirm.

The mark is the mode's own switch: centred while idle — every corner of an editing card is already spoken for, and the middle is where a finger lands on a picture — and stepped aside to the top edge while framing, so the confirm never sits on the gesture it exists to enable.

What is stored is a **point in the picture and a size**, not a rectangle cut out of it: where the part that matters is, as a fraction of the picture's own width and height, and how large the picture is drawn. The point stays the anchor — the picture grows about it, so scaling never slides the art out from under the choice already made. A rectangle belongs to one frame shape and stops meaning anything when the card moves between full and half — the two are different proportions. A point stays correct in both, and on every screen, because §2.7 fixes each variant's proportions and only the global scale changes. The size follows the same rule by being a **multiple of what it takes to cover the frame**, never an absolute number of pixels: an absolute size would letterbox the moment the card changed proportions.

Framing pans and scales, with a floor at the size that covers the frame: framing crops, it never letterboxes, and no setting exposes the ground behind the art. A picture nobody has touched is centred at that covering size, which is what every surface has always done. The cover (§4) is on the same rule but is not yet the owner's to move.

**The mark sits over the picture, above everything the card draws on it.** A bleed card puts its number over its own art, behind a gradient that keeps the number legible; a control drawn beneath either is invisible and unreachable, which is what limited framing to the one card that draws nothing over its art. It is centred because every corner of a card in the editor is already spoken for — and because the middle is where a finger lands to move a picture.

**Only where it does something.** A card earns the control by carrying a picture that loaded — because any picture can be drawn larger inside its frame, including one the frame crops none of. One that failed to load, and a card with no picture at all, have nothing to reveal; offering to move nothing and answering the mark with no movement reads as broken. The per-axis rule survives as a statement about **panning at the covering size**: a wide picture in a tall frame moves sideways and not up until it is scaled.

**It is an edit, not an action.** A reframe waits for Done and is dropped by Cancel, like every other edit in the session. Moving a picture and being told the profile has no unsaved changes is the session disagreeing with what the owner just did.

### 6.3 Empty, unavailable and stale states

- A card whose subject cannot be named does not ship (§2, rule 2).
- A card the owner has not filled, or one whose platform cannot support it, renders as an owner-only placeholder and is hidden from visitors (the behavior `docs/integration/personalization.md` § `type` already describes for a showcase bound to an unsupported platform).
- A visitor never sees stale platform data presented as current; the composed render applies the same freshness rule the platform card render applies. How staleness reads visually — withheld or marked — is settled by #232.

## 7. Card catalog

Cards are grouped by the question they answer, never by platform. The category order drives three things at once: the add catalog's groups, a fresh composition's default order, and how a profile reads top to bottom.

| Category | Question | Cards |
|---|---|---|
| Who I am | Who are you across games? | the profile header (§4); Text Note when it lands (§10) |
| What I play | Where does your time go? | Main · Recent |
| How good I am | How good are you? | Rank · Personal Best |
| What I achieved | What did you accomplish? | Milestone · Achievement shelf · Rarest Achievement |
| What I own | What did you build up? | Collection · Collector |
| Art | — | Art (a visual card, §6: it answers nothing) |

Card by card:

| Card | Question it answers | Sizes | Origin | Notes |
|---|---|---|---|---|
| Main | what I play the most | full, half | auto | the platform's top or primary game, character or mode, derived from published data |
| Recent | what I am playing lately | full, half | auto | the game and its recent playtime |
| Rank | how good I am | full, half | auto | current standing on one platform; the full variant carries a larger crest |
| Personal Best | the best I have ever done | full, half | auto | the peak figure with the mode or context it belongs to (#227) |
| Milestone | what I conquered | full, half | curated pick, auto data | one chosen game's progress |
| Achievement shelf | how much I completed | full | auto | whole-library completion |
| Rarest Achievement | the hardest thing I have done | set by the registry when the card lands (#231) | auto | the achievement, its game and how rare it is |
| Collection | what I own or chase | full | curated | a chosen set of games with progress states |
| Collector | how big my library is | full | auto | one platform's whole library aggregated |
| Art | none — it is a picture | full, half | auto art, curation later | added in one tap, unpointed; it falls back to the first linked platform publishing art (§6's image rule) with no datum over it, and reads no other surface's preference. Pointing it at a specific picture arrives with the image picker (§10). Its full variant keeps the 4:5 portrait at column width — a tall plate, not a landscape strip — per §6.1's designed-variant rule |

Not every platform gets every card: a card is offered only where the data genuinely supports it. Per-card availability is declared in the registry (§7.1) and enforced by the add catalog's availability rules. This document does not enumerate a card × platform matrix — the registry owns it, and an enumeration in prose would be stale within a story.

### 7.1 The archetype registry

The registry is the extensibility seam. Each entry declares: the category and question it answers; the sizes it supports (§5); its format (§6.1); whether its content is auto-derived or owner-curated, and at what scope (account vs activity: per queue, per mode, per character, per minigame); and the availability rule that decides whether it is offered at all.

Adding a card is one registry entry plus its designed variants; the layout, editor and persistence do not change.

Its seam today is `lib/src/features/profile/domain/profile_archetype.dart`, which carries the archetype set, the wire-kind mapping, the supported sizes, the format and the category. The remaining fields above — question, origin, scope and availability — are declared there as the catalog work lands; until then they live in each card's own code and in the add catalog.

### 7.2 Platform data and art sources

This table is what decides bleed vs framed (§6.1): where a platform publishes real art for a card's subject, that card is bleed.

| Platform | Key data | Canonical art source |
|---|---|---|
| GW2 | AP, masteries, wallet, legendary armory, PvP/WvW ranks, fractal tier, raid clears, titles | official render service (item/skin icons), spec art |
| LoL | rank per queue, champion mastery | Data Dragon splash arts & portraits |
| WoW | ilvl, spec, mounts, pets, raid/M+ progress | armory character render + media API |
| Chess.com | rating per mode, puzzles, W/L/D | none — framed format (§6.1) |
| Hypixel | Bedwars (beds, stars, FKDR), network level | Minecraft skin render + Feat.gg minigame icons |
| RetroAchievements | points, mastered games | retro box art + achievement badges |
| Steam | games, hours, perfect games, level, achievements | store capsules/headers CDN + achievement icons |

The table lists sources, not per-card guarantees; per-card availability is the registry's (§7.1).

### 7.3 Wire kinds → catalog

| Wire kind | Catalog card |
|---|---|
| `showcase` | Milestone |
| `collection` | Collection |
| `game_collector` | Collector |
| `completionist` | Achievement shelf |
| `rank` | Rank |
| `main` | Main |
| `recent` | Recent |
| `passport` | Identity |
| `art` | Art |

`template`, `composed_card` and `data_menu` are retired: the client neither writes nor reads them, so a row still carrying one resolves to nothing and renders as absent. `platform` is no longer offered when adding a card, but its existing rows still render.

A new card lands with its own kind, added to the personalization brief; `docs/integration/personalization.md` is the only place a wire contract is written.

## 8. Theme system

- **6–8 curated themes** in v1 (no free picker — contrast/legibility guaranteed per theme only with a closed set).
- Token set per theme; everything derives from it:

```css
:root[data-theme="crimson"] {
  --accent:#BC3B4E; --accent-text:#CF6574; --accent-soft:rgba(188,59,78,.16);
  --art-a:#BC3B4E; --art-b:#5A1D2A; --art-c:#2A1016;
}
/* theme-independent base: --bg:#0A0A0D; --surface:rgba(21,21,27,.92);
   --surface2:#1C1C24; --line:#26262F; --text:#EFEFF2; --muted:#96969F; */
```

- Mandatory inheritance: card accents, datum highlights, card grounds, progress bars, background art and placeholder art all read theme tokens; switching re-tints the whole profile live.
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

- **Contrast.** The theme-independent tokens carry body copy and stats, so those ratios hold for every theme: body text (`--text` on `--surface` over `--bg`) ≈ 16:1 and muted text (`--muted`) ≈ 6.4:1 both clear AA-normal (≥4.5); stat numbers (bold `--text`) ≈ 16:1 clear AA-large (≥3.0). `--accent` is an emphasis/UI and large-text color (tags, chip outlines, grounds, borders, graphics) rather than body copy, so it is held to the ≥3.0 bar — the level the default accent meets:

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

- **`--accent-text`: the accent as small text.** A label that wants to carry its theme rather than fall back to `--muted` reads in this token, which is held to AA-normal (≥4.5) on every ground the palette puts text on — `--bg`, `--surface` over `--bg`, and `--surface2`. The lightest of the three is the hard case for light text, so the table below reports both ends. Most accents already clear the bar and pass their own value through; where one does not, the tone is lifted in **lightness only**, leaving the hue and saturation that make the theme recognizable untouched. `--accent` itself never changes: grounds, borders and graphics do not need the lift and would lose the theme's character to it.

  | id | `--accent-text` | : surface | : surface2 | |
  |---|---|---|---|---|
  | crimson (default) | `#CF6574` | ≈ 5.0:1 | ≈ 4.7:1 | lifted from `#BC3B4E` |
  | ember | `#E8763B` | ≈ 6.2:1 | ≈ 5.7:1 | = accent |
  | solar | `#E0A82E` | ≈ 8.6:1 | ≈ 7.9:1 | = accent |
  | chak | `#3BBC8E` | ≈ 7.7:1 | ≈ 7.1:1 | = accent |
  | frost | `#3BC7E8` | ≈ 9.2:1 | ≈ 8.5:1 | = accent |
  | abyss | `#4C82EA` | ≈ 5.0:1 | ≈ 4.6:1 | = accent |
  | arcane | `#9A6DEA` | ≈ 5.0:1 | ≈ 4.6:1 | lifted from `#8E5CE8` |
  | rose | `#E85C9E` | ≈ 5.6:1 | ≈ 5.2:1 | = accent |

  Its first consumer is the profile handle (§4), which read in `--muted` until this token existed.

- **Legacy theme values:** an earlier profile theme field carried a different closed list (`classic|immersive|retro|analyst`, stored but visually inert). Those rows remap to `crimson`; unknown values fall back to `crimson` on read.
- Typography: Space Grotesk (display/numbers) + Inter (body/labels). Dark-first only in v1.
- Placeholder-art rule: bottom paint layer is a **solid mid-tone** (`--art-b`), never a gradient that can fall to black.

## 9. Layout persistence and the composition editor

**The row is the object, not the card.** The profile layout is an ordered list of rows (persisted as an ordered JSON array of rows; the legacy integer `position` and its parking reorder are retired).

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
- The layout is written through the owner-scoped layout write operation documented in `docs/integration/personalization.md` § Layout write (composition editor), which validates row shape, cell counts, ownership and uniqueness. Per-archetype size support is **not** server-validated — the client offers only legal placements (§7.1).

### 9.1 One edit mode

**What is visible on the profile is edited on the profile, by touching it. What the profile does not show lives in settings.** The profile offers exactly two entry points — Edit and Settings — and there is no separate edit-profile destination.

Edit mode is the same render with affordances over it, never another page:

- the avatar, the cover and the name/bio each open their own editor where they sit;
- the theme is picked on the render and re-tints it live — a color decision belongs where the colors are;
- the cards are arranged (§9.2).

Everything in a session is a draft: one Done writes the identity and the arrangement together, one Cancel discards both. The identity is written first, because a failed arrangement is redone with a few drags while typed text has no other copy. A photo upload is the exception and commits on its own — it is a file leaving the device, not a value in a form.

The entry point stays closed while the profile read is in flight: a session writes every profile field back, so opening it on a value known to be stale would let Done revert what settings just changed.

Settings keeps what the profile page does not show: privacy, account, language, and the discovery-feed preview.

### 9.2 Editor interaction (arranging cards)

**A drag moves a card; the ⇆ toggle resizes it.** A card dropped into a gap keeps the size it had: the toggle is already the explicit control for that decision, and coupling size to where a card lands made a second control for the same thing — an owner who moved a card got a resize they never asked for. A drop *beside* another card is still a half placement; there the size is not a side effect, it is what the zone means.

- Each card shows a drag handle in edit mode. Lifting it puts **the card itself** in the air — the same card, capped at ~240px and centered on the pointer — and the slot it left reads vacated until it lands. Auto-scroll near viewport edges. Touch + mouse.
- Drop zones:
  - **Gap between rows** → card becomes its own row, at the size it already had: a full card lands full, a half card lands as a centered orphan. Gap indicators appear while dragging.
  - **Beside another card** (including the empty half of an orphan row — "next to" counts, not just "on top of") → pair, both half. Drop side sets left/right order.
  - **Onto own pair partner** → swap left/right.
- Validity: both cards must support `half`; a full pair accepts no third card; full-only archetypes accept no side-drops. Invalid zones never light up.
- **The landing indicator is the discoverability.** Because the drag holds the nearest landing place rather than demanding the pointer over it, the indicator appears as soon as the card is near one, and it is one vocabulary for both zones: an accent bar, across the column in a gap and down the channel beside the target card's drop side. It is never drawn on the card. The mark names the row edge the carried card will land on, so a bar sitting on the target's art states the opposite of what it means — and every slot edge has the same channel beside it, the column's side padding outside and the row gutter inside, so the mark keeps one relationship to its target whether that target is an orphan half or a full-width card. It **pulses** while a card is in the air — the eye is on the card under the finger during a drag, and motion is what peripheral vision catches (§10's one motion exception; reduced motion suppresses the pulse and leaves the same bar, legible on its own). A lift that can pair with nothing never shows a pair bar: each row it passes hands the aim to the gap beside it, which is how an owner learns that card places whole rows only. A separate outline on every merely-*possible* destination was tried and withdrawn — once acquisition worked by neighborhood it restated what the mark already said, and as a closed rectangle around a whole row it outweighed the mark it was meant to introduce, enclosing the empty half of an orphan row into the bargain. One-time tooltip optional.
- **Acquisition is by neighborhood, not by hover.** The drag holds the nearest landing place to the pointer, not the one under it: gaps and rows tile the editor, a row this card cannot pair with contributes none and falls to the gap beside it, and the empty half of an orphan row acquires the pair as readily as the card does. What is held is always what is highlighted, so nothing lands where it was not shown; it changes hands only when a rival is meaningfully nearer, so a pointer tracking a boundary settles rather than flickering, and each change of target is marked by a haptic tick. Releasing outside the editor — by more than about half a card — holds nothing and cancels cleanly. What this replaces: requiring the pointer to be over the target, which left a full-only card with a ~24px stripe as its only destination.
- **⇆ size toggle** on dual-size archetypes, the one control whose purpose is the size: full → orphan half in place; half → new full row inserted after the origin row, ex-partner stays centered orphan.
- `mockups/layout-editor.html` is normative for editor interaction — its mutations (`removeCard`, `insertAsRow`, `pairWith`, `toggleSize`) and what each drop zone *means* — and for nothing else. Port the behavior, not the code. How a zone is *acquired* is this section's prose, not the mockup's pointer-exact hit test; #208 is where that model was decided.

## 10. Deferred

Out of v1 — deferred, not rejected, except where a line says otherwise.

- **Media** — user-uploaded imagery as a source for the visual family (screenshot galleries, 1 big + 3 small): requires a multi-image upload/moderation/storage pipeline no story covers (#198). The family itself ships with Art (§6); what is deferred is where its pictures may come from.
- **Recap / "Feat Replay"** (monthly wrapped card): requires historical aggregation (monthly stat snapshots) that does not exist. Own epic post-V1; high retention value, not a launch blocker.
- **Public-text moderation** — unblocks Text Note *editing*; one policy for note + display_name + bio, reusing the existing moderation provider seam with text input (#199).
- Uploading your own header art (choosing among the art the profile already carries is part of the header, §4).
- **Motion** — post-V1 polish, with one exception already taken: the composition editor's landing indicator pulses while a card is in the air (§9.2). It earns the exception because it is the only thing telling an owner where a release will land, it sits in the channel beside the card rather than on it and so cannot lean on the card's own contrast, and a drag is exactly the moment the eye is elsewhere. It is scoped to that indicator, it runs only during a drag, and reduced motion suppresses it — the static bar is the one that has to be legible. Nothing else in the product animates.
- Per-platform premium card art; user-derived palettes; multi-asset header art; animated backgrounds.
- 3+ column layouts, vertical spans, free grid — **explicitly rejected**.

## 11. Rollout

The sequencing rule is fixed: the visual regression net lands first (#222), then presentation quality (formats #223, datum rules #224, profile header #225, catalog categories #226), then new vocabulary (#227, #229, #231 and their siblings), then polish and cleanup (#232, #208, #182, #191, #173).

This document describes the target; until a story lands, the surface it replaces still ships. The live, checkable story list is the epic (#20).
