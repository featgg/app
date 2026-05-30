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
  `bio`, `theme_id`, `privacy_level`, `created_at`. A public profile exposes
  these to anyone; a private profile is readable only by its owner.
- **Writable columns (owner only).** `display_name`, `avatar_url`, `bio`,
  `theme_id`, `privacy_level`.
- **Server-managed (read-only to the client).** `id`, `created_at`,
  `last_updated_at`, and `deletion_requested_at`. Never client-writable.
- **Access rule.** Read: public profiles by anyone, private profiles by the
  owner only. Update: owner only, restricted to the writable columns above.
- **Constraints (surface as the SDK error on violation).**
  - `username` — unique, lowercase, 3–30 chars.
  - `display_name` — 1–50 chars.
  - `bio` — up to 150 chars.
  - `avatar_url` — must be an `http`/`https` URL.
  - `theme_id` — one of `classic`, `immersive`, `retro`, `analyst`.
  - `privacy_level` — one of `public`, `private`. Setting it to `private`
    hides the profile and the user's game cards from everyone but the owner.
- **Ordering / pagination.** Reads are single-row: the signed-in user's own
  profile, or one public profile looked up by `username`. No pagination.

## Out-of-band side effects

Setting `privacy_level` propagates server-side to the visibility of the
user's game cards (see `feed.md`): private hides them, public restores them.

## Cross-references

- `auth.md` — issues the session token and provisions the profile at sign-up.
- `feed.md` — the user's public game cards, gated by the same `privacy_level`.

## Notes

- `username` is chosen at sign-up and is **not** client-editable for now —
  making it editable is a planned future feature, so it is read-only through
  this surface.
