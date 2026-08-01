# Feed brief

## Surface summary

Read the public, UI-ready game cards the backend publishes per connected
platform — both for rendering a specific profile and for the discovery feed.
Cards are produced and refreshed by the backend (see `connections.md` →
refresh); the client only reads them. Discovery reads a dedicated
one-card-per-profile surface (see § Discovery surface), not raw cards.

## Authentication

Public cards are readable by any client, including signed-out, via the SDK's
public key. A user can always read their own cards — including while their
profile is private — with their session token (see `auth.md`).

## Shape 2 (direct data access)

- **Table.** `game_cards`
- **Readable columns.** `user_id`, `platform`, `is_public`, `feed_preview`,
  `widget_data`, `last_updated_at`.
  - `feed_preview` — lightweight payload for discovery / list surfaces.
  - `widget_data` — richer payload for rendering the full profile.
- **Writable columns.** None. Cards are entirely backend-owned; the client
  never writes here. New and updated data comes from the refresh operation in
  `connections.md`.
- **Access rule.** Read: public cards by anyone, the owner's cards always.
  `is_public` is set server-side and inherits from the owner's profile
  `privacy_level` — it is never client-controlled.
- **Constraints.** One card per user per platform.
- **Ordering / pagination.** For a single profile, read that user's cards (at
  most one per platform). Discovery does NOT read this table directly — it
  reads the one-card-per-profile surface below.

## Discovery surface (one card per profile)

- **Relation.** `discovery_feed` — a read-only surface over the public game
  cards. Same access model as `game_cards` public reads: readable by any
  client, including signed-out, via the SDK's public key. No writes, ever.
- **Columns.** `user_id`, `platform`, `feed_preview`, `last_updated_at` —
  same types and payload shape as the `game_cards` columns of the same name.
- **Contract.** At most **one row per public profile**: the profile's
  *featured* card when the owner has picked one and that platform has a
  public card, else the profile's most-recently-updated public card. The
  featured pick is the `featured_platform` profile preference (see
  `profile.md`); resolution is soft — a featured platform that is missing or
  no longer linked silently falls back to the freshest card. This contract is
  stable: the surface always yields one `feed_preview` per profile,
  regardless of how the backend resolves it.

  **Discovery feed — client query contract:**

  - **Keyset pagination** over `last_updated_at` descending with `user_id` as
    the stable tiebreaker (not offset paging, which drifts under concurrent
    updates). Always specify the ordering explicitly in the query. The cursor
    predicate for page 2+ is:
    `last_updated_at < curISO OR (last_updated_at = curISO AND user_id < curUserId)`.
    In PostgREST `or()` notation:
    `last_updated_at.lt.<curISO>,and(last_updated_at.eq.<curISO>,user_id.lt.<curUserId>)`.
  - **Own-card exclusion is client-side:** the surface includes the viewer's
    own row when their profile is public; discovery hides it via
    `user_id != <viewerId>` (`.neq('user_id', viewerId)`). If the server later
    excludes the viewer too, the client predicate is a harmless no-op.
  - **Stale WoW (Retail) exclusion is client-side:** feed queries filter out
    rows where `platform = 'wow_retail'` AND
    `last_updated_at < now-minus-30-days-UTC-ISO`. PostgREST predicate:
    `or=(platform.neq.wow_retail,last_updated_at.gte.<cutoff_30d_iso>)`.
    `cutoff_30d_iso` is `clock.now().toUtc().subtract(Duration(days: 30)).toIso8601String()`.
  - **Page size** is a client choice under the data API's result-set cap; no
    specific number is required by the backend.

## Payload shape

The `feed_preview` and `widget_data` columns from Shape 2 are JSON
objects that share one envelope. `feed_preview` is the lightweight
payload — the envelope plus 1–2 headline `stats`, no `data` block.
`widget_data` is the richer payload — the same envelope plus a
per-platform `data` block. Every envelope field present in
`feed_preview` holds the same value in `widget_data`: `feed_preview` is a
subset of `widget_data`.

The envelope is identical across all platforms; only which optional slots
carry data varies (see the optionality matrix below). The client branches
on `platform` to interpret the `data` block, and on `schema_version` to
stay forward-compatible. Cards expose only data the upstream platform
already makes public for that account — nothing private or
contact-related beyond the public upstream profile.

### Envelope

Top-level fields, present on every card in both columns:

