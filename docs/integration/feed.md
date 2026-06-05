# Feed brief

## Surface summary

Read the public, UI-ready game cards the backend publishes per connected
platform — both for rendering a specific profile and for discovery surfaces
that list recently-updated public cards. Cards are produced and refreshed by
the backend (see `connections.md` → refresh); the client only reads them.

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
  most one per platform). For a discovery feed, read public cards ordered by
  `last_updated_at` (most recent first) and page with a limit; the data API
  caps result-set size, so always paginate discovery reads.

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
  "hero_image": "https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg",
  "profile_url": "https://steamcommunity.com/id/test/",
  "stats": [
    { "key": "hours_played", "value": 1240, "unit": "hours" },
    { "key": "games_owned", "value": 312, "unit": "count" }
  ],
  "last_updated": "2026-06-03T12:00:00Z",
  "data": {
    "library_showcase": [
      { "app_id": 730, "title": "CS2", "hours": 540,
        "icon_image": "https://shared.akamai.steamstatic.com/steam/apps/730/capsule_184x69.jpg",
        "hero_image": "https://shared.akamai.steamstatic.com/steam/apps/730/library_600x900.jpg" }
    ],
    "recent_games": [
      { "app_id": 730, "title": "CS2", "hours_2weeks": 12 }
    ]
  }
}
```

The `data` block's field inventory is platform-specific and ships with
each platform's own contract; only its image URLs follow the envelope
image rules above.

### Per-platform optionality (v1)

The envelope shape is identical for every platform; this table records
which optional slots carry data versus `null` in v1. A slot that is not
populated is `null` — treat a missing optional slot as "not available
yet", not an error. Each platform's `data` field inventory and stable
`stats` keys ship with that platform's own contract.

| Platform            | icon_image / hero_image                           | profile_url | subtitle     | Notes |
| ------------------- | ------------------------------------------------- | ----------- | ------------ | ----- |
| `steam`             | both shown                                        | URL shown   | `null`       | Complete worked example above. |
| `league_of_legends` | both `null` (v1)                                  | `null`      | region token | Images deferred; `title` is `GameName#TAG`. |
| `wow_retail`        | render (attributed) when available, else `null`   | `null`      | realm name   | When `last_updated` is >30 days old, show a "stale — tap to refresh" state, not the data. |
| `minecraft_hypixel` | both `null` (v1)                                  | `null`      | `null`       | Skin render deferred to a later image surface. |
| `chess`             | avatar shown, hero `null`                         | URL shown   | country token| Cleanest avatar case. |
| `retroachievements` | avatar shown, hero `null`                         | URL shown   | `null`       | Per-game box-art appears only inside `widget_data.data` and may be absent. |
| `gw2`               | both `null`                                       | `null`      | `null`       | No account / character portrait exists. |

## Cross-references

- `connections.md` — the refresh operation that produces and updates cards.
- `profile.md` — `privacy_level` governs whether a user's cards are public.
