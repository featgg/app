# Account deletion brief

## Surface summary

Lets a signed-in user request deletion of their account (which sends a
one-time code to their email), confirm deletion with that code (which
schedules permanent deletion after a 7-day grace period), and cancel a
pending deletion during the grace period.

## Authentication

Bearer token issued by the sign-in surface, sent in the `Authorization`
header. See `auth.md`.

## Common errors

Every operation can return `UNAUTHORIZED` (401 — session invalid or
expired; re-authenticate) and `INTERNAL_ERROR` (500 — unexpected; show a
generic error and allow retry). These are omitted from the per-operation
tables below.

## Request deletion — Shape 1 (server operation)

- **Path.** `/functions/v1/delete-account`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** `{ "action": "request" }`
- **Success response.** `200` —
  `{ "success": true, "otp_sent": true }`
- **Error responses.**

  | Code                    | Status | Client-UX consequence                          |
  | ----------------------- | -----: | ---------------------------------------------- |
  | `OTP_RATE_LIMIT`        |    429 | Too many code requests in a short window; back off and retry after `retry_after` seconds when present. |
  | `ACCOUNT_DELETE_FAILED` |    500 | Could not send the code; allow retry.          |

- **Idempotency and retry semantics.** Safe to retry; each call sends a
  fresh code.
- **Latency / timeout expectation.** Sends an email; normal latency.
  Recommended client timeout ~15s.

## Confirm deletion — Shape 1 (server operation)

- **Path.** `/functions/v1/delete-account`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.**
  `{ "action": "confirm", "otp": "<the code from the email>" }`
  (`otp: string, required`)
- **Success response.** `200` —
  `{ "success": true, "deletion_scheduled_at": "<ISO 8601 timestamp>" }`.
  Deletion is scheduled 7 days out. If a deletion was already pending,
  the grace period restarts from this confirmation.
- **Error responses.**

  | Code                    | Status | Client-UX consequence                              |
  | ----------------------- | -----: | -------------------------------------------------- |
  | `INVALID_REQUEST`       |    400 | The code field was missing; prompt to enter it.    |
  | `INVALID_OTP`           |    401 | The code is wrong or expired; let the user retry.  |
  | `OTP_RATE_LIMIT`        |    429 | Too many verification attempts; back off and retry after `retry_after` seconds when present. |
  | `ACCOUNT_DELETE_FAILED` |    500 | Could not schedule deletion; allow retry.          |

- **Idempotency and retry semantics.** Re-confirming restarts the 7-day
  grace window (latest intent wins).
- **Latency / timeout expectation.** Normal. Recommended client timeout
  ~15s.

## Cancel deletion — Shape 1 (server operation)

- **Path.** `/functions/v1/cancel-deletion`
- **HTTP method.** `POST`
- **Request headers.** `Authorization: Bearer <token>`;
  `Content-Type: application/json`
- **Request body.** Empty: `{}`
- **Success response.** `200` —
  `{ "success": true, "cancelled": true }`
- **Error responses.**

  | Code                    | Status | Client-UX consequence                  |
  | ----------------------- | -----: | -------------------------------------- |
  | `INVALID_REQUEST`       |    400 | Body must be empty; client bug.        |
  | `ACCOUNT_DELETE_FAILED` |    500 | Could not cancel; allow retry.         |

- **Idempotency and retry semantics.** Idempotent. Cancelling when
  nothing is pending still returns success.
- **Latency / timeout expectation.** Fast. Recommended client timeout ~10s.

## Rate limits

This surface enforces no application-level rate limit of its own. The
one-time code is issued through the auth platform, which applies its own
built-in limits on how often a verification email may be sent and how
many times a code may be tried before it expires. When either limit is
hit, the request returns `429 OTP_RATE_LIMIT` — distinct from any 500.
When the platform reports a retry window, the response body includes an
integer `retry_after` (seconds) and a matching `Retry-After` header;
both are omitted when no window is exposed. Treat `OTP_RATE_LIMIT` as a
transient, user-retryable throttle: debounce the "request code" /
"resend" / "confirm" actions, show a brief "try again in a moment"
message, and do not report it to crash reporting.

## Out-of-band side effects

- Requesting deletion sends a one-time code to the user's email.
- Confirming deletion sends a confirmation email. If that email fails to
  send, the deletion is still scheduled and the response is still `200`.

## Cross-references

- `auth.md` — issues the bearer token every operation requires.
- `profile.md` — the owner-scoped read that reports whether a deletion is
  pending.
