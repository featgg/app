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

- `platform` — a single-platform card. **The only kind wired today.**
- `data_menu` — a curated stat/showcase widget. *(upcoming)*
- `template` — a pre-designed, slot-filled card. *(upcoming)*
- `composed_card` — a user-assembled, cross-platform composed card.
  *(upcoming)*

### `platform` — valid values and binding rule

`platform`, when set, must be one of:
`steam`, `league_of_legends`, `wow_retail`, `minecraft_hypixel`, `chess`,
`retroachievements`, `gw2`.

Whether `platform` is required or must be null depends on `type`:

- `type = platform` → `platform`
  **must be a non-null** value from the list above.
- `type` in {`composed_card`, `data_menu`, `template`} → `platform`
  **must be null**.

A write that breaks this rule is rejected (the row is not created), distinct
from the invalid-`type` rejection above.

- **Constraints (surface as the SDK error on violation).**
  - At most 50 widgets per user — an insert that would exceed the cap is
    rejected.
  - `position` is a non-negative integer (`>= 0`), unique per user.
  - `settings` is a JSON object up to ~50 KB. Versioned envelope:
    `{ "schema_version": 1, "size": "small" | "wide" | "large" }`.
  - `type` must be a valid value, and `platform` must satisfy the
    binding rule above.
- **Ordering / pagination.** Read the user's widgets ordered by `position`.
  The set is small (≤ 50); no pagination required.

## Cross-references

- `profile.md` — widgets are readable when the parent profile is public.
- `connections.md` — a `platform` widget surfaces data from a connected
  platform; the platform tokens above match the connections surface.
