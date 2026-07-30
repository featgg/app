# Personalization brief

## Surface summary

Read and manage the signed-in user's profile widgets — the layout blocks
shown on their profile. The user can add, reorder, toggle, configure, and
remove widgets, up to a per-user cap. This surface covers only the widget
layout; the profile's identity fields (name, avatar, bio, theme, privacy)
live in `profile.md`.

## Authentication

A user manages only their own widgets, with their session token (see
`auth.md`); row-level authorization keys off it. A profile's widgets are also
readable by anyone when that profile is public (see `profile.md`), via the
SDK's public key.

## Shape 2 (direct data access)

- **Table.** `profile_widgets`
- **Readable columns.** `id`, `user_id`, `platform`, `type`, `position`,
  `is_enabled`, `settings`, `created_at`, `last_updated_at`. Readable by the
  owner always; by anyone when the parent profile is public.
- **Writable columns (owner only).** `platform`, `type`, `position`,
  `is_enabled`, `settings`. The client may insert, update, and delete its own
  widget rows.
- **Server-managed (read-only to the client).** `id`, `user_id`,
  `created_at`, `last_updated_at`.
- **Access rule.** Insert / update / delete: owner only, restricted to the
  writable columns. Read: owner always, or anyone when the parent profile is
  public.

### `type` — valid values

`type` is required and must be one of the following tokens (lowercase,
snake_case). Any other value is rejected as an invalid value for the field.

- `platform` — a single-platform card. No longer offered when adding a card;
  existing rows still render.
- `template` — a pre-designed, slot-filled card. **Client-retired** (see below).
- `composed_card` — a user-assembled, cross-platform composed card.
  **Client-retired** (see below).