| Field            | JSON type         | Required | Notes |
| ---------------- | ----------------- | -------- | ----- |
| `schema_version` | integer           | yes      | Always `1`. Branch on it; render a safe fallback for an unknown version. |
| `platform`       | string            | yes      | One of the supported platform values (see `connections.md`). |
| `title`          | string            | yes      | Primary identity line (persona / username / character name). Raw value, never a localized label, never `null`. |
| `subtitle`       | string \| null    | yes      | Secondary line (raw value or token). `null` when the platform has none. |
| `icon_image`     | string \| null    | yes      | Absolute `https://` URL to a small square avatar / icon, or `null`. |
| `hero_image`     | string \| null    | yes      | Absolute `https://` URL to large cover / hero art, or `null`. Often `null` in `feed_preview`. |
| `profile_url`    | string \| null    | yes      | Absolute `https://` URL to the user's public upstream profile, or `null`. |
| `stats`          | array of Stat     | yes      | Ordered, may be empty. `feed_preview`: 1–2 headline stats; `widget_data`: the fuller set. |
| `last_updated`   | string (ISO-8601) | yes      | UTC timestamp the data reflects; mirrors the `last_updated_at` column. |

"Required" means the key is always present. A nullable field
(`string | null`) is always present but may carry `null`.

### Stat

Each entry in `stats` is an object:

```
{ "key": "string", "value": <number | string | bool>, "unit": "string (optional)" }
```

- `key` — stable machine token; map it to a localized label client-side.
- `value` — raw number, string, or bool; never a display string.
- `unit` — optional stable token (for example `hours`, `count`); map it
  to a localized unit label.

No display or localized strings ever appear in a Stat.

### Schema version and compatibility

