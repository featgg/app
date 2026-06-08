# Connections brief

## Surface summary

Lets a signed-in user connect their accounts on supported third-party
gaming platforms to their profile, refresh the data shown for each
connection, and remove a connection. It also lets the client read which
platforms the user has connected and each connection's status. This
surface covers the connections themselves; the public cards produced from
a connection's data are a separate surface (see `feed.md`).

## Authentication

Bearer token issued by the sign-in surface, sent in the `Authorization`
header. See `auth.md`.

## Supported platforms

The link and refresh operations are parameterized by a platform value:

| Platform value      | Display name              |
| ------------------- | ------------------------- |
| `steam`             | Steam                     |
| `league_of_legends` | League of Legends         |
| `wow_retail`        | World of Warcraft (Retail)|
| `minecraft_hypixel` | Minecraft (Hypixel)       |
| `chess`             | Chess.com                 |
| `retroachievements` | RetroAchievements         |
| `gw2`               | Guild Wars 2              |

## Common errors

Every server operation in this brief can return: `UNAUTHORIZED` (401 —
session invalid or expired; client should re-authenticate),
`UNSUPPORTED_MEDIA_TYPE` (415) and `PAYLOAD_TOO_LARGE` (413) (client bug,
should not occur with a correct client), `SERVER_MISCONFIGURATION` and
`INTERNAL_ERROR` (500 — unexpected; show a generic error and allow
retry). These are omitted from the per-operation tables below.

## Link an account — Shape 1 (server operation)

- **Path.** `/functions/v1/link-account`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** Shape depends on the platform:
  - `platform: string, required — one of the supported platform values`
  - Steam, Minecraft (Hypixel), Chess.com, RetroAchievements:
    `remote_id: string, required — the user's canonical identifier on
    that platform`. Confirmed identifiers: Steam = SteamID64 (the 64-bit
    numeric ID); Minecraft (Hypixel) = the player UUID. Chess.com and
    RetroAchievements use each platform's canonical account identifier
    (specific form to confirm).
  - League of Legends:
    `metadata: object, required — { game_name: string, tag_line: string,
    region: string }`
  - World of Warcraft (Retail):
    `metadata: object, required — { region: string, realm: string,
    character: string }`
  - Guild Wars 2:
    `api_key: string, required — a Guild Wars 2 API key. Write-only: it
    is never returned in any response.`
- **Success response.** `200` — `{ "success": true }`
- **Error responses.**

  | Code                 | Status | Client-UX consequence                                  |
  | -------------------- | -----: | ------------------------------------------------------ |
  | `ALREADY_LINKED`     |    409 | Already linked; see Idempotency below.      |
  | `INVALID_REQUEST`    |    400 | Highlight the invalid field; the input was malformed.  |
  | `UPSTREAM_NOT_FOUND` |    404 | Identity not found on the platform; ask to re-check.   |
  | `UPSTREAM_RATE_LIMIT`|    429 | Platform is busy; ask the user to retry shortly.       |
  | `UPSTREAM_FAILURE`   |    502 | Platform unavailable; allow retry later.               |
  | `LINK_WRITE_FAILED`  |    500 | Generic failure; allow retry.                          |

  For Guild Wars 2, an invalid or unauthorized API key is reported as
  `INVALID_REQUEST` (400), not `UPSTREAM_NOT_FOUND`.
- **Idempotency and retry semantics.** Not idempotent. `ALREADY_LINKED` is
  returned both when the caller re-links the same account (a retry after a
  successful link) and when the submitted account is linked elsewhere — to a
  different profile, or a different account already occupies the caller's single
  per-platform slot. Treat it as success only when the caller already has that
  same account linked (intent satisfied); otherwise the link did not occur, so
  show an "already linked" error rather than reporting success.
- **Latency / timeout expectation.** Validates the identity against the
  third-party platform; may take a few seconds. Recommended client
  timeout ~15s.

## Unlink an account — Shape 1 (server operation)

