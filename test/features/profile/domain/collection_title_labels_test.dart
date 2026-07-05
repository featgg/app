import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/profile/domain/collection_title_catalog.dart';
import 'package:featgg/src/features/profile/presentation/collection_title_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collectionTitleCatalog — well-formedness', () {
    test('the catalog is non-empty with unique, non-empty keys', () {
      expect(collectionTitleCatalog, isNotEmpty);
      expect(
        collectionTitleCatalog.toSet(),
        hasLength(collectionTitleCatalog.length),
        reason: 'duplicate catalog key',
      );
      for (final key in collectionTitleCatalog) {
        expect(key, isNotEmpty);
      }
    });
  });

  group('collectionTitleLabel — totality across locales', () {
    for (final locale in const [Locale('en'), Locale('es'), Locale('pt')]) {
      test(
        'every catalog key resolves to a non-empty label in $locale',
        () async {
          final l10n = await AppLocalizations.delegate.load(locale);
          for (final key in collectionTitleCatalog) {
            final label = collectionTitleLabel(l10n, key);
            expect(label, isNotNull, reason: '$key ($locale)');
            expect(label, isNotEmpty, reason: '$key ($locale)');
          }
        },
      );
    }

    test('an unknown key returns null', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(collectionTitleLabel(l10n, 'collectionTitleNope'), isNull);
    });
  });
}
