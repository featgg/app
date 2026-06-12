import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cross-feature isolation gate. The settings feature may reach the profile
/// feature only through its `domain`; it must never import a profile
/// `presentation` file nor reference `profileProvider` (the profile read
/// provider, which lives in profile presentation). This test guards that rule
/// at the source level, independent of the layering reviewer.
///
/// Comment lines are skipped so the doc-comments that *mention* `profileProvider`
/// to explain the rule are not counted as violations — only real code is.
void main() {
  test(
    'no settings source references profileProvider or profile presentation',
    () {
      final dir = Directory('lib/src/features/settings');
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'settings feature directory must exist',
      );

      final providerRef = RegExp(r'\bprofileProvider\b');
      final offenders = <String>[];

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (final line in lines) {
          // Skip line comments (including `///` doc-comments) — only code counts.
          if (line.trimLeft().startsWith('//')) continue;
          if (providerRef.hasMatch(line)) {
            offenders.add('${entity.path}: references profileProvider');
          }
          if (line.contains('profile/presentation')) {
            offenders.add('${entity.path}: imports profile/presentation');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );
}