- **Path.** `/functions/v1/unlink-account`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** `platform: string, required — one of the supported
  platform values`
- **Success response.** `200` — `{ "success": true }`
- **Error responses.**

  | Code            | Status | Client-UX consequence            |
  | --------------- | -----: | -------------------------------- |
  | `INVALID_REQUEST` |  400 | Malformed request; client bug.   |
  | `UNLINK_FAILED` |    500 | Generic failure; allow retry.    |

- **Idempotency and retry semantics.** Idempotent. Unlinking a platform
  that is not connected still returns success — the final state is
  already correct.
- **Latency / timeout expectation.** Fast. Recommended client timeout ~10s.

## Refresh a connection — Shape 1 (server operation)

One endpoint per platform; routing is derived server-side from the
user's existing connection. Each path is `/functions/v1/sync-<platform>`:

| Platform value      | Path                                   |
| ------------------- | -------------------------------------- |
| `steam`             | `/functions/v1/sync-steam`             |
| `league_of_legends` | `/functions/v1/sync-league-of-legends` |
| `wow_retail`        | `/functions/v1/sync-wow-retail`        |
| `minecraft_hypixel` | `/functions/v1/sync-minecraft-hypixel` |
| `chess`             | `/functions/v1/sync-chess`             |
| `retroachievements` | `/functions/v1/sync-retroachievements` |
| `gw2`               | `/functions/v1/sync-gw2`               |

- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** Empty: `{}`
- **Success response.** `200` — at minimum
  `skipped: boolean, required — true when the upstream data was unchanged
  and nothing was refreshed`. Additional platform-specific fields may be
  present alongside `skipped`; they are not a stable contract — do not
  depend on them.
- **Error responses.**

  | Code                       | Status | Client-UX consequence                                  |
  | -------------------------- | -----: | ------------------------------------------------------ |
  | `SYNC_COOLDOWN`            |    429 | Disable refresh until the `Retry-After` window passes. |
  | `LINKED_ACCOUNT_NOT_FOUND` |    404 | No connection for this platform; prompt to connect.    |
  | `MISSING_STORED_CREDENTIAL`|    404 | Connection needs re-linking; prompt to reconnect.      |
  | `UPSTREAM_NOT_FOUND`       |    404 | Upstream identity is gone; suggest reconnecting.       |
  | `UPSTREAM_RATE_LIMIT`      |    429 | Platform is busy; allow retry later.                   |
  | `UPSTREAM_FAILURE`         |    502 | Platform unavailable; allow retry later.               |
  | `SYNC_COMMIT_FAILED`       |    500 | Generic failure; allow retry.                          |
  | `COOLDOWN_CHECK_FAILED`    |    500 | Generic failure; allow retry.                          |
  | `INVALID_STORED_ROUTING`   |    500 | Connection is broken; prompt to reconnect.             |

- **Idempotency and retry semantics.** Safe to retry once the
  `Retry-After` window elapses. The operation is naturally idempotent:
  unchanged data returns `skipped: true`.
- **Latency / timeout expectation.** Fetches data from the third-party
  platform; may be slow (several seconds). Recommended client timeout
  ~30s; do not retry before `Retry-After`.

## Refresh all connections — Shape 1 (server operation)

A bulk companion to the per-platform refresh: refreshes every platform the
user has connected in one call. It self-throttles per platform, so calling it
on every app start/resume is safe.

- **Path.** `/functions/v1/refresh-all`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** `action: string, optional` — `"refresh"` or `"open"`;
  defaults to `"refresh"` when omitted or the body is `{}`.
  - `"refresh"` — refresh every connected platform (replace-on-success).
  - `"open"` — activity ping only; see *Activity ping* below.
