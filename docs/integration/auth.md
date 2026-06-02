# Auth brief

## Surface summary

Lets a user sign up and sign in, obtain the session token every other surface
requires, refresh it, and sign out. On first sign-up the backend
automatically provisions the user's profile; the client never creates it.

## Authentication

This surface is what establishes authentication. Sign-in and code-verification
calls are unauthenticated; once a session exists, refresh and sign-out use it.

## Shape 1 (server operation)

Calls are made under the base URL's `/auth/v1/` path, through the client
SDK. **Deviation from the global envelope:** responses are the auth SDK's session
and user objects (and the platform's error format), not the
`{ success, code, message }` envelope the other server operations use. The
client uses the SDK methods described below rather than hand-rolling requests.

### Sign in with an email code

- The client submits the user's email; the platform sends a 6-digit one-time
  code (valid ~1 hour) to that address. The client then submits the code to
  obtain a session — there is no magic link, only the 6-digit code. Sign-up
  happens automatically on first use: a new account and profile are
  provisioned. No separate email-confirmation step is required before signing
  in.
- **Side effect.** Requesting the code sends the user an email.

### Sign in with a third-party identity provider

- OAuth 2.0 authorization-code flow with PKCE: the client starts the flow, the
  user authenticates with the provider, and is redirected back to the app with
  a session. Supported providers: Google and Discord.

### Session token, refresh, and sign out

- A successful sign-in yields a bearer token (a JWT, valid ~1 hour) plus a
  refresh token; the SDK stores the session and refreshes it automatically.
  This bearer token is the `Authorization: Bearer <token>` every other brief
  requires.
- Sign-out clears the session.

## Rate limits

The auth platform rate-limits verification-email sends and sign-in /
code-verification / token-refresh attempts. The client must handle a
rate-limited response and back off: briefly disable the action that was
rate-limited (the "send / resend code" action, and code verification) and
surface a "try again shortly" message. The exact limits are
environment-configured; do not hard-code them as enforcement.

One limit is a fixed minimum interval between successive code sends to the same
address (about a minute by default). Because that interval is known up front, the
client may mirror it as a proactive resend countdown so the resend control
re-enables when the server will next accept a request, rather than re-enabling
early into an immediate rejection. This countdown is UX only and approximate —
the window is environment-configured and may differ; the rate-limited response
stays authoritative.

## Out-of-band side effects

- Requesting an email sign-in code sends an email to the user.
- First successful sign-up provisions the user's profile server-side (a
  default username and profile row). The client reads and updates it via
  `profile.md`.

## Cross-references

- Every other brief depends on the session token this surface issues.
- `profile.md` — the profile provisioned at sign-up.
