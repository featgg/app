import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/composition_editor_rows.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Serves a fixed set of owner widgets; every mutation is out of scope here.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// No card for any platform, so the seeded Rank/Main cards render their neutral
/// no-data state without any real image decode.
final class _NullCardsRepository implements CardsRepository {
  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(null);
}

const _rank = ProfileWidget(
  id: 'r',
  kind: ProfileWidgetKind.rank,
  platform: Platform.leagueOfLegends,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

const _main = ProfileWidget(
  id: 'm',
  kind: ProfileWidgetKind.main,
  platform: Platform.steam,
  position: 1,
  isEnabled: true,
  size: ProfileWidgetSize.small,
);

Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PersonalizationTheme(
        palette: PersonalizationPalette.crimson,
        child: const SingleChildScrollView(
          child: CompositionEditorRows(columnWidth: 360),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a seeded Rank (now dual-size) shows a size toggle and bootstraps '
      'as a full row, like Main', (tester) async {
    final container = ProviderContainer(
      retry: (count, error) => null,
      overrides: [
        profileWidgetsRepositoryProvider.overrideWithValue(
          _FakeWidgetsRepository(const [_rank, _main]),
        ),
        cardsRepositoryProvider.overrideWithValue(_NullCardsRepository()),
      ],
    );
    addTearDown(container.dispose);

    // Materialize the owner widgets the editor rows read, then seed the editor.
    await container.read(ownerProfileWidgetsProvider.future);
    container.read(profileCompositionProvider.notifier).startComposing(const [
      _rank,
      _main,
    ]);

    await tester.pumpWidget(_harness(container));
    await tester.pumpAndSettle();

    // Rank now supports both sizes → ⇆ toggle present, like Main.
    expect(find.byKey(const Key('compositionSizeToggle_r')), findsOneWidget);
    expect(find.byKey(const Key('compositionSizeToggle_m')), findsOneWidget);

    // The dual-size Rank bootstraps as a full row.
    expect(container.read(profileCompositionProvider).working, const [
      FullRow('r'),
      FullRow('m'),
    ]);
  });
}
