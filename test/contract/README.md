# Contract tests

These tests replay **recorded real** backend responses through the app's actual
DTOs and repository/mapper code. Unlike our unit tests, the JSON does not come
from us — it is captured from the real backend and cleaned of secrets. A real
contract change (a renamed field, a changed or added error code, a schema bump,
a format drift) turns CI red here instead of shipping green and surfacing only
on a manual install.

They are **contract** tests, not integration tests: offline, fast, no emulator,
no live network. The only thing different from a unit test is *where the JSON
comes from*.

## The `__PLACEHOLDER__` gate

Every fixture is a wrapper:

```json
{ "__PLACEHOLDER__": true, "status": 200, "payload": { } }
```

- `__PLACEHOLDER__` (bool, required) — `true` while the fixture is scaffolded.
  A `true` fixture makes `parseRecordedFixture` **fail loudly**, naming the
  file. This keeps the contract suite red until a human drops cleaned real data.
- `status` (int, optional) — HTTP status for server-operation (Shape 1)
  fixtures; omitted for direct-data (Shape 2) fixtures.
- `payload` (object, required) — the recorded response body (Shape 1) or the
  recorded `widget_data` envelope (Shape 2).

`fixture_loader_test.dart` is green: it proves the gate itself. The
`*_contract_test.dart` suites are red on purpose while their fixtures are
placeholders — that is the gate working, not a bug.

## Adding (or filling in) a contract test

1. **Identify the endpoint or table.** Find the brief it is governed by under
   `docs/integration/` (for example `account-deletion.md`, `feed.md`). The
   brief is the contract; the assertions enforce it.
2. **Capture a real response.** Against the staging backend, capture the real
   response body (Shape 1) or read the real `widget_data` envelope (Shape 2)
   using an API client (for example, a Bruno collection).
3. **Clean every secret and PII before saving.** Replace, consistently:
   - bearer tokens / JWTs → `fake-jwt`
   - emails → `test@example.com`
   - user / account ids → a fixed UUID
   - timestamps → a fixed value (keep the real *format*: epoch ms stays epoch
     ms, ISO stays ISO)

   Keep the shape exact: every real field name, type, and nesting must survive
   the cleaning. Only the *values* are scrubbed. `gitleaks` (pre-commit + the
   CI `secrets` job) scans `test/`, so a leaked token is blocked — but clean by
   hand anyway.
4. **Drop the cleaned payload in and flip the gate.** Put the cleaned body
   under `payload`, set the right `status` (Shape 1 only), and set
   `"__PLACEHOLDER__": false`.
5. **Run the suite.** `flutter test test/contract`. The fixture's test now
   asserts the documented mapping against the brief and should go green; if it
   is red, either the backend drifted from the brief or the app mapper did —
   investigate before forcing it green.

## Layout

```
test/contract/
  fixture_loader.dart          # the __PLACEHOLDER__ gate + file reader
  fixture_loader_test.dart     # green self-test of the gate
  account_deletion_contract_test.dart
  cards_contract_test.dart
  fixtures/
    account_deletion/*.json
    cards/*.json
```