`schema_version` is `1` and stable. Additive changes — a new envelope
field, a new `stats` key, a new token — do not bump it; ignore unknown
fields, keys, and tokens and render a safe fallback. Only a breaking
change (removing or renaming a field, changing a type, or changing a
token's meaning) bumps the version. Hard-code against the version you
know and fall back for anything higher.

### Image rules

A non-null `icon_image` or `hero_image` is always a fully-qualified
`https://` URL that loads directly (CDN-backed, cacheable, no auth
header). Unavailable art is `null` — never a placeholder, never a partial
or relative path. The same rule applies to any image URL inside a
`widget_data.data` block.

### Steam example

`feed_preview`:

```json
{
  "schema_version": 1,
  "platform": "steam",
  "title": "TestUser",
  "subtitle": null,
  "icon_image": "https://avatars.akamai.steamstatic.com/<hash>_medium.jpg",
  "hero_image": null,
  "profile_url": "https://steamcommunity.com/id/test/",
  "stats": [
    { "key": "hours_played", "value": 1240, "unit": "hours" },
    { "key": "games_owned", "value": 312, "unit": "count" }
  ],
  "last_updated": "2026-06-03T12:00:00Z"
}
```

`widget_data` (same envelope plus a per-platform `data` block; note the
widget-tier avatar and the hero art):

```json
{
  "schema_version": 1,
  "platform": "steam",
  "title": "TestUser",
  "subtitle": null,
  "icon_image": "https://avatars.akamai.steamstatic.com/<hash>_full.jpg",
  "hero_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg",
  "profile_url": "https://steamcommunity.com/id/test/",
  "stats": [
    { "key": "hours_played", "value": 1240, "unit": "hours" },
    { "key": "games_owned", "value": 312, "unit": "count" },
    { "key": "games_perfect", "value": 42, "unit": "count" }
  ],
  "last_updated": "2026-06-03T12:00:00Z",
  "data": {
    "library_showcase": [
      { "app_id": 730, "title": "CS2", "hours": 540,
        "icon_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/capsule_184x69.jpg",
        "hero_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg",
        "achieved": 142, "total": 167 }
    ],
    "recent_games": [
      { "app_id": 730, "title": "CS2", "hours_2weeks": 12,
        "icon_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/capsule_184x69.jpg",
        "hero_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg" }
    ],
    "perfect_showcase": [
      { "app_id": 730, "title": "CS2",
        "icon_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/capsule_184x69.jpg",
        "hero_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg" }
    ],
    "rarest_achievement": {
      "name": "Ashes to Ashes",
      "icon_image": "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/730/abc123.jpg",
      "game": "CS2",
      "game_icon_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/capsule_184x69.jpg",
      "game_hero_image": "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg",
      "rarity_pct": 0.31,
      "rarity_basis": "GAME_PLAYERS"
    }
  }
}
```

`recent_games[]` entries carry the same constructed cover art as
`library_showcase[]`. Both image fields follow § Image rules.

`rarest_achievement` is optional and absent when no achievement resolved —
the service samples a bounded number of games per sync, so the published
achievement is the rarest **among the games sampled**, not a whole-library
guarantee. `rarity_pct` is a percentage; `rarity_basis` names what that
percentage is measured against, and `GAME_PLAYERS` is the only value today.
Read the basis rather than assuming a denominator: a platform added later may
measure rarity differently, and a hard-coded "% of players" would then be
wrong. The block carries two game images: `game_icon_image` is the store's
small capsule crop (wide and low) and `game_hero_image` is the game's portrait
cover — the same class of art `library_showcase[]` and `perfect_showcase[]`
publish as `hero_image`. `game_hero_image` is optional and additive under
`schema_version: 1`, so a card synced before it landed carries only
`game_icon_image` and gains the cover on its next natural refresh; prefer the
cover wherever the art is drawn at size and fall back to the capsule. Both
follow § Image rules.

`library_showcase[]` entries may carry an optional achievements pair:
`achieved` (integer ≥ 0, unlocked count) and `total` (integer > 0,
achievements the game defines). The two fields appear **together or not at
all** — absence means the game's achievement data is not available, never
`0/0` and never `total: 0` — so render an achievements figure only when
both are present. `achieved: 0` next to a positive `total` is a real value
(owned, none unlocked). Only a bounded subset of the user's top games by
playtime carries the pair; do not infer zero from absence. Additive under
`schema_version: 1`; a card gains the fields on its next natural refresh.

The Steam card additionally publishes a `games_perfect` stat (integer ≥ 0,
`unit: "count"`) — the whole-library count of games with every achievement
unlocked. It is **widget-tier only**: it appears in `widget_data.stats[]`,
never in `feed_preview`. For very large libraries it is a converging
best-effort lower bound. Additive under `schema_version: 1`; `0` is a real
value (no perfect games), distinct from absence.

`data.perfect_showcase[]` is the companion cover list for that count: a
**widget-tier only** array of perfect games, most-played first, each entry
`{ app_id (integer), title (string), icon_image (url | absent), hero_image
(url | absent) }`. It is a bounded best-effort subset (≤ 10 entries) — the
authoritative total remains the `games_perfect` stat, never the array length.
Absent means "no shelf available", never an error; treat a missing or
empty array as empty. Its image urls follow the envelope image rules.
Additive under `schema_version: 1`.

The `data` block's field inventory is platform-specific and ships with
each platform's own contract; only its image URLs follow the envelope
image rules above.

### Per-platform optionality (v1)

The envelope shape is identical for every platform; this table records
which optional slots carry data versus `null` in v1. A slot that is not
populated is `null` — treat a missing optional slot as "not available
yet", not an error. Each platform's `data` field inventory and stable
`stats` keys are documented per platform in *Per-platform data and stats (v1)* below.

| Platform            | icon_image / hero_image                           | profile_url | subtitle     | Notes |
| ------------------- | ------------------------------------------------- | ----------- | ------------ | ----- |
| `steam`             | both shown                                        | URL shown   | `null`       | Complete worked example above. |
| `league_of_legends` | both `null` (v1)                                  | `null`      | region token | Images deferred; `title` is `GameName#TAG`. |
| `wow_retail`        | render (attributed) when available, else `null`   | `null`      | realm-REGION | When `last_updated` is >30 days old, show the owner a "stale — tap to refresh" state (not the data) and hide the card from other viewers. |
| `minecraft_hypixel` | both `null` (v1)                                  | `null`      | `null`       | Skin render deferred to a later image surface. |
| `chess`             | avatar shown, hero `null`                         | URL shown   | country token| Cleanest avatar case. |
| `retroachievements` | avatar shown, hero `null`                         | URL shown   | `null`       | Per-game box-art appears only inside `widget_data.data` and may be absent. |
| `gw2`               | both `null`                                       | `null`      | world name \| null | No account / character portrait exists. |

### Per-platform data and stats (v1)

These are the `data` field inventories and stable `stats` keys for the six non-Steam platforms, at the same depth as the Steam example. Steam's own shapes remain in § Steam example. All values are client-facing JSON read from `feed_preview` or `widget_data`; the envelope, Stat, and image rules above still apply.

#### chess

Platform value: `chess`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "rating", "value": 1842, "unit": "rating" },
    { "key": "followers", "value": 530, "unit": "count" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "primary_mode": "RAPID",
    "ratings": {
      "rapid":  { "current": 1842, "best": 1901, "record": { "win": 312, "loss": 198, "draw": 44 } },
      "blitz":  { "current": 1654, "best": 1720 },
      "bullet": { "current": 1580, "best": 1612 }
    },
    "puzzle_rush_score": 37,
    "tactics_best": 2150,
    "fide": 1900,
    "title_flags": { "is_titled": true, "title": "FM" }
  }
}
```

`widget_data` adds one stat beyond `feed_preview`: `puzzle_rush` (unit `count`).

`primary_mode` is the uppercase token naming the user's main mode — one of `RAPID` | `BLITZ` | `BULLET` | `DAILY`. The `ratings` object is keyed by the lowercase mode tokens `rapid` | `blitz` | `bullet` | `daily` (a subset — not all modes are guaranteed to be present). Each mode entry carries `current` and `best` numbers; `record` (`win`, `loss`, `draw`) is best-effort and may be absent. `tactics_best`, `fide`, and `title_flags` are optional and may be absent. `icon_image` is the user's avatar (`https://` URL or `null`); `hero_image` is `null`. Subtitle is the country token.