- **Success response.** `200` — `{ "success": true, "results": [ { "platform":
  <platform value>, "status": <status> }, … ] }`, one entry per connected
  platform. A user with no connections returns `200` with `"results": []`
  (not an error). `status` is one of:

  | Status              | Meaning                                                       |
  | ------------------- | ------------------------------------------------------------- |
  | `refreshed`         | New upstream data fetched and stored.                         |
  | `skipped_unchanged` | Upstream data unchanged; nothing to update.                   |
  | `skipped_cooldown`  | Within this platform's refresh window; not fetched this call. |
  | `failed`            | This platform's refresh failed; its previous card is kept.    |

  `failed` is opaque — the bulk response gives no per-platform reason. For an
  actionable code (for example "needs reconnect"), call that platform's
  per-platform refresh (`/functions/v1/sync-<platform>`), which returns the
  granular error. Use `refresh-all` as the bulk happy path and per-platform
  sync for diagnosis.
- **Error responses.** These fail the whole call; a single platform's failure
  does not (it appears as `failed` in `results`). Common errors apply and are
  omitted here.

  | Code               | Status | Client-UX consequence                                                   |
  | ------------------ | -----: | ----------------------------------------------------------------------- |
  | `INVALID_REQUEST`  |    400 | `action` not in `{ "refresh", "open" }`, or malformed body; client bug. |
  | `REFRESH_COOLDOWN` |    429 | Every connected platform is on cooldown; back off, treat as no-op.      |
  | `SYNC_COOLDOWN`    |    429 | Every connected platform is on cooldown; identical handling.            |

  Both 429s are UX-identical: back off and retry on the next start/resume. The
  remaining time is in both the `Retry-After` header and a `retry_after` field
  in the body (`{ "success": false, "code", "message", "retry_after" }`). A
  `200` carries no per-platform retry hint — in the mixed case (some
  `refreshed`, some `skipped_cooldown`) the client simply retries next open.
- **Idempotency and retry semantics.** Naturally idempotent (replace-on-success;
  unchanged data → `skipped_unchanged`); safe to retry once `Retry-After`
  elapses. Concurrent refreshes of the same platform are coalesced server-side
  — a second in-flight refresh returns `skipped_cooldown` rather than
  double-fetching — but the client should still keep at most one `refresh-all`
  in flight and skip a repeat within a short resume window.
- **Latency / timeout expectation.** Platforms refresh in parallel, so total
  latency is roughly the slowest single platform, not the sum. Recommended
  client timeout ~60s (above the per-platform ~30s, to absorb one slow leg);
  call it non-blocking in the background.

### Activity ping (`{ "action": "open" }`)

Marks the account active; does not fetch and has no client-visible effect on
the cards you read. Success is `200` — `{ "success": true, "opened": true }`;
never rate-limited. Only the common errors apply. Sending it is optional and
independent of data freshness — `{ "action": "refresh" }` alone keeps cards
fresh.

## Read your connections — Shape 2 (direct data access)

- **Table.** `linked_accounts`
- **Readable columns.** `platform`, `status` (`active` or `error`),
  `last_sync_at`, `created_at`, and the connection's identity/routing
  fields the client displays (`remote_id`, `metadata`).
- **Writable columns.** None. Connections are created, refreshed, and
  removed only through the server operations above.
- **Access rule.** Owner-only: a user can read only their own
  connections.
- **Constraints.** At most one connection per platform per user.
- **Ordering / pagination.** The set is small (one row per connected
  platform); no pagination is required.

## Rate limits

Each connection enforces a refresh cooldown. While the cooldown is
active, the refresh endpoint returns `SYNC_COOLDOWN` (429) with a
`Retry-After` header carrying the remaining seconds. The client must not
retry before that window elapses.

`refresh-all` enforces its own, longer per-platform cooldown, separate from the
per-platform refresh window; when every connected platform is still cooling
down it returns `429` (`REFRESH_COOLDOWN`/`SYNC_COOLDOWN`) with `Retry-After`.
The client must not retry before that window.

## Out-of-band side effects

- Refreshing a connection fetches fresh data from the third-party
  platform.
- Unlinking permanently removes the data shown for that connection.

## Cross-references

- `auth.md` — issues the bearer token every operation requires.
- `feed.md` — the public cards produced from a connection's refreshed data.
