# Integration briefs

This directory is the canonical home for **integration briefs**:
public-repo-safe descriptions of the backend surfaces the Flutter
client uses. A brief is the contract. The planner reads the brief when
planning a feature that uses the backend, the implementer codes to the
brief, and the reviewer asserts the implementation matches it.

This file is a meta-document. It is not itself a brief. Briefs live in
sibling files alongside this README.

## What a brief is

A brief is a single Markdown file under `docs/integration/` describing
one logically-grouped backend surface the client uses. One file per
surface; one surface per file. The filename is kebab-case, scoped by the
surface it describes, and ends in `.md` — for example, the sign-in
surface lives at `docs/integration/auth.md` and the player profile
surface at `docs/integration/profile.md`.

The layout is flat: no subdirectories, no epic grouping. Volume can
justify a richer layout later; today's KISS default is one flat Markdown
file per surface.

A brief documents one logically-grouped surface, and covers one
**contract**, not one provider: where a single surface serves many
third-party platforms through one shape parameterized by a platform
value, that is one brief listing the supported platform values — not one
file per platform. Each endpoint or data access within a brief is one of
two shapes, and the brief declares the shape of each; when the surface is
a single conceptual feature, a brief may mix shapes across sections, each
section stating its shape. The two shapes are:

- **Server operation (HTTP endpoint).** An operation the backend runs
  server-side — anything secret-bearing, cross-record, or derived. The
  client calls an HTTPS endpoint.
- **Direct data access (client SDK).** Data where the signed-in user is
  the source of truth and the client reads or writes it directly under
  row-level authorization, using the client SDK.

Briefs are English-only. They use plain Markdown — no diagrams beyond
what clarifies a request or response shape, no embedded JSON Schema, no
OpenAPI document. A contributor should be able to read a brief
top-to-bottom in a few minutes and know exactly what the client may do
against that surface, what the request and response look like, and how
to handle errors.

## Global conventions

These conventions are shared by all briefs so individual briefs do not
repeat them. A brief states only its deviations.

**Base URL.** The client calls the backend at a single base URL,
configured once in the client (the SDK is initialized with it). Today
that is the backend's default project URL; `api.feat.gg` is a planned
alias (post-MVP) and is not yet routable. Briefs document paths and
resource names relative to this base — never a hard-coded host. The full
URL for a server operation is the base URL plus the brief's path.

**Versioning.** Surfaces are unversioned unless a brief states otherwise.

**Server-operation surfaces** exchange JSON and use a stable envelope:

- Success:
  ```json
  { "success": true, "...": "operation-specific fields" }
  ```
- Error:
  ```json
  { "success": false, "code": "STABLE_ERROR_TOKEN", "message": "Human-readable message" }
  ```

The client branches on the stable `code` token, not on the HTTP status
alone — several distinct errors may share one status. Each brief lists
the `code` tokens its endpoints can return. Request bodies are JSON and
capped in size (currently 64 KB); an argument-less call sends an empty
JSON object `{}` and still sets the JSON content type.

**Direct-data-access surfaces** return rows from the data API under
row-level authorization. Errors surface as the client SDK's typed error.
Result-set limits and pagination are stated per brief.

**Abstract type term.** Request and response fields are described as
`field_name: type, required|optional — one-line semantic` (for example,
`email: string, required — RFC 5322 syntax`;
`created_at: string, required — ISO 8601 timestamp`).

## What a brief MUST contain

Every brief contains the common fields below, plus the fields for its
shape. Briefs that omit a required field are incomplete and block the
planning stage for any feature that depends on the surface.

**Common to both shapes:**

- **Surface summary.** One paragraph: the user-facing capability this
  surface enables, in client terms.