#### retroachievements

Platform value: `retroachievements`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "total_achievement_points", "value": 48320, "unit": "points" },
    { "key": "retro_rank", "value": 1204, "unit": "count" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "profile": {
      "total_points": 48320,
      "true_points": 112500,
      "softcore_points": 320,
      "rank": 1204,
      "member_since": "2019-03-15T00:00:00Z",
      "motto": "Achievement hunter"
    },
    "recent_games": [
      {
        "title": "Sonic the Hedgehog",
        "console": "Mega Drive",
        "achieved": 18,
        "total": 22,
        "completion_pct": 81.8,
        "icon_url": "https://media.retroachievements.org/Images/001234.png"
      }
    ]
  }
}
```

`widget_data` adds one stat beyond `feed_preview`: `completion_pct` (unit `percent`, best-effort).

`profile.member_since` and `profile.motto` may be `null`. `recent_games[].icon_url` is per-game box-art that appears only inside `widget_data.data`; it follows the envelope image rules and may be `null` (treat absent as not available). `icon_image` is the user's avatar (`https://` URL or `null`); `hero_image` is `null`.

#### minecraft_hypixel

Platform value: `minecraft_hypixel`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "network_level", "value": 142, "unit": "count" },
    { "key": "bedwars_wins", "value": 2340, "unit": "count" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "rank": "MVP_PLUS",
    "rank_raw": "MVP+",
    "level": 142,
    "karma": 8750400,
    "game_stats": {
      "bedwars": { "wins": 2340, "kills": 18200, "final_kills": 9100, "beds_broken": 4750, "star": 142 },
      "skywars": { "wins": 840, "kills": 5200 },
      "duels":   { "wins": 410,  "kills": 2200 }
    }
  }
}
```

`widget_data` adds three stats beyond `feed_preview`: `bedwars_kills` (unit `count`), `karma` (unit `count`), `achievement_points` (unit `points`).

`rank` is one of `DEFAULT` | `VIP` | `VIP_PLUS` | `MVP` | `MVP_PLUS` | `MVP_PLUS_PLUS` | `YOUTUBER` | `ADMIN` | `UNKNOWN`. Render an unknown rank token with a safe fallback. `rank_raw` is optional. Each block inside `game_stats` is best-effort and may be absent, and the blocks do NOT share a uniform shape: `bedwars` carries `{ wins, kills, final_kills, beds_broken, star? }` (`star` is optional); `skywars` and `duels` carry only `{ wins, kills }`. Do not expect `final_kills`, `beds_broken`, or `star` outside `bedwars`. `icon_image` is `null` and `hero_image` is `null` in v1 — skin render is deferred. Subtitle is `null`.

#### gw2

Platform value: `gw2`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "wvw_rank", "value": 842, "unit": "count" },
    { "key": "fractal_level", "value": 100, "unit": "count" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "main_profession": "GUARDIAN",
    "account": {
      "account_age_hours": 6240,
      "veterancy_years": 9,
      "total_ap": 18430,
      "fractal_level": 100,
      "wvw_rank": 842,
      "home_world": "Seafarer's Rest"
    },
    "top_characters": [
      {
        "name": "Lyra Dawnseeker",
        "race": "Human",
        "profession": "GUARDIAN",
        "level": 80,
        "deaths": 124,
        "hours_played": 1840,
        "is_main": true
      }
    ]
  }
}
```

`widget_data` adds three stats beyond `feed_preview`: `total_ap` (unit `count`), `account_age_hours` (unit `count`), `veterancy_years` (unit `years`).

Scope-gated fields: `wvw_rank`, `fractal_level`, and `total_ap` arrive `null` or omitted — NEVER `0` — depending on the permissions of the user's API key. Treat absent as "not available", not as zero. `main_profession` is `null` when the account has no character; it is otherwise a profession token (`GUARDIAN` | `WARRIOR` | `ENGINEER` | `RANGER` | `THIEF` | `ELEMENTALIST` | `MESMER` | `NECROMANCER` | `REVENANT`). `account.home_world` may be `null`. `icon_image` is `null` and `hero_image` is `null` — no portrait is exposed. Subtitle is the world name or `null`.

