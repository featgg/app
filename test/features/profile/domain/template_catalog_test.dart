import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/features/profile/domain/data_menu_catalog.dart';
import 'package:featgg/src/features/profile/domain/template_catalog.dart';
import 'package:featgg/src/features/profile/presentation/template_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'templateCatalog — well-formedness (iterates, no per-template case)',
    () {
      test('the catalog is non-empty', () {
        expect(templateCatalog, isNotEmpty);
      });

      test('every template has a unique, non-empty id and title key', () {
        final ids = templateCatalog.map((t) => t.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id');
        for (final t in templateCatalog) {
          expect(t.id, isNotEmpty, reason: t.id);
          expect(t.titleKey, isNotEmpty, reason: t.id);
          expect(t.slots, isNotEmpty, reason: t.id);
        }
      });

      test('every slot id is unique within its template', () {
        for (final t in templateCatalog) {
          final slotIds = t.slots.map((s) => s.id).toList();
          expect(
            slotIds.toSet(),
            hasLength(slotIds.length),
            reason: 'duplicate slot id in ${t.id}',
          );
        }
      });

      test('every slot has a real category and a non-empty label key', () {
        for (final t in templateCatalog) {
          for (final slot in t.slots) {
            expect(
              DataMenuCategory.values,
              contains(slot.category),
              reason: '${t.id}/${slot.id}',
            );
            expect(slot.id, isNotEmpty, reason: t.id);
            expect(slot.labelKey, isNotEmpty, reason: '${t.id}/${slot.id}');
          }
        }
      });

      test('templateDefinitionById finds a known id and is null otherwise', () {
        expect(templateDefinitionById(templateCatalog.first.id), isNotNull);
        expect(templateDefinitionById('not_a_template'), isNull);
        expect(templateDefinitionById(null), isNull);
      });
    },
  );

  group('label resolver totality', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every template title key resolves to a non-empty string', () {
      for (final t in templateCatalog) {
        final label = templateTitleLabel(l10n, t.titleKey);
        expect(label, isNotNull, reason: t.id);
        expect(label, isNotEmpty, reason: t.id);
      }
    });

    test('every slot label key resolves to a non-empty string', () {
      for (final t in templateCatalog) {
        for (final slot in t.slots) {
          final label = templateSlotLabel(l10n, slot.labelKey);
          expect(label, isNotNull, reason: '${t.id}/${slot.id}');
          expect(label, isNotEmpty, reason: '${t.id}/${slot.id}');
        }
      }
    });
  });
}
