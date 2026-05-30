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
- **Constraints (surface as the SDK error on violation).**
  - At most 50 widgets per user — an insert that would exceed the cap is
    rejected.
  - `position` is unique per user.
  - `settings` is a JSON object up to ~50 KB.
- **Ordering / pagination.** Read the user's widgets ordered by `position`.
  The set is small (≤ 50); no pagination required.

## Cross-references

- `profile.md` — widgets are readable when the parent profile is public.
- `connections.md` — a `platform` widget surfaces data from a connected
  platform.
