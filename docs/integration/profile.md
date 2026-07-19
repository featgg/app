# Profile brief

## Surface summary

Read any user's public profile, and read or update the signed-in user's own
profile (display name, avatar, bio, theme, privacy). This surface covers
profile identity and top-level settings; the widget layout shown on a
profile is a separate surface (see `personalization.md`). Profiles are
created automatically at sign-up (see `auth.md`); the client never creates
one.

## Authentication

Public profile rows are readable by any client, including signed-out, via the
SDK's public key. Reading a private profile and updating a profile require the
user's bearer session token (see `auth.md`); row-level authorization keys off
it — a user can update only their own profile.

## Shape 2 (direct data access)

- **Table.** `profiles`
- **Readable columns.** `id`, `username`, `display_name`, `avatar_url`,
  `bio`, `theme_id`, `privacy_level`, `featured_platform`, `layout`,
  `created_at`. A public profile exposes these to anyone; a private profile is
  readable only by its owner.
- **Owner-only readable column.** `deletion_requested_at` — readable only by the
  owner, server-managed, and never client-writable (see below). It is not part
  of the public readable set above, even on a public profile.
- **Writable columns (owner only).** `display_name`, `bio`, `theme_id`,
  `privacy_level`, `featured_platform`.
- **Server-managed (read-only to the client).** `id`, `created_at`,
  `last_updated_at`, `deletion_requested_at`, `layout`, and `avatar_url`. Never
  client-writable directly; `avatar_url` is updated by the upload endpoint
  (see `avatar.md`). `layout` is written through the owner-scoped layout write
  operation, not this update surface (see `personalization.md` § Layout write
  (composition editor)).
- **Access rule.** Read: public profiles by anyone, private profiles by the
  owner only. Update: owner only, restricted to the writable columns above.
- **Constraints (surface as the SDK error on violation).**
  - `username` — unique, lowercase, 3–30 chars.
  - `display_name` — 1–50 chars.
  - `bio` — up to 150 chars.
  - `theme_id` — closed list: `crimson` (default), `ember`, `solar`, `chak`,
    `frost`, `abyss`, `arcane`, `rose` (see `docs/personalization/spec.md` §8).
    Clients treat any unknown token as the default theme on read.
  - `privacy_level` — one of `public`, `private`. Setting it to `private`
    hides the profile and the user's game cards from everyone but the owner.
  - `featured_platform` — one of the platform values (see `connections.md`),
    or `null`. A display preference: which of the user's cards represents
    them in the discovery feed (see `feed.md` § Discovery surface). `null`
    means the most-recently-updated card. Resolution is soft — pointing at a
    platform the user no longer has falls back to the freshest card; the
    client never needs to clean it up.
  - `layout` — a JSON array of ordered rows composing the personalization profile, each row
    `{ "t": "full"|"pair", "c": [ cardId | null, … ] }` referencing the
    profile's own widget ids. `[]` means no composed
    layout (render the default arrangement). Read-only through this surface and
    resolved softly on the client: a malformed row or slot is ignored rather
    than failing the read. Written through the owner-scoped layout write
    operation (see `personalization.md` § Layout write (composition editor)).
    See `docs/personalization/spec.md` §9.
- **Ordering / pagination.** Reads are single-row: the signed-in user's own
  profile, or one public profile looked up by `username`. No pagination.

## Out-of-band side effects

Setting `privacy_level` propagates server-side to the visibility of the
user's game cards (see `feed.md`): private hides them, public restores them.

## Cross-references

- `auth.md` — issues the session token and provisions the profile at sign-up.
- `avatar.md` — the upload operation that writes `avatar_url` server-side.
- `feed.md` — the user's public game cards, gated by the same `privacy_level`.

## Notes

- `username` is chosen at sign-up and is **not** client-editable for now —
  making it editable is a planned future feature, so it is read-only through
  this surface.
