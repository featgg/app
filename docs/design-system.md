# Feat.gg — Design System Canon

> **Status:** Living draft · `v0.1` · updated 2026-06-01
> **Stability:** Provisional — expect frequent change. This doc is meant to be edited freely.

---

## 1. Purpose & scope

This is the **single source of truth for Feat.gg's visual and UX decisions** — the concrete values and rules that `docs/architecture.md` deliberately leaves out.

**It is:**
- The canonical record of *what* the values are (palette, type scale, spacing, radii, breakpoints) and *why*.
- The reference humans **and agents** (planner / implementer / reviewer) consult so the UI stays coherent as it scales.
- The contract behind "no contradicting hard-coded design values in code": token code is the *implementation* of this doc.

**It is not:**
- The token code itself. Tokens live in Dart; `ThemeData` derives from them; the tokens trace back to the decisions here.
- A pixel-perfect component spec. Component sections give *direction*, not final specs.
- An architecture doc. Only client-side visual/UX decisions live here.

---

## 2. How this stays loose (read this first)

Everything derives from a **minimal set of source values**. Change these and the rest follows; you should almost never edit a value in two places.

```text
# Source values — the only things you normally change
brand / seed          #BC3B4E        (PROVISIONAL — current best, not final)
neutral-dark-base     #0B0D10
font-display          Space Grotesk
font-body             Inter
spacing-base          4 px           (8pt grid)
radius-card           16 px
```

Rules of the road:
- **One value, one home.** Roles (e.g. `primary`, `surface`) point at source values; components point at roles. Never hard-code a raw hex/size in a widget.
- **Mark provisional things.** Anything not settled is tagged `(PROVISIONAL)` and listed in §13.
- **Swapping the brand = one line.** Because color is seed-driven (M3) + a single accent override, rebranding is changing `brand/seed` and regenerating.
- When in doubt, prefer *fewer* tokens over a complete-but-rigid set.

---

## 3. Design principles / mood

The agreed personality: **modern, with gamer energy, but clean and legible — dark-first, restrained, art-forward.** Not neon, not cyberpunk, not luxury/executive.

1. **The game art carries the richness; the UI is calm.** Chrome is near-monochrome (white/grey on near-black). Color is a precision instrument, not decoration.
2. **The accent means "you achieved something."** The brand red shows up almost exclusively on achievement / progress / identity moments — see the usage rule in §5.2. This gives the achievement system its own visual signature and makes unlocking feel special.
3. **Depth, tactile, console-dashboard feel.** Layered glassmorphism cards, game artwork bleeding into the card behind a dark gradient scrim for legibility, soft realistic elevation.
4. **Restraint over richness.** If a screen feels busy, remove color before removing content.
5. **Built for 3 languages.** Layouts assume text grows 15–30% (es/pt vs en). Slack everywhere, no fixed widths.

Reference: the converged feed mockup (dusty-red accent, glass cards, art-forward) is the visual anchor for §11.

---

## 4. Theme strategy

- **Dark-first, both shipped from day one.** Dark is the hero experience; light is a first-class citizen, not an afterthought.
- **Seed-driven (Material 3).** The `ColorScheme` is derived from a seed via `ColorScheme.fromSeed`; specific roles are overridden (see §6).
- **Tokens are theme-agnostic.** Components reference semantic roles (`surface`, `onSurface`, `primary`…), never a literal light/dark value. Theme switch = swap the role values.
- **Respect the system theme** by default; allow manual override in settings.

**M3 note (decide at implementation):** `fromSeed` desaturates and harmonizes the seed, so a punchy accent can come out muted. Two acceptable approaches:
- **(A)** Seed neutral → surfaces stay truly neutral → **override `primary`** (+ on/container) with the brand red. *Recommended* for "neutral UI + scarce accent."
- **(B)** Seed = brand red with a low-chroma scheme variant → then override surface roles back to neutral near-black.
Either way, the role values in §6 are the target; the seed is just how we get there.

---

## 5. Color

