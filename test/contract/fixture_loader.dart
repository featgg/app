import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A recorded backend response replayed through the app's real DTOs/mappers.
/// [status] is the HTTP status for Shape-1 server-operation fixtures and null
/// for Shape-2 direct-data fixtures; [payload] is the recorded response body
/// (Shape 1) or `widget_data` envelope (Shape 2).
typedef RecordedFixture = ({int? status, Map<String, dynamic> payload});

/// Decodes a recorded-fixture wrapper. If `__PLACEHOLDER__` is `true` the
/// fixture still holds scaffold data, so this fails loudly (naming [source])
/// rather than asserting against invented values — the runtime gate that keeps
/// the contract suite red until the slot is filled with published fixture
/// data (published fixtures omit the key entirely).
RecordedFixture parseRecordedFixture(
  String jsonContent, {
  required String source,
}) {
  final map = jsonDecode(jsonContent) as Map<String, dynamic>;
  if (map['__PLACEHOLDER__'] == true) {
    fail(
      'Fixture "$source" is still a placeholder — its slot has not been '
      'provisioned with published fixture data yet '
      '(see test/contract/README.md).',
    );
  }
  return (
    status: map['status'] as int?,
    payload: map['payload'] as Map<String, dynamic>,
  );
}

/// Reads a fixture file relative to the package root (guaranteed cwd under
/// `flutter test`) and parses it. A missing/unreadable file throws, so the
/// test errors red rather than silently skipping.
RecordedFixture loadRecordedFixture(String relativePath) =>
    parseRecordedFixture(
      File(relativePath).readAsStringSync(),
      source: relativePath,
    );
