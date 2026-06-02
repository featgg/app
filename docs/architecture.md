# Architecture

This document is canon rank 4 in the source-precedence ladder: `AGENTS.md` (rank 1) > `pubspec.yaml` (rank 2) > `docs/integration/` (rank 3) > this document (rank 4) > code. Where anything here conflicts with a higher-ranked source, that source wins without exception. It formalizes the Flutter patterns and architectural decisions for the app — layering, the data/integration contract, the error model, state management, UI/presentation conventions, internationalization, testing, and observability — and is also enforced by the reviewer checklist in `.claude/agents/app-reviewer.md`. It governs the `lib/src/` skeleton.

Two conventions, to avoid noise throughout: a package named here is pinned in `pubspec.yaml`, and its version is not restated, unless the text marks it as not yet present; and a rule attributed to `AGENTS.md` is cited once where it is introduced, not in every section that relies on it.

## Architecture

### Layers

The app follows Clean Architecture with four layers and a strict source-dependency rule. The reviewer checklist expresses the layering in this left-to-right order:

```
presentation → application → domain → data
```

In source-dependency terms, every layer depends inward toward `domain`, the dependency-free core: `presentation` depends on `application`; `application` depends on `domain`; and `data` also depends on `domain` — it implements `domain`'s repository interfaces rather than the other way around. The dependency direction never reverses; the reviewer agent enforces it, not convention (§ Dependency rule and enforcement).

### Responsibility of each layer

**domain** — pure entities, repository interfaces, and business rules. Entities (and value objects) model the domain and are immutable; repository interfaces declare the contracts that `data` implements; business rules, when a feature has them, are pure logic. This layer contains no Flutter framework imports, no client SDK imports, and no serialization annotations. It is the stable core all other layers depend on. Many features have no business rule beyond the entity itself, which is correct.

**application** — *optional* orchestration services. A service combines two or more repositories (or reuses a rule across controllers) into one operation that belongs to no single controller or repository; it depends on repository interfaces, never on an implementation, and never touches the client SDK or HTTP. This layer is optional and decided per feature: when no orchestration is needed it is absent, and a `presentation` controller calls a single repository directly (§ Services and the application layer). Calls through a service return `Either<Failure, T>`.

**data** — repository implementations, data sources, DTOs, and mappers. This is the only layer that touches the client SDK (`supabase_flutter`) or makes HTTPS calls. It implements the repository interfaces declared in `domain`, converts wire/SDK shapes to domain entities, and maps errors to `Failure` subtypes at the layer boundary.

**presentation** — widgets, screens, and controllers. Widgets render state and dispatch user intent; controllers — Riverpod providers and `AsyncNotifier`s, the equivalent of a cubit — hold a screen's state, perform mutations, and call a repository through its `domain` interface (or, when one exists, an application service). The controller is the use case. This layer holds no business rule of its own; it never touches the `data` layer's SDK/HTTP and never inspects a raw error — it branches only on `Failure`/`AsyncValue` values.

### Directory layout

The canonical directory tree is:

- `lib/src/core/` — cross-cutting concerns: error model, client initialization, router, theme, env wiring, the centralized breakpoint helper, the reusable `AsyncValueWidget`, and the `CrashReporter`/`AnalyticsService` interfaces.
- `lib/src/features/<feature>/` — one directory per product feature, subdivided into `data/`, `domain/`, and `presentation/`, plus an optional `application/` present only when the feature needs an orchestration service.

This document fixes their layout and responsibilities; the directories themselves live in code.

### Dependency rule and enforcement

A layer may import only code in its own sub-tree and code in layers it depends inward on. Concretely: `presentation` may import `application` and `domain`; `application` may import `domain`; `data` may import `domain`. No layer imports code from a more outward layer. Additionally, a feature's `application/` and `data/` internals are not importable by a different feature; only `domain` entities and interfaces cross feature boundaries. The reviewer enforces both the inward-only layer rule and cross-feature isolation on every review (`.claude/agents/app-reviewer.md` § Review checklist), not convention alone — no cross-feature coupling for a single caller.