### 5.1 Brand / accent

| Token | Dark | Light | Notes |
|---|---|---|---|
| `primary` (fills, icons, rings) | `#BC3B4E` | `#BC3B4E` | **PROVISIONAL** brand red (dusty rose). |
| `onPrimary` (text/icon on red) | `#FFFFFF` | `#FFFFFF` | AA on the red fill. |
| `primaryText` (red text on surface) | `#E76A7D` | `#BC3B4E` | Use this lighter tint for red *text* on dark (small red text at `#BC3B4E` fails AA). |
| `primaryContainer` (badge/chip bg) | `#2E151A` | `#FBE0E4` | Subtle red-tinted container. |
| `onPrimaryContainer` | `#F0B8C0` | `#5A0E1A` | |

### 5.2 Accent usage rule (the heart of the identity)

The accent appears **only** in these places. Everything else is neutral white/grey:
- the **feat / achievement** icon (hex badge),
- the **level-up progress ring**,
- the **active bottom-nav** item,
- the **active "like"** heart.

Not on: tab labels, post-type tags, comment/share/clap icons & counts, usernames, the compose (+), generic buttons. Default interactive chrome uses `onSurface`/neutral, **not** `primary`. (This is a usage discipline, since M3 components reach for `primary` by default.)

### 5.3 Neutral surfaces & text

**Dark**
| Role | Hex | Use |
|---|---|---|
| `background` | `#0B0D10` | Scaffold. |
| `surface` | `#101317` | Base surface. |
| `surfaceContainerLow` | `#15181D` | Subtle raise. |
| `surfaceContainer` | `#1A1E24` | Cards (base of the glass stack). |
| `surfaceContainerHigh` | `#20252B` | Raised cards, sheets. |
| `surfaceContainerHighest` | `#272D34` | Top elevation. |
| `outlineVariant` | `#2A2F37` | Hairline dividers. |
| `outline` | `#3A4049` | Borders, input outlines. |
| `scrim` | `rgba(0,0,0,.55)` → `0` | Gradient over game art for legibility. |
| `onSurface` | `#F3F5F8` | Primary text (near-white). |
| `onSurfaceVariant` | `#AAB2BD` | Secondary text. |
| `onSurfaceDim` | `#6F7884` | Meta (timestamps, counts). |
| `disabled` | `#4A5159` | Disabled text/icons. |

**Light**
| Role | Hex | Use |
|---|---|---|
| `background` | `#F8F9FB` | Scaffold. |
| `surface` | `#FFFFFF` | Base surface. |
| `surfaceContainerLow` | `#F2F4F7` | |
| `surfaceContainer` | `#ECEFF3` | Cards. |
| `surfaceContainerHigh` | `#E5E9EE` | Raised. |
| `surfaceContainerHighest` | `#DDE2E9` | Top elevation. |
| `outlineVariant` | `#E2E6EB` | Hairlines. |
| `outline` | `#C5CCD4` | Borders. |
| `onSurface` | `#14171B` | Primary text. |
| `onSurfaceVariant` | `#545C66` | Secondary text. |
| `onSurfaceDim` | `#79828D` | Meta. |

### 5.4 Semantic colors

`success` doubles as the **"connected" / verified** indicator (the green check), so it's part of the brand vocabulary, not just an alert color.

| Token | Dark | Light | Use |
|---|---|---|---|
| `success` | `#2ECC71` | `#15A34A` | Connected, verified, positive confirmation. |
| `warning` | `#F5B339` | `#C77700` | Caution, non-blocking issues. |
| `error` | `#FF5A52` | `#DC2626` | Errors, destructive actions. |
| `info` | `#4AA3FF` | `#1E6FE0` | Neutral informational states only. |

Containers/`on*` tints follow the same pattern as §5.1 (dark, low-chroma background + light text; reverse for light theme).

