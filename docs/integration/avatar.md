# Avatar upload brief

## Surface summary

Lets the signed-in user upload a new profile avatar. The image is screened
by a server-side moderation provider before being stored; on success the
`profiles.avatar_url` column is updated server-side. The client observes
the change by re-reading the profile (see `profile.md`).

The server enforces a maximum upload size of 1 MB. Uploads over this limit
return `413 PAYLOAD_TOO_LARGE`.

## Authentication

Bearer token issued by the sign-in surface, sent in the `Authorization`
header. See `auth.md`. If there is no active session the SDK attaches no
token and the endpoint returns `UNAUTHORIZED`.

## Shape 1 (server operation)

- **Path.** `/functions/v1/moderate-and-set-avatar`
- **HTTP method.** `POST`
- **Request headers.**
  - `Authorization: Bearer <token>` (see `auth.md`)
  - `Content-Type: image/jpeg` — the only accepted type. The client transcodes
    every picked image (HEIC, PNG, WebP, …) to JPEG before upload and sends
    `image/jpeg`.
- **Request body.** Raw image bytes (binary). JSON bodies are capped at
  64 KB (see `README.md` § Global conventions); a ≤200 KB compressed image
  encoded as base64 would exceed that cap, so the upload uses a binary body.
- **Success response.** HTTP `200` —
  `{ "success": true, "avatar_url": "<public https URL of the new avatar>" }`
  (`avatar_url: string, required`)
- **Error responses.**

  | Code                      | Status | `details` body                                              | Client-UX consequence                                                          |
  | ------------------------- | -----: | ----------------------------------------------------------- | ------------------------------------------------------------------------------ |
  | `MODERATION_REJECTED`     |    422 | `{ "success": false, "code": "...", "message": "...", "categories": [...] }` | Friendly localized rejection; avatar unchanged. Category tokens are never shown to the user. |
  | `PAYLOAD_TOO_LARGE`       |    413 | `{ "success": false, "code": "...", "message": "..." }`    | Generic "couldn't use that image" copy. Maximum upload size is 1 MB.           |
  | `UNSUPPORTED_MEDIA_TYPE`  |    415 | `{ "success": false, "code": "...", "message": "..." }`    | Generic "couldn't use that image" copy. Fires when `Content-Type` is not `image/jpeg`, when the request bytes are not a real JPEG (server magic-byte sniff), when the body is empty, or when the HTTP method is not POST. The client never triggers these — it always POSTs a non-empty, real `image/jpeg` body (`encodeJpg` output). |
  | `UNAUTHORIZED`            |    401 | `{ "success": false, "code": "...", "message": "..." }`    | Re-authenticate; avatar unchanged.                                             |
  | `AVATAR_COOLDOWN`         |    429 | `{ "success": false, "code": "...", "message": "...", "retry_after": <int seconds> }` | The upload affordance disables and shows a countdown seeded from `retry_after`; when `retry_after` is absent the client disables for a short window and shows a generic "try again shortly" message. Note: a `Retry-After` header also carries the seconds, but the client reads `retry_after` from the body because the client SDK does not expose response headers. |
  | `MODERATION_UNAVAILABLE`  |    500 | `{ "success": false, "code": "...", "message": "..." }`    | "Try again later"; avatar unchanged (fail closed).                             |

  The client branches on the `code` token first; HTTP status is the
  secondary signal when `code` is absent.

- **Idempotency / retry.** Not idempotent — each successful call stores a new
  object. Safe to retry after any error because a rejected or failed call
  stores nothing. No idempotency key.
- **Versioning.** Unversioned.
- **Latency / timeout.** Moderation runs synchronously via a third-party
  provider call. Recommended client timeout ~30 s. A timeout maps to a
  retryable failure; no silent partial write occurs.
- **Out-of-band side effects.** On success the backend replaces and deletes
  the previous avatar object and updates `profiles.avatar_url`. The client
  observes the new URL by re-reading the profile provider. No
  email/notification side effects.

## Rate limits

This surface enforces a per-user upload throttle: a burst of 3 uploads is
allowed, then roughly 1 per 60 seconds (the allowance refills one slot per
minute, up to 3). In normal use it is almost never hit. When it is, the
endpoint returns `429 AVATAR_COOLDOWN`. The server reports the remaining
seconds in the `Retry-After` header (authoritative); because the client SDK
does not expose response headers, the client uses a `retry_after` body field
when present and otherwise backs off for a fixed ~60 s window. Either way the
client disables the upload affordance for the window — a live countdown when
the seconds are known, a generic "try again shortly" message otherwise.

## Cross-references

- `auth.md` — issues the bearer token used in the `Authorization` header.
- `profile.md` — `avatar_url` is a readable column on the `profiles` table;
  this operation is the only way the client writes it.