### Data layer and the integration contract

The briefs in `docs/integration/` define two shapes for backend surfaces, and the data layer maps each to a distinct data-source role:

- **Shape 1 (server operation)** — a data source calls an HTTPS endpoint at a path under `/functions/v1/<name>` or `/auth/v1/`. It parses the stable envelope: a success response carries `success: true` plus operation-specific fields; an error response carries `success: false` with a stable `code` token and a human-readable `message`. The data source branches on the `code` token, not on HTTP status alone, because several distinct errors may share one status code (see the connections and account-deletion briefs for the error tables).
- **Shape 2 (direct data access)** — a data source reads or writes public tables via the client SDK (`supabase_flutter`) under row-level authorization. The access rules and writable columns are as the relevant brief states; the client SDK surfaces errors as its typed error type, which the data source maps to a `Failure` subtype.

**Load-bearing invariant:** no data-layer call may be written without a corresponding brief in `docs/integration/`. Until a brief exists for a surface, the repository method returns `Either.left(NotImplemented)`. This is stated in `docs/integration/README.md` and restated in `AGENTS.md` § Public-repo discipline.

### Error model boundary

Every repository method returns `Either<Failure, T>` (via `fpdart`). The `data` layer is the only place that touches raw SDK errors or HTTP responses; it translates them into `Failure` subtypes at the boundary before anything crosses into `application` or `presentation`. A Shape-1 `code` token maps to a `Failure` subtype; a Shape-2 SDK error maps to a `Failure` subtype. The `application` and `presentation` layers branch on `Failure` values — they never inspect an HTTP status code or a raw SDK error type directly.

**Errors do not flow backward.** Data flows up (data source → repository → (application, when present) → presentation), and errors flow up in the same direction, as values on the `Left` of an `Either` — nothing is ever thrown back down to be re-mapped. There is a single `try/catch` in the whole stack: in the repository implementation, where a raw SDK error is caught and converted to a `Left(Failure)`. Above that boundary there is no per-layer `try/catch`; an expected failure is a value, not a Dart exception.

**Which layer produces which failure.** The `data` layer is the source of technical failures (5xx, timeouts, SDK errors, `code` tokens). `domain` is the source of business-rule failures, and these are rare: `domain`'s purpose is entities and rules, not error handling, and in this app many features have no business rule and therefore produce no `domain` failure — which is correct, not a smell. When a rule does exist, `domain` constructs a `Left(Failure)` itself; it never throws and never returns an error to the data source.

**Folding into UI state.** The controller folds the `Either`: a `Right` becomes the success value (an `AsyncData`), and a `Left` is surfaced through the `AsyncValue` error channel (an `AsyncError`), so every screen renders state uniformly via `AsyncValueWidget`. The conversion into UI state happens in the controller, which lives in `presentation`.

The concrete `Failure` taxonomy (the specific subclasses and the mapping function) is defined in code, not this document. This section fixes the boundary rule only. A `Failure` carries a stable `code`/type, not user-facing text; the `presentation` layer maps that code to a localized string (§ Internationalization).

## Design patterns

### Governing principle

KISS and minimal patch are the default stance (`AGENTS.md` § Core principles). A pattern is adopted only when a second concrete caller exists or a layer boundary requires it. No abstraction is introduced for a single caller. Each pattern below states the condition under which it applies; none is "always use".

### State management — Riverpod codegen

Riverpod with code generation is the only state-management and dependency-injection mechanism in this codebase. Providers are annotated with `@riverpod` (from `riverpod_annotation`) and their implementations are generated by `riverpod_generator`; `flutter_riverpod` wires providers into the widget tree. Legacy `StateNotifier` is forbidden, as stated explicitly in `AGENTS.md` § Stack. Controllers — the providers and `AsyncNotifier`s that hold screen state — live in the `presentation` layer alongside the widgets they serve; the optional `application` layer holds orchestration services only.