- `data_menu` — a curated stat/showcase widget. **Client-retired** (see below).
- `showcase` — a single-game art showcase card. *(client rendering is
  Steam-first: a showcase row bound to another platform is accepted and stored,
  but the client renders it as unavailable — owner placeholder, hidden from
  visitors — until that platform's showcase source ships)*
- `collection` — a multi-game collection card.
- `game_collector` — a platform-bound card aggregating a connected platform's
  whole library (games-owned count, total hours, top-game cover). Client
  rendering is Steam-first.
- `completionist` — a platform-bound card whose hero is the whole-library
  perfect-games count (how many games are 100% completed). Client rendering is
  Steam-first.
- `passport` — a profile-level identity card aggregating the owner's linked
  platforms: one headline stat per linked platform plus a linked-platform count.
  It reads only already-published card data (no new fields) and mixes every
  linked platform, so it is not platform-bound.
- `rank` — a platform-bound card showing the owner's competitive rank/rating on
  one connected platform (League tier, Mythic+ rating, Chess mode rating,
  RetroAchievements rank). Reads only already-published card data. Rendered at
  full or half size (the full variant shows a larger crest and a wider stat cap).
- `main` — a platform-bound card showing the owner's primary game / character /
  mode on one connected platform (Steam top game, WoW character, GW2 main, League
  top mastery, Chess primary mode). Reads only already-published card data.
- `art` — a visual card carrying a picture and no data. It is not
  platform-bound: which picture it shows is a client-side choice carried in
  `settings` (see below), defaulting to a client-resolved best available image
  when absent.

`showcase`, `collection`, `game_collector`, `completionist`, `passport`,
`rank`, `main`, and `art` are the kinds the client writes today.

`template`, `composed_card` and `data_menu` are **client-retired**: the client
no longer writes them and no longer reads them — a row carrying one of those
tokens resolves to nothing and is omitted, so it renders as absent without
needing to be removed. They stay documented above, with their binding rule,
because the service still accepts them: a consumer must be able to tell a valid
row from an invalid one for as long as that is true. They leave this document
when they leave the accepted values.

### `platform` — valid values and binding rule

`platform`, when set, must be one of:
`steam`, `league_of_legends`, `wow_retail`, `minecraft_hypixel`, `chess`,
`retroachievements`, `gw2`.

Whether `platform` is required or must be null depends on `type`:

- `type = platform` → `platform`
  **must be a non-null** value from the list above.
- `type = showcase` → `platform` **must be a non-null** value from the list
  above (the single source platform the showcase draws from).
- `type` in {`composed_card`, `data_menu`, `template`} → `platform`
  **must be null** (client-retired, still accepted).
- `type = collection` → `platform` **must be null** (a collection spans multiple
  games).
- `type = game_collector` → `platform` **must be a non-null** value from the
  list above (the platform whose library it aggregates).
- `type = completionist` → `platform` **must be a non-null** value from the
  list above (the platform whose library it counts).
- `type = passport` → `platform` **must be null** (it aggregates every linked
  platform, not a single source).
- `type = rank` → `platform` **must be a non-null** value from the list above
  (the platform whose competitive standing it renders).
- `type = main` → `platform` **must be a non-null** value from the list above
  (the platform whose primary game/character/mode it renders).
- `type = art` → `platform` **must be null** (the card reads no account data;
  its picture source is a `settings` choice, not a binding).

A write that breaks this rule is rejected (the row is not created), distinct
from the invalid-`type` rejection above.

Per-kind rendered size (Rank and Main are both full or half) is
client-enforced, not server-validated — the client offers only legal sizes.

- **Constraints (surface as the SDK error on violation).**
  - At most 50 widgets per user — an insert that would exceed the cap is
    rejected.
  - `position` is a non-negative integer (`>= 0`), unique per user.
  - `settings` is a JSON object up to ~50 KB. Versioned envelope:
    `{ "schema_version": 1 }`. A row written before the rendered size became a
    property of the saved arrangement may also carry a `size` string; it is
    ignored on read and no longer written. The
    `settings` schema is client-owned; the client may add fields additively
    under the same `schema_version: 1`. An `art` widget may carry its picture source under another such
    field — `"art": { "source": "<platform>" }` — the platform whose artwork it
    shows. It is likewise additive and optional: absent means the client
    resolves the best available image at render time, and it never bumps the
    version. A `showcase` widget carries its
    single-game choice under another such field —
    `"showcase": { "game": "<gameKey>", "hero": "<stat>", "meta"?: "<stat>" }` —
    the game to render and which stat is the hero. It is likewise additive,
    ignored when absent, and never bumps the version. A `collection` widget
    carries its multi-game choice under another such field —
    `"collection": { "games": ["<gameKey>", ...], "title": "<titleKey>" }` — the
    ordered games it renders and a stable catalog title key. It is likewise
    additive, ignored when absent, and never bumps the version. A
    `game_collector` widget carries no additional settings sub-object beyond
    the envelope — it has no per-widget choice (it aggregates the whole
    library) — and a future art-source selector may be added additively under
    the same `schema_version: 1`. A `completionist` widget likewise carries no
    additional settings sub-object — it has no per-widget choice (it counts the
    whole library's perfect games). A `passport` widget likewise carries none —
    it aggregates every linked platform.
  - `type` must be a valid value, and `platform` must satisfy the
    binding rule above.
- **Ordering / pagination.** Read the user's widgets ordered by `position`.
  The set is small (≤ 50); no pagination required.

## Layout write (composition editor)

The composed arrangement itself — the ordered rows a profile renders — is written
through a dedicated owner-scoped server operation, not the direct `profiles`
update surface. The backend is treated as an opaque HTTPS service.

### Shape 1 (server operation)

- **Operation.** `POST /rest/v1/rpc/set_profile_layout`
- **Headers.** `Authorization: Bearer <jwt>`, `Content-Type: application/json`.
- **Auth.** Requires a valid session; always acts on the caller's own profile
  (there is no target field).
- **Request body.** `{ "p_layout": Row[] }` — replace semantics: send the whole
  layout. `Row` is one of:
  - `{ "t": "full", "c": [CardId] }` — one full-width card.
  - `{ "t": "pair", "c": [CardId | null, CardId | null] }` — up to two side-by-side
    halves; a single non-null slot renders as a centered orphan.
  - `CardId` is a non-empty id of one of the caller's own widgets. `[]` clears the
    layout (the profile falls back to the default arrangement).
- **Server-enforced (all-or-nothing).** Known `t`; the correct cell count per row
  type; every id is one of the caller's own widget ids; each card appears at most
  once; at most 50 rows; at most ~8 KB serialized. Per-archetype size support
  (which cards may be half) is **not** server-validated — the client offers only
  legal placements.
- **Disabled-card semantics.** A save that references a disabled card succeeds; the
  client hides that card at render and re-enabling it restores its slot with no
  re-save.
- **Success.** `204` with an empty body.
- **Errors.** JSON `{ code, message, ... }`. Branch on `code`/status, never on
  `message`:
  - `422` `LAYOUT_INVALID` — the layout was rejected. Roll back the edit and show
    a "couldn't save" message.
  - `401` — the session is invalid/expired; re-authenticate.
  - `5xx` / other — transient; roll back and allow a retry.

## Cross-references

- `profile.md` — widgets are readable when the parent profile is public; the
  `layout` column referencing these widget ids is read there and written via the
  operation above.
- `connections.md` — a `platform` widget surfaces data from a connected
  platform; the platform tokens above match the connections surface.