> **Watch-item — brand red vs error red.** Brand `primary` is a **dusty rose** (`#BC3B4E`); `error` is a **hotter, brighter red** (`#FF5A52`). They are different tokens and never share a context (errors live in banners/snackbars/validation; the brand accent lives in achievement/identity moments). Re-check this separation in real screens. **Never** use `error` decoratively or `primary` for error states.
>
> **`info` is blue on purpose, but scarce.** Blue/cyan is *not* a brand color (avoided the "Battle.net" look). `info` blue appears only in informational UI, never as chrome.

### 5.5 M3 role mapping (cheat sheet)

`primary`→brand red · `secondary`/`tertiary`→keep neutral or low-chroma (don't introduce a second loud hue) · `surface*`→§5.3 · `error`→§5.4 · `outline`/`outlineVariant`→§5.3.

---

## 6. Typography

**Families** (via `google_fonts`):
- **Display:** `Space Grotesk` — headings, hero numbers (feat name, level), wordmark feel. (PROVISIONAL — confirm pt/es diacritic glyph coverage: ã, õ, ç, ñ.)
- **Body / UI:** `Inter` — everything dense and multilingual.
- **KISS fallback:** if two families is too much, ship **Inter only**; the scale still holds.

**Scale** (base sizes in `sp`; all sizes must respect text scaling — see §10).

| Token | Font | Size | Weight | Line height | Use |
|---|---|---|---|---|---|
| `display` | Space Grotesk | 32 | 700 | 1.15 | Hero moments: feat name, level number, empty-state titles. |
| `headline` | Space Grotesk | 24 | 600 | 1.20 | Screen / section titles. |
| `title-lg` | Space Grotesk | 20 | 600 | 1.25 | Card titles, prominent names. |
| `title-md` | Inter | 16 | 600 | 1.30 | Subtitles, list headers, usernames. |
| `body-lg` | Inter | 16 | 400 | 1.50 | Primary reading text. |
| `body-md` | Inter | 14 | 400 | 1.50 | Default body, descriptions. |
| `label` | Inter | 14 | 500 | 1.20 | Buttons, tabs, interactive labels. |
| `caption` | Inter | 12 | 400 | 1.40 | Timestamps, meta, counts. |
| `tag` | Inter | 11 | 600 | 1.30 | UPPERCASE pills (FEAT UNLOCKED), +0.5 letter-spacing. |

**Weights:** 400 / 500 / 600 / 700 (added 600 SemiBold vs the old placeholder set).

**i18n:** generous line-heights and the slack in spacing absorb es/pt expansion. Never set fixed-height text containers.

---

## 7. Spacing

8pt grid, base unit **4px**. `4` and `12` exist for fine control; default to `16` for padding and `24` for separating cards/sections.

| Token | px | Alias | Use |
|---|---|---|---|
| `space-1` | 4 | xs | Icon↔label gaps, fine nudges. |
| `space-2` | 8 | sm | Tight internal padding, chip padding. |
| `space-3` | 12 | — | Compact gaps. |
| `space-4` | 16 | md | **Default** padding, card inner padding. |
| `space-6` | 24 | lg | Between cards, section spacing. |
| `space-8` | 32 | xl | Large section breaks. |
| `space-10` | 40 | 2xl | Screen-level gaps. |
| `space-12` | 48 | 3xl | Major separation. |

---

## 8. Radius

| Token | px | Use |
|---|---|---|
| `radius-xs` | 4 | Inputs, small chips. |
| `radius-sm` | 8 | Buttons, small controls. |
| `radius-md` | 12 | Images/elements inside cards. |
| `radius-lg` | 16 | **Cards** (feed cards), top of sheets. |
| `radius-xl` | 24 | Large containers, bottom sheets, modals. |
| `radius-full` | 999 | Avatars, pills/tags, FAB. |

Rationale: soft, modern feel → cards at `16`; avatars and tags fully round; keep small interactive controls at `8` so they don't read as "blobby."

---

## 9. Breakpoints, responsive & adaptive

Mobile-first; aligns with M3 window size classes. Phone is the design target. Web is TBD; desktop is best-effort.

| Class | Range (px) | Target |
|---|---|---|
| `compact` (phone) | 0–599 | Design target. Single column. |
| `medium` (tablet) | 600–1023 | Wider gutters; 2-col feed / master-detail begins. |
| `expanded` (desktop) | ≥ 1024 | Multi-column; max content width ~1200, centered. |

### 9.1 Posture
- **Mobile-first.** We design for `compact`; every other size is **reflow, not redesign** — the same components rearranged, not new screens.
- The table above owns *what* reflows per class; the rest of §9 is *how* we approach it.

### 9.2 Responsive (size)
- **Navigation adapts with width:** bottom nav on `compact` → navigation rail on `medium`+ (persistent rail/drawer on `expanded`). A principle, not a per-screen spec.
- **Max content width** on `expanded` (~1200, centered) — no full-bleed line lengths on wide screens.
- Prefer reflowing existing components over bespoke wide layouts.
- **`medium` / `expanded` detail is provisional & best-effort** — locked when that scope is real (§13). Don't over-spec it now.

### 9.3 Adaptive (platform) — feel, not look

**Decision: one brand visual language everywhere; platform-native only in the *feel*.** The custom Material 3 theme (this doc) is the *look* on iOS, Android, and Windows — we do **not** build a parallel Cupertino/native component set (it would fight the brand and double the work — KISS). What we honor per platform is interaction *feel*, where Flutter provides it for free.

- **Feel = native (where free):** scroll physics, back gesture / page transitions, haptics, system pickers (date/time), share sheet, text-selection controls, keyboard behavior — via Flutter's `.adaptive` constructors (`Switch.adaptive`, `showAdaptiveDialog`, `CircularProgressIndicator.adaptive`, `Slider.adaptive`…) and platform defaults.
- **Look = Material (always):** the branded theme owns colors, type, shape, glassmorphism, and component visuals on every platform. Never use an `.adaptive` variant that changes the *visual* brand.
- **No hand-forking the platform** beyond those adaptive constructors (KISS); add a `Theme.of(context).platform` branch only when a concrete surface demands it (§13).
- **Portrait primary**, landscape best-effort; foldables out of scope for now.
- **Windows / desktop:** best-effort, Material everywhere; no native Windows controls.

### 9.4 Implementation rule
- One **window-size-class helper** (app `core` layer, per `architecture.md`) is the source; widgets **read the size class, never raw pixel checks** — same anti-hard-coding rule as colors and spacing.
- Responsive widgets are **deferred until a screen actually reflows** (loose — same posture as the loading widgets).

---

## 10. Accessibility (non-negotiable)

- **Contrast WCAG AA:** 4.5:1 for text, 3:1 for large/graphical elements. Use `primaryText` (not `primary`) for small red text on dark.
- **Touch targets ≥ 48dp**, with spacing between adjacent targets.
- **Text scaling:** size in `sp`; respect `MediaQuery.textScaler`; no fixed-height text boxes. Test at 130%.
- **Visible focus states** on all interactive elements.
- **Never encode meaning by color alone:** pair `success` green with a check + label; pair `error` with an icon + text.
- **i18n:** design for +15–30% text length; avoid truncation-critical layouts and fixed widths.

---

## 11. UX rules (required)

### 11.1 Recoverable error → snackbar vs banner

- **Snackbar** — transient, low-severity, the user can ignore or one-tap retry. Auto-dismiss (~4–6s), never blocks. One line, at most one action. Use for: a failed background action, optimistic-update rollback, "copied", a blip on a non-critical fetch.
- **Banner** — persistent, in-context, higher severity but still recoverable; affects the whole surface and should be acknowledged. Stays until resolved/dismissed, inline at the top of the affected screen. Use for: offline / degraded state ("Showing cached data"), something the user can work around but should address.
- **Rule of thumb:** transient + ignorable → snackbar; persistent + state-level → banner.

### 11.2 Blocking error → full screen with retry

Used when the screen can't render its core content at all (initial load failed with no cached data, session/auth error, hard server error).
- Restrained icon/illustration (monochrome, optional dusty-red accent), a short title ("Couldn't load your feed"), a one-line cause-agnostic explanation, a primary **Retry**, and a secondary escape (back / help).
- No fake chrome behind it. Respects theme. Copy is human and i18n-friendly (no fixed width).

### 11.3 Loading → skeleton vs spinner

- **Skeleton** — when the *shape* of incoming content is known (feed cards, profile header, lists). Mirrors the layout with shimmer placeholders; reduces layout shift. **Default** for structured content.
- **Spinner** — when shape is unknown or the wait is small/indeterminate (button submit state, pull-to-refresh, a small inline action).
- **Nothing** — for waits under ~300ms, show nothing (avoid a flash).
- **Rule of thumb:** structured content → skeleton; action/indeterminate → spinner; ultra-short → nothing.

---

## 12. Component direction (high-level, not specs)

**Feed item (post card)** — the brand-defining surface.
- Glassmorphism card; game art bleeds into the background behind a dark gradient scrim.
- Header row: avatar + username (+ verified) + timestamp + overflow (`⋯`).
- Post-type tag as a **neutral** pill (Feat Unlocked / Game Connection / Level Up) — not red.
- Subject in `title-lg`/`display`; the **feat hex-badge** or **level ring** is where the brand red lives.
- Reaction row: active **like = red**; comment/share/clap = neutral, with counts.
- `radius-lg`, soft elevation + translucency.

**Game card** — a connected game/account.
- Art-forward: cover art, title, platform logo, connected state (`success` check), optional stats. Compact, grid-friendly.

**Profile header** — identity anchor.
- Large avatar, display name, handle, key stats (feats / level / games), connected-platform chips.
- The header stays a **stable, branded anchor**; the profile body is the highly-customizable / widget surface (later). Keep the anchor consistent even as the body flexes.

**Avatar / identity.**
- Circular (`radius-full`). Sizes: 24 / 32 / 40 / 48 / 64.
- Status: online = `success` dot. Verified badge. A brand-red ring is reserved for special/featured states only (stay scarce).

---

## 13. Open questions / provisional

- [ ] **Exact brand red** — `#BC3B4E` is the current best but not locked.
- [ ] **M3 derivation** — approach A vs B in §4 (decide at implementation).
- [ ] **Light-mode glass / art-scrim** — validate text legibility over bright artwork.
- [ ] **Brand-red vs error-red** separation — monitor in real screens (§5.4).
- [ ] **Display font** — confirm Space Grotesk + pt/es glyph coverage; KISS fallback is Inter-only.
- [ ] **Tablet / desktop reflow detail** — master-detail, grid column counts, rail/drawer behavior. Best-effort; lock when that scope is real (§9.2).
- [ ] **Per-platform adaptive coverage** — which surfaces need iOS/Android-specific treatment beyond Flutter's adaptive defaults.

---

## 14. Decision log

| Date | Decision |
|---|---|
| 2026-05-31 | Dark-first, ship both light & dark from day one. |
| 2026-05-31 | Restrained color: near-monochrome UI, accent reserved for achievement/identity moments (§5.2). |
| 2026-05-31 | Brand accent = dusty red `#BC3B4E` (provisional). |
| 2026-05-31 | Brand red and error red are distinct tokens (§5.4). |
| 2026-05-31 | Typography: Space Grotesk (display) + Inter (body); Inter-only fallback. |
| 2026-05-31 | Scales: spacing 8pt grid (base 4), cards `radius-lg` 16, M3 window-class breakpoints. |
| 2026-05-31 | Responsive & adaptive: mobile-first, reflow-not-redesign; honor iOS/Android via Flutter adaptive constructors (KISS); read window-size class, not pixels (§9). |
| 2026-06-01 | Adaptive = hybrid: one brand visual language (custom Material 3) on every platform; platform-native only in the *feel* (physics/gestures/haptics/pickers via Flutter `.adaptive`), never the *look* (§9.3). |