**Use cases are providers/controllers.** The use case is the controller itself, not a separate class: a read is a derived provider, a mutation is an `AsyncNotifier`, both living in `presentation`. A widget never calls a repository or a data source — it watches a provider or calls a controller method; the controller, in turn, calls a single repository interface directly (or an application service when one exists). A standalone service is introduced only for real orchestration: more than one repository combined into a single operation, or a rule reused by more than one controller. A service that only forwards a single repository call is not written; it is friction without benefit.

**Ephemeral visual state uses `setState`.** State that is purely visual, does not outlive the widget, and carries no domain meaning stays in the widget via `setState`. Riverpod is used when state has domain meaning, is shared between widgets, or must outlive the widget. This is detailed at the screen level below.

### Dependency injection

Dependencies — repository implementations, the client SDK instance, and other services — are provided through Riverpod providers and overridden in tests via `ProviderScope` overrides. No service locator and no global singletons are used; this keeps test isolation mechanical rather than fragile.

### Functional error handling — Either/Option

Fallible operations return `Either<Failure, T>` from `fpdart`. When absence is a meaningful value rather than an error, `Option<T>` is used. Expected failures do not cross layer boundaries as Dart exceptions; they are values on the `Left` side of `Either`.

### Immutability and value equality

Domain entities and application state objects are immutable. Value equality is established via `Equatable` or generated `==`/`hashCode`, not by reference identity. This prevents a class of bugs where two logically identical states are treated as different because they occupy different memory addresses.

### Repository pattern and the single data-layer abstraction

`domain` declares repository interfaces; `data` implements them; callers (a `presentation` controller, or an `application` service when one exists) depend on the interface, never the implementation. The repository interface is the **only** abstraction at the data boundary — there is no separate abstract contract over a data source. A data source is always concrete, so navigation goes straight to the implementation without an interface hop. This is deliberate: the repository interface is the layer-crossing seam Clean Architecture requires (it inverts the dependency so `data` points at `domain`), whereas a second abstraction over the data source would be friction for a single caller.

Where a repository has a single data source (the backend), the data-source calls are collapsed into the repository implementation; a separate data-source class is introduced only when there is more than one source to coordinate (for example a remote source plus a local cache). In either case the repository implementation is the coordinator and lives in `data` — it is not `domain` that coordinates data sources. Interfaces live in `domain/`; their implementations live in `data/`. Naming follows a strict convention so the abstract↔implementation jump stays cheap to navigate: the interface is `XRepository` and its implementation is `XRepositoryImpl` (for example `ProfileRepository` / `ProfileRepositoryImpl`).

### Services and the application layer

A service is a plain Dart class in the `application` layer that orchestrates two or more repositories (or reuses a rule across controllers) into a single operation that belongs to no individual controller or repository. It is the only inhabitant of the `application` layer, and that layer is optional — decided feature by feature.

A service exists only when at least one condition holds: the operation combines **two or more repositories** into one action, or the **same orchestration is reused by two or more controllers**. When neither holds, no service is written — a `presentation` controller depends on a single repository interface and calls it directly. A service that merely forwards one call to one repository is the anti-pattern this rule forbids.

A service is **not** an alternative path that bypasses the data layer. Every backend datum still flows through a data source and a repository; a service sits *above* repositories and calls them. It never touches the client SDK or HTTP, holds no data source, and is not a repository (it implements no repository interface). It depends on repository interfaces (in `domain`), receives entities — never DTOs — and returns `Either<Failure, T>` or a composed entity. Like a data source, a service is concrete: the only abstraction at the data boundary remains the repository. It is provided and overridden through Riverpod like everything else.