#### league_of_legends

Platform value: `league_of_legends`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "rank_lp", "value": 75, "unit": "lp" },
    { "key": "winrate", "value": 54.2, "unit": "percent" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "rank": {
      "tier": "GOLD",
      "division": "II",
      "lp": 75,
      "wins": 183,
      "losses": 155
    },
    "top_mastery": [
      { "champion_id": 157, "level": 7, "points": 412000 },
      { "champion_id": 99,  "level": 6, "points": 198000 }
    ],
    "challenges_details": {
      "total_points": 32400,
      "level": "GOLD"
    },
    "summoner": {
      "level": 312,
      "profile_icon_id": 4895
    }
  }
}
```

`widget_data` adds three stats beyond `feed_preview`: `mastery_points` (unit `points`), `challenge_points` (unit `points`), `summoner_level` (unit `count`).

`rank` is `null` when the summoner is unranked; otherwise `tier` is one of `IRON` | `BRONZE` | `SILVER` | `GOLD` | `PLATINUM` | `EMERALD` | `DIAMOND` | `MASTER` | `GRANDMASTER` | `CHALLENGER`, and `division` is one of `I` | `II` | `III` | `IV`. `summoner.profile_icon_id` is a numeric ID — NOT a URL. `icon_image` is `null` and `hero_image` is `null` in v1 — images deferred. Title is `GameName#TAG`; subtitle is the region token.

#### wow_retail

Platform value: `wow_retail`.

`feed_preview` headline stats:

```json
{
  "stats": [
    { "key": "item_level", "value": 639, "unit": "count" },
    { "key": "achievement_points", "value": 28450, "unit": "points" }
  ]
}
```

`widget_data` `data` block:

```json
{
  "data": {
    "profile": {
      "race": "Night Elf",
      "faction": "ALLIANCE",
      "class": "Hunter",
      "spec": "Marksmanship",
      "level": 80,
      "ilvl_avg": 639,
      "ilvl_equipped": 635
    },
    "mythic_plus": {
      "rating": 2840,
      "best_runs": [
        {
          "keystone_level": 12,
          "dungeon": { "name": "Ara-Kara, City of Echoes" },
          "completed_timestamp": 1717101240000,
          "duration": 1834000,
          "is_completed_within_time": true,
          "mythic_rating": { "rating": 245.6 }
        }
      ]
    },
    "recent_achievements": [
      { "id": 40281, "name": "Ahead of the Curve: Queen Ansurek", "completed_at": "2026-05-15T18:00:00Z" }
    ],
    "attribution": "Data provided by Blizzard"
  }
}
```

`widget_data` adds one stat beyond `feed_preview`: `mythic_plus_rating` — this stat carries no `unit` (the `rating` unit token belongs to `chess` and must not be applied here); it is present only when M+ data exists.

`profile.spec` is best-effort and may be `null`. `mythic_plus.rating` is `null` or the `mythic_plus` block may be absent when M+ data is not available; render a safe fallback for absent M+ data. `mythic_plus.best_runs` is an array of at most 10 Mythic Keystone run objects in the game provider's native shape (the field names are the provider's; the objects are not normalized). Read these exact fields: `keystone_level` (integer), `dungeon.name` (string), `completed_timestamp` (epoch **milliseconds**, NOT an ISO string), `duration` (run time in ms), `is_completed_within_time` (boolean), and `mythic_rating.rating` (number). Other fields (e.g. `members`, `keystone_affixes`, `map_rating`) may be present but are not part of the v1 contract. Do NOT assume `level` or `completed_at` — those do not exist. `profile.faction` is one of `ALLIANCE` | `HORDE`. `data.attribution` is the string `"Data provided by Blizzard"`, delivered in `widget_data.data`; show it conspicuously wherever the full card is rendered (any surface that reads `widget_data`). Apply a freshness gate: if `last_updated` is more than 30 days old, show a "stale — tap to refresh" state instead of the data. The gate is **viewer-aware**: the card's owner sees the actionable "stale — tap to refresh" state, while any other viewer sees the card hidden entirely (no stale data, no stat chips) — only the owner can trigger a refresh. `icon_image` (avatar render) and `hero_image` (main character render) are absolute `https://` URLs or `null`. Subtitle is `realm-REGION`.

## Cross-references

- `connections.md` — the refresh operation that produces and updates cards.
- `profile.md` — `privacy_level` governs whether a user's cards are public.
