# Contract tests

These tests replay **recorded** backend responses through the app's actual
DTOs and repository/mapper code. Unlike our unit tests, the JSON does not come
from us — the fixtures are published, pre-sanitized, from the backend's own
contract artifact, where they are validated against the backend's documented
contract before anything lands here. A real contract change (a renamed field,
a changed or added error code, a schema bump, a format drift) turns CI red
here instead of shipping green and surfacing only on a manual install.

They are **contract** tests, not integration tests: offline, fast, no emulator,
no live network. The only thing different from a unit test is *where the JSON
comes from*.

## Fixture wrapper

Every fixture is a wrapper around the recorded body:

```json
{ "status": 200, "payload": { } }
```

- `status` (int, optional) — HTTP status for server-operation (Shape 1)
  fixtures; omitted for direct-data (Shape 2) fixtures.
- `payload` (object, required) — the recorded response body (Shape 1) or the
  recorded `widget_data` envelope (Shape 2).
- `__PLACEHOLDER__` (bool) — present (and `true`) only while a slot is
  scaffolded and still awaiting published data. Such a fixture makes
  `parseRecordedFixture` **fail loudly**, naming the file, so its suite stays
  red until the slot is provisioned. Published fixtures omit the key.

`fixture_loader_test.dart` proves the gate itself.

## Adding a contract test

1. **Identify the endpoint or table.** Find the brief it is governed by under
   `docs/integration/` (for example `account-deletion.md`, `feed.md`). The
   brief is the contract; the assertions enforce it.
2. **Scaffold the test and its fixture slot.** Write the suite against the
   brief and add a placeholder fixture (`"__PLACEHOLDER__": true`). The suite
   stays red — that is the gate working, not a bug.
3. **The fixture content arrives by publication.** Fixture slots are filled
   from the backend's published contract artifact; fixtures are sanitized and
   validated at the source and must **never be hand-edited here**. If a slot
   stays unprovisioned or a published fixture looks wrong, raise it — do not
   invent data.
4. **Run the suite.** `flutter test test/contract`. A filled fixture's test
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