This is the inverse of a data source, which is why the two never overlap: a **data source** sits at the bottom and faces outward — it speaks to the backend and returns raw DTOs — while a **service** sits near the top and faces inward — it composes already-validated entities from several repositories. One fetches raw data from outside; the other combines clean data from inside.

In this app, services are expected to be rare. Because the backend exposes server operations (Shape 1 endpoints under `/functions/v1/`), most cross-entity orchestration happens server-side: a screen that needs several entities combined is usually served by one endpoint — hence one repository and no service. A client-side service appears only when the client must combine two *separate* backend surfaces that no single endpoint joins.

### DTO ↔ entity mapping and vocabulary

The codebase uses exactly two names for data shapes, and "model" is not one of them:

- A **DTO** is the wire/SDK shape. It lives in `data` and is annotated with `json_annotation` (generated by `json_serializable`). A data source returns a typed DTO — never a raw `Map` or loose primitives passed upward. Parsing the wire into a DTO happens once, at the edge (`fromJson`), where a parse failure maps cleanly to a `Failure`; this is preferred over stringly-typed `map['key']` access scattered through the layer, which moves errors to runtime and forfeits compile-time checking, autocomplete, and refactor safety. Every wire or SDK response shape is a DTO, without exception; the choice is not left to per-call judgment, which keeps the boundary uniform — even a trivial single-field response is a DTO, for consistency.
- An **entity** is the domain object. It lives in `domain`, is pure and immutable, and carries no serialization annotation.

The `data` layer maps a DTO to an entity before returning values upward; `domain` and the layers above it only ever see entities — never a DTO and never a `Map`. `domain` never imports a DTO or a serialization annotation; if it did, it would acquire a dependency on the wire format, violating the dependency rule.

### Navigation — go_router

Declarative routing is provided by `go_router`. Routes are configured centrally in `lib/src/core/router/`. The `presentation` layer triggers navigation; `application` and `domain` layers do not import `go_router`. The router config itself lives in code; this section fixes the location and the no-import rule for inner layers.

### Configuration — compile-time defines and environments

Runtime configuration is read via `--dart-define-from-file`; `flutter_dotenv` is not used. There are two environments — **staging** (where development and testing happen, against fake/test data) and **production** (real users) — each backed by its own Supabase project. Each environment has its own config file:

- `env.staging.json` — Supabase URL and anon key for the staging project.
- `env.production.json` — Supabase URL and anon key for the production project.

**The config file is the single mechanism that selects which backend the app talks to.** The environment is chosen at run/build time by passing the file; no other mechanism (including a Flutter flavor) selects the backend:

```
flutter run        --dart-define-from-file=env.staging.json
flutter build apk  --dart-define-from-file=env.production.json
```

In the editor, the two configurations live in `launch.json` and are selected from the run dropdown rather than typed by hand.

Both real config files are gitignored without exception; a single committed template, `env.example.json`, documents their shape (staging and production are identical in form and differ only in values). The Supabase anon key is designed to be distributed in a client and is not a secret in the traditional sense, but the "no real env file in git" rule has no exceptions, to keep the boundary simple. No secret is ever committed.

**Flutter flavors are deliberately not used yet.** A flavor controls native app identity (application id, icon, name) so that staging and production can be installed side by side on a single device; it does not select the backend — the config file does. For a single developer this side-by-side capability earns its cost only near the closed beta, when a production beta build and a staging dev build must coexist on the same device. Flavors are therefore deferred. The production application id is nonetheless fixed now, so the store identity never changes after publication and the later flavor retrofit stays safe.

### Theming — design tokens

Colors, spacing, typography, and border radii live as named design tokens. `ThemeData` is derived from tokens; widgets consume tokens, not hard-coded values (§ No hard-coded values). `google_fonts` and `flutter_svg` are used for typography and icon rendering respectively. The concrete token definitions live in code; the design rationale behind the specific values — palette, type scale, spacing scale — is a design-system concern, not fixed here.

