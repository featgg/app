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

## Cross-references

- `connections.md` — the refresh operation that produces and updates cards.
- `profile.md` — `privacy_level` governs whether a user's cards are public.