- **Authentication.** The auth scheme the surface requires, in concrete
  terms (for example, "Bearer token issued by the sign-in surface, sent
  in the `Authorization` header"). A brief that depends on a token
  issued elsewhere links to that brief rather than re-describing how the
  token is obtained.
- **Rate limits.** If the surface enforces a rate limit: the limit, the
  IANA-standard header that carries any retry delay (`Retry-After`), and
  the client's required back-off behavior.
- **Out-of-band side effects.** If using the surface triggers a side
  effect the client must know about (for example, "this call sends the
  user an email"), the brief states it.
- **Cross-references.** Other briefs this surface depends on.

**Shape 1 — Server operation (HTTP endpoint):**

- **Path.** The path the client calls, relative to the base URL (for
  example, `/functions/v1/<name>`).
- **HTTP method.** One of `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
- **Request headers.** Every header the client must send, by purpose and
  on-the-wire name.
- **Request body.** The body shape in abstract type terms, or that the
  body is empty.
- **Success response.** The status code(s) indicating success and the
  body shape, or that there is no body.
- **Error responses.** Every error the client must handle, given as:
  HTTP status code, the stable error-code token, the error-body shape,
  and the client-UX consequence.
- **Idempotency and retry semantics.** Whether the endpoint is safe to
  retry, whether it accepts an idempotency key, and any other
  retry-relevant behavior.
- **Versioning.** If versioned, how the version is signaled and which
  version the brief documents.
- **Latency / timeout expectation.** The recommended client request
  timeout and whether the call may be long-running.

**Shape 2 — Direct data access (client SDK):**

- **Table.** The public table the surface exposes.
- **Readable columns** and **writable columns**, listed explicitly.
  Columns the client must not write (server-managed) are called out.
- **Access rule.** The row-level authorization that applies (owner-only,
  public-or-owner, read-only to the client).
- **Constraints.** Caps, uniqueness, or size limits the client must
  respect, surfaced as the error the client receives when one is
  violated.
- **Ordering / pagination.** How the client orders, pages, or limits
  results.

## What a brief MAY contain

To make the contract usable, a brief may freely state any of the
following:

- The kind of backend platform the client talks to (a managed Postgres
  data API plus serverless functions) and the client SDK used to reach
  it.
- The public tables and columns the client reads or writes, and the
  access rule enforced for each.
- The security model in plain terms: row-level authorization keyed to
  the signed-in user.
- The public base URL and hostname the client calls (a product fact). It
  is documented once in § Global conventions § Base URL; individual briefs
  use paths relative to it rather than repeating the host.
- HTTP methods, status codes, and IANA-standard header names.
- Abstract request/response field shapes, the auth scheme, rate-limit
  numbers, idempotency contract, and versioning signal.
- The names of the third-party platforms the product integrates with on
  the user's behalf — these are product facts, not backend internals.

## What a brief MUST NOT contain

A brief describes the public contract a client is entitled to use. It
must not expose backend internals that are sensitive, privileged, or
unreachable by the client. The following are forbidden:

- The structure of any non-public data store the client cannot reach:
  internal-only schemas, internal-only tables, or their columns.
- Internal-only stored procedures or functions — anything the client
  cannot invoke directly. (Client-callable endpoint names are public by
  necessity and are allowed.)
- Secret names, signing keys, privileged service credentials, or any
  environment-variable or deployment-configuration identifier.
- How a submitted credential is stored or transformed at rest. A brief
  states only that a credential field is write-only and never returned.
- Scheduled-job names, migration filenames, internal source paths, or
  internal helper identifiers that are not part of the client-callable
  surface.
- Internal hostnames, IP ranges, private network identifiers, and
  internal observability identifiers (log streams, metric names,
  dashboards, trace ids).
- Internal team names, ticket identifiers, or planning identifiers from
  outside this repository.

Obscuring the public data model is explicitly not a goal: the names of
public tables and columns the client uses already ship inside the client
and add no exposure when documented. Security is enforced by row-level
authorization, not by hiding names.

## How the pipeline consumes briefs

- **Plan.** When the planner plans a feature that uses a backend
  surface, it reads the brief covering that surface and cites it. A plan
  that uses a surface with no brief in `docs/integration/` is incomplete
  and must either wait for the brief or restrict the change to a stub
  that returns a typed not-implemented failure.
- **Implement.** The implementer codes against the brief verbatim — same
  URL or table, same method or access, same request and response shape,
  same error handling.
- **Review.** The reviewer asserts the implementation matches the brief.
  A divergence between code and brief is a review blocker.
- **Git.** The git stage carries no special obligation toward briefs
  beyond the standard public-repo discipline checks.

No backend call may be written without a corresponding brief in this
directory. This is restated as a load-bearing invariant in `AGENTS.md`
§ Public-repo discipline.

## Source of truth and updates

Briefs are the source of truth for backend contracts inside this
repository. When the backend changes a contract:

- The brief is updated first, or at the same time as, the client change
  that consumes the new contract.
- A client pull request that diverges from its brief — different URL,
  table, method, or shape — is a review blocker.
- A brief change that lands without an accompanying client change is
  acceptable when the contract change is forward-compatible (for
  example, a new optional response field older client code ignores
  cleanly).

Briefs are versioned by Git history. The most recent committed version
on `main` is the current contract. There is no separate version field
inside a brief; if a contract evolves incompatibly, either the endpoint
is versioned (and the brief documents the version it covers) or a new
brief replaces the old one in the same change.

## What this directory does not host

This directory hosts integration briefs only. It does not host:

- Architecture diagrams, sequence diagrams, or any design artifact
  beyond what clarifies a single request or response shape inside a
  brief.
- Operational runbooks, on-call procedures, or incident playbooks.
- Internal process documentation or planning identifiers from outside
  this repository.
- Backend implementation documentation of any kind.

Architecture and code-authoring guidance (how to structure a feature,
layering and dependency rules, data sources, clean-code conventions)
lives elsewhere under `docs/`, not here.