## UI and presentation conventions

This part fixes the structural rules for the `presentation` layer. It deliberately contains rules, not visual or UX decisions. The dividing line: **a structural rule the reviewer can enforce belongs here; a value that changes with design judgment belongs in the design system.** The existence of design tokens, the prohibition on hard-coded values, where responsive logic lives, and the state-rendering pattern are rules and live here. The concrete visual and UX values — the palette, the exact breakpoint pixels, whether an error is a snackbar or a full screen, whether loading is a skeleton or a spinner — are design decisions that live in `docs/design-system.md`, not here.

### Dummy widgets

A screen or widget renders state and dispatches user intent; it holds no business logic. It watches its feature's controllers (providers/notifiers in `presentation`) and calls their methods. It never reaches the `data` layer, never inspects an HTTP status or a raw SDK error, and never branches on anything other than `Failure`/`AsyncValue` state.

### No hard-coded values

Colors, spacing, typography, and border radii are consumed as named design tokens; a widget never hard-codes a color or a magic number. User-facing text is consumed from localization; a widget never hard-codes a string. Both are enforced rules, not conventions.

### Responsive layout

The app is mobile-first and also targets desktop and web. Mobile-first means the base layout is the mobile layout, and constraints for larger surfaces (a maximum content width, multi-column arrangements) are added on top — not a desktop layout shrunk down. Breakpoints are defined once, centrally, in `core` (as named values, like tokens). A widget branches on layout via `LayoutBuilder` and the central breakpoint helper. Scattered `MediaQuery.of(context).size.width > N` checks are forbidden — every screen reads the same breakpoint definitions so layout behavior is consistent across the app. The specific breakpoint pixel values are a design-system concern.

### State: reads vs. writes

Two patterns cover all screen state, and every feature follows the same mold:

- **Reads** are derived providers (`@riverpod Future<T> …`). A widget consumes one with `ref.watch(...)` and renders its `AsyncValue`.
- **Writes/mutations** are an `AsyncNotifier` (`@riverpod class …Controller`) exposing methods the widget calls. A method runs the operation inside `AsyncValue.guard` — which turns a throwing future into an `AsyncValue`, keeping the result as a value rather than letting an exception escape — and then invalidates the affected read providers (`ref.invalidate(...)`) so the UI refreshes.

Both the read providers and the mutation controllers live in the `presentation` layer of their feature. A widget watches a provider or calls a controller method; the controller calls a single repository interface directly, or — only when orchestration is needed — an application service. Nothing skips straight to a data source.

### Ephemeral state

State that is purely visual, does not outlive the widget, and has no domain meaning — a dropdown's open/closed flag, a text field's contents before submit, an `AnimationController`, `obscureText` — uses `setState`. Riverpod is used when state has domain meaning, is shared between widgets, or must outlive the widget. This does not weaken the dummy-widget rule: business state stays in providers.

### Centralized loading and error rendering

Loading and error states are rendered through a single reusable `AsyncValueWidget<T>` in `core`, not re-implemented per screen. This is the structural seam: the concrete look of loading and error (skeleton vs. spinner, snackbar vs. banner vs. full screen) is a design-system decision and, because rendering is centralized here, can be changed in one place without touching screens.

## Internationalization (i18n)

The app ships in three locales: English (`en`), Spanish (`es`), and Portuguese (`pt`). Localization uses `flutter_localizations` with `intl` and ARB files compiled by `flutter gen-l10n`; `slang` and ad-hoc string maps are not used. The setup — dependencies, ARB files, and generation wiring — lives in code.

