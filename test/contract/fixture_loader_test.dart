import 'package:flutter_test/flutter_test.dart';

import 'fixture_loader.dart';

void main() {
  group('parseRecordedFixture', () {
    test('placeholder fixture fails loudly, naming its source', () {
      const json =
          '{"__PLACEHOLDER__": true, "status": 200, '
          '"payload": {"any": "REPLACE_ME"}}';
      expect(
        () => parseRecordedFixture(json, source: 'sample.json'),
        throwsA(
          isA<TestFailure>().having(
            (f) => f.message,
            'message',
            contains('sample.json'),
          ),
        ),
      );
    });

    test('non-placeholder fixture returns payload and status', () {
      const json =
          '{"__PLACEHOLDER__": false, "status": 200, '
          '"payload": {"success": true, "otp_sent": true}}';
      final fixture = parseRecordedFixture(json, source: 'sample.json');
      expect(fixture.status, 200);
      expect(fixture.payload, {'success': true, 'otp_sent': true});
    });

    test('omitted status yields null (Shape-2 direct-data fixtures)', () {
      const json =
          '{"__PLACEHOLDER__": false, "payload": {"schema_version": 1}}';
      final fixture = parseRecordedFixture(json, source: 'card.json');
      expect(fixture.status, isNull);
      expect(fixture.payload, {'schema_version': 1});
    });
  });
}