User-facing text lives only in `presentation` (under a feature's `presentation/` or a shared `l10n` location); it is never hard-coded in a widget and never present in `domain` or `data`. Consequently, a `Failure` never carries user-facing text — it carries a stable `code`/type, and the `presentation` layer maps that code to a localized string. A backend `message` is for logs and developers, not for direct display. This keeps the error model decoupled from presentation and fully translatable.

## Testing

The goal is to cover the most probable failure points, not to maximize line coverage; there is no coverage threshold. Tests are added where there is behavior that can break, ordered by value:

1. **Repository implementations (data)** — the highest-value tests. They exercise DTO→entity mapping, Shape-1 envelope (`code`) parsing, and SDK-error→`Failure` mapping at the boundary, written against a fake of the client SDK: given a wire response, assert the entity; given an error envelope or SDK error, assert the `Failure` subtype. This is the most probable failure point in the codebase.
2. **Domain logic** — cheap and high-value (pure Dart, no mocks), but only where a real business rule, calculation, or validating value object exists. A repository interface is a declaration and is not tested; an entity that is plain data is not tested. Many features have no domain test, and that is correct.
3. **Mutation controllers (presentation)** — `AsyncNotifier`s that carry mutation logic, tested with `ProviderContainer`/`ProviderScope` overrides that inject fakes. Read-only passthrough providers are not worth testing.
4. **Widget tests (presentation)** — assert that each `AsyncValue` state renders correctly (loading, error, data). These catch UI-state regressions.

This is not "four tests per feature": a given feature may have tests in only one or two of these layers. **Golden tests are deferred** (fragile across platforms and fonts, high maintenance) and are not a gate; they may later cover a small set of stable design-system components. **Integration tests are not run as a suite** (slow and brittle for a solo developer); at most a single end-to-end test for one critical flow may be added if that flow proves regression-prone.

Mocking uses `mocktail` (no code generation), to be added to dev dependencies. Riverpod is tested with `ProviderContainer` from the framework — no `bloc_test`-style package is required. The pull-request gate is qualitative, not a percentage: when a repository implementation is created or changed, it lands with its mapping and error tests.

## Observability — crash reporting and analytics

Two cross-cutting concerns live behind abstractions in `lib/src/core/`: a `CrashReporter` and an `AnalyticsService`. Both are abstract interfaces; their concrete implementations are wired through Riverpod providers in code, not fixed by this document. Defining them as interfaces here fixes three things: the rest of the app depends on the interface and never on a vendor SDK directly, the implementation is swappable without touching any feature, and user opt-out is enforced in one place. These are thin cross-cutting `core` services — distinct from the feature-level orchestration services of the `application` layer — not a telemetry framework.

- **`CrashReporter`** — captures unexpected errors and crashes (both native and Flutter). Not every `Failure` is reported: expected failures (for example `UNAUTHORIZED`, `INVALID_REQUEST`) are normal control flow and are noise; only unexpected failures (a DTO that failed to parse, a 5xx, an unhandled exception) are reported. The capture points are the repository implementation (where an unexpected error is already being mapped) and a global Riverpod provider observer for otherwise-uncaught provider errors; an SDK-level filter (a `beforeSend`-style hook) drops expected failures before anything leaves the device. The concrete wiring — including that filter — lives in the `CrashReporter` implementation, not here.
- **`AnalyticsService`** — records anonymous product events. The concrete implementation (Aptabase) is wired near the closed-beta milestone; until then a no-op implementation satisfies the interface so call sites can be written without the SDK present.

Privacy is a design constraint, not an afterthought: analytics events carry no PII and no stable user identifier; the user can opt out (the opt-out flag short-circuits `AnalyticsService` to a no-op); only data that will actually be used is collected (data minimization). This holds the codebase close to GDPR/CCPA norms even though the product does not target the EU. No token or session value is ever sent to either service.

## Security model

This section describes the app's own client-side security model. For reporting a discovered vulnerability, see `SECURITY.md` (a separate document covering disclosure policy and scope).

### Trust boundary

The backend is an opaque HTTPS service and the authority for all authorization decisions. The client never enforces authorization itself. Row-level authorization on the backend — which controls which rows a given session may read or write — is the trust boundary, as described in the integration briefs. Client-side input validation exists for fast UX feedback; it is not a security control. The client treats every server-enforced rule as authoritative and degrades gracefully when a request is denied.

### Session and token handling

A successful sign-in yields a bearer JWT (valid approximately one hour) plus a refresh token, as described in `docs/integration/auth.md`. The client SDK (`supabase_flutter`) owns session storage and automatic token refresh; the app never hand-rolls token persistence, never logs a token value, and never passes a token through an untrusted channel. Sign-out clears the session via the SDK.

### Secrets and configuration

No secret is committed to this repository (`AGENTS.md` § Core principles: "No commits with secrets"). Runtime configuration — including the SDK's public/anon key and the backend base URL — arrives via `--dart-define-from-file` from a per-environment config file (`env.staging.json` or `env.production.json`), both gitignored. The SDK's public/anon key is designed to be distributed in a client and is not a secret in the traditional sense; all privileged operations still require a valid session token enforced server-side.

### Public-vs-owner data exposure

Some data surfaces are publicly readable — public profiles, public game cards, and widgets of public profiles (tables `profiles`, `game_cards`, `profile_widgets`) — via the SDK's public key without a session token, as documented in the relevant briefs. Private and owner-only data requires a valid session token and is enforced server-side by row-level authorization; `privacy_level` on a profile propagates server-side to the visibility of that user's cards. The client renders only what the backend returns and degrades gracefully on a denial rather than assuming access or attempting to unlock data locally.

### Authorization failures and re-auth

A `UNAUTHORIZED` error (HTTP 401, code token `UNAUTHORIZED`) from any Shape-1 operation, or an equivalent session-expired condition from the SDK, maps to a `Failure` subtype that drives the application to a re-authentication path. The client never retries a privileged call with a known-invalid session. Such expected failures are not reported to the crash reporter.

### Input handling

Client-side validation mirrors the field constraints documented in the briefs — for example the `display_name` 1–50 and `bio` 150-character limits in the profile brief, or the `INVALID_REQUEST` error in the connections brief — for fast UX feedback before a round trip. The backend constraint is authoritative. When the backend surfaces a constraint violation (a Shape-2 SDK error or a Shape-1 `INVALID_REQUEST` code), the data layer maps it to a `Failure` and the presentation layer shows the user a meaningful, localized message.

**Rate-limit back-off.** The same client-vs-server split governs rate limiting. A client-side throttle is anti-spam UX only: it stops accidental mashing and is treated as bypassable (closing and reopening the app clears it) — never a real rate-limit control. It is kept short (a few seconds), with one exception: when a brief documents a *fixed* minimum interval for an action (e.g. the email-code resend window), the client mirrors that interval as its proactive countdown — the same way client-side validation mirrors a documented field constraint (§ Input handling) — so the action re-enables exactly when the server would next accept it, rather than a few seconds early into a guaranteed rejection. The authoritative limit is still the backend's, surfaced as a rate-limit `Failure` (HTTP 429 class); only that drives the longer "try again shortly" message and reactive back-off. The client never invents a long block of its own, because a long client block punishes honest mistakes while doing nothing a determined caller cannot bypass.

### Deep links and platform surfaces

Inbound deep links (App Links on Android, Universal Links on iOS) are treated as untrusted input. The router resolves an inbound URI to a named route, but reaching a privileged destination still gates on current session state — the router does not bypass authorization. An OAuth redirect (part of the PKCE flow for Google and Discord sign-in) is handled per `docs/integration/auth.md`. The deep-link platform plumbing lives in code.

## Source precedence and amendments

This document is canon rank 4. When anything here conflicts with `AGENTS.md` (rank 1), `pubspec.yaml` (rank 2), or `docs/integration/` (rank 3), those higher-ranked sources win without exception. Amendments to this document ship as their own PR following the standard workflow; they do not accompany feature PRs.