import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/personalization_archetype_cards.dart';
import 'package:featgg/src/features/profile/presentation/personalization_profile_view.dart';
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const _userId = 'owner-1';

/// Returns a fixed set of widgets for both the public and owner reads; every
/// mutation is out of scope for the read-only render.
final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

  final List<ProfileWidget> widgets;

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// Layout: a full row, a pair, then an orphan pair (one slot null → centered).
const _profile = Profile(
  id: _userId,
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: [
    FullRow('a'),
    PairRow(left: 'b', right: 'c'),
    PairRow(left: 'd'),
  ],
);

// Platform-less kinds → the Fallback archetype, so the composition renders
// without any card-source dependency.
ProfileWidget _widget(
  String id,
  ProfileWidgetKind kind, {
  bool isEnabled = true,
}) => ProfileWidget(
  id: id,
  kind: kind,
  platform: null,
  position: 0,
  isEnabled: isEnabled,
  size: ProfileWidgetSize.small,
);

final _widgets = [
  _widget('a', ProfileWidgetKind.template),
  _widget('b', ProfileWidgetKind.composed),
  _widget('c', ProfileWidgetKind.dataMenu),
  _widget('d', ProfileWidgetKind.template),
];

Widget _harness({
  Profile profile = _profile,
  List<ProfileWidget>? widgets,
  ProviderListenable<AsyncValue<List<ProfileWidget>>>? widgetsProvider,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(widgets ?? _widgets),
      ),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: PersonalizationProfileView(
          profile: profile,
          userId: _userId,
          widgetsProvider: widgetsProvider,
        ),
      ),
    ),
  );
}

Future<void> _pumpAt(
  WidgetTester tester,
  double width, {
  double height = 2400,
  Profile profile = _profile,
  List<ProfileWidget>? widgets,
  ProviderListenable<AsyncValue<List<ProfileWidget>>>? widgetsProvider,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(
      profile: profile,
      widgets: widgets,
      widgetsProvider: widgetsProvider,
    ),
  );
  await tester.pumpAndSettle();
}

double _dy(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(personalizationCardKey(id))).dy;

double _dx(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(personalizationCardKey(id))).dx;

void main() {
  testWidgets('renders full, pair, and centered orphan rows in order', (
    tester,
  ) async {
    await _pumpAt(tester, 600);

    for (final id in ['a', 'b', 'c', 'd']) {
      expect(
        find.byKey(personalizationCardKey(id)),
        findsOneWidget,
        reason: 'card $id should render',
      );
    }

    // Full row above the pair above the orphan (spec §9 order).
    expect(_dy(tester, 'a'), lessThan(_dy(tester, 'b')));
    // The pair sits on one row and never stacks — same top, left before right.
    expect(_dy(tester, 'b'), moreOrLessEquals(_dy(tester, 'c'), epsilon: 0.5));
    expect(_dx(tester, 'b'), lessThan(_dx(tester, 'c')));
    expect(_dy(tester, 'c'), lessThan(_dy(tester, 'd')));

    // Orphan 'd' is a single centered half — narrower than the full row and
    // horizontally offset from the column's left edge.
    final orphanWidth = tester
        .getSize(find.byKey(personalizationCardKey('d')))
        .width;
    final fullWidth = tester
        .getSize(find.byKey(personalizationCardKey('a')))
        .width;
    expect(orphanWidth, lessThan(fullWidth));
    expect(_dx(tester, 'd'), greaterThan(_dx(tester, 'a')));
  });

  testWidgets('composition is identical at 390 and 2048 (same order)', (
    tester,
  ) async {
    // Only global scale may change; the ordered composition must not (spec §6).
    // Resize the same mounted tree rather than re-pumping, so the composition is
    // compared across widths without rebuilding the widget from scratch.
    await _pumpAt(tester, 390);
    expect(_dy(tester, 'a'), lessThan(_dy(tester, 'b')));
    expect(_dy(tester, 'b'), moreOrLessEquals(_dy(tester, 'c'), epsilon: 0.5));
    expect(_dx(tester, 'b'), lessThan(_dx(tester, 'c')));
    expect(_dy(tester, 'c'), lessThan(_dy(tester, 'd')));

    tester.view.physicalSize = const Size(2048, 2400);
    await tester.pumpAndSettle();
    expect(_dy(tester, 'a'), lessThan(_dy(tester, 'b')));
    expect(_dy(tester, 'b'), moreOrLessEquals(_dy(tester, 'c'), epsilon: 0.5));
    expect(_dx(tester, 'b'), lessThan(_dx(tester, 'c')));
    expect(_dy(tester, 'c'), lessThan(_dy(tester, 'd')));
  });

  testWidgets('no overflow at 320px and the pair never stacks', (tester) async {
    await _pumpAt(tester, 320);

    expect(tester.takeException(), isNull);
    // The pair halves stay side by side, not stacked.
    expect(_dy(tester, 'b'), moreOrLessEquals(_dy(tester, 'c'), epsilon: 0.5));
    expect(_dx(tester, 'b'), lessThan(_dx(tester, 'c')));
  });

  // The render tints from profile.theme, not a hardcoded default: a non-crimson
  // theme installs its own palette, and two themes install two palettes.
  // Each scenario pumps once — the InheritedWidget carries the palette a
  // single card would read.
  PersonalizationPalette installedPalette(WidgetTester tester) => tester
      .widget<PersonalizationTheme>(find.byType(PersonalizationTheme).first)
      .palette;

  testWidgets('installs a non-default theme palette (not hardcoded crimson)', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      600,
      profile: _profile.copyWith(theme: ProfileTheme.arcane),
    );

    expect(installedPalette(tester), paletteForTheme(ProfileTheme.arcane));
    expect(installedPalette(tester), isNot(PersonalizationPalette.crimson));
  });

  testWidgets('a different theme installs a different palette', (tester) async {
    await _pumpAt(
      tester,
      600,
      profile: _profile.copyWith(theme: ProfileTheme.chak),
    );

    expect(installedPalette(tester), paletteForTheme(ProfileTheme.chak));
    expect(
      paletteForTheme(ProfileTheme.chak),
      isNot(paletteForTheme(ProfileTheme.arcane)),
    );
  });

  testWidgets('a disabled card is hidden: its full row is omitted and a pair '
      'centers the other card', (tester) async {
    // 'b' is disabled → its full row disappears and the (a, b) pair collapses to
    // a centered 'a'.
    final widgets = [
      _widget('a', ProfileWidgetKind.template),
      _widget('b', ProfileWidgetKind.composed, isEnabled: false),
      _widget('c', ProfileWidgetKind.dataMenu),
    ];
    const profile = Profile(
      id: _userId,
      username: 'nico',
      displayName: 'Nico',
      avatarUrl: null,
      bio: null,
      theme: ProfileTheme.crimson,
      privacy: ProfilePrivacy.public,
      featuredPlatform: null,
      layout: [
        FullRow('b'),
        PairRow(left: 'a', right: 'b'),
        FullRow('c'),
      ],
    );

    await _pumpAt(tester, 600, profile: profile, widgets: widgets);

    // The disabled card never renders.
    expect(find.byKey(personalizationCardKey('b')), findsNothing);
    expect(find.byKey(personalizationCardKey('a')), findsOneWidget);
    expect(find.byKey(personalizationCardKey('c')), findsOneWidget);

    // The (a, b) pair collapsed to a centered orphan → 'a' is narrower than a
    // full-width row.
    final aWidth = tester
        .getSize(find.byKey(personalizationCardKey('a')))
        .width;
    final cWidth = tester
        .getSize(find.byKey(personalizationCardKey('c')))
        .width;
    expect(aWidth, lessThan(cWidth));
  });

  testWidgets('a pair row ends both cards on the same line whatever their '
      'natural heights differ by', (tester) async {
    // A full-only archetype dropped into a pair slot clamps to the full variant,
    // so its natural height differs from its dual-size partner's — the only case
    // where a pair's two cards would end on different lines.
    final widgets = [
      _widget('short', ProfileWidgetKind.completionist),
      _widget('tall', ProfileWidgetKind.template),
    ];
    const profile = Profile(
      id: _userId,
      username: 'nico',
      displayName: 'Nico',
      avatarUrl: null,
      bio: null,
      theme: ProfileTheme.crimson,
      privacy: ProfilePrivacy.public,
      featuredPlatform: null,
      layout: [PairRow(left: 'short', right: 'tall')],
    );

    await _pumpAt(tester, 600, profile: profile, widgets: widgets);

    final short = tester.getRect(find.byKey(personalizationCardKey('short')));
    final tall = tester.getRect(find.byKey(personalizationCardKey('tall')));
    expect(short.height, moreOrLessEquals(tall.height, epsilon: 0.5));
    expect(short.bottom, moreOrLessEquals(tall.bottom, epsilon: 0.5));
  });

  testWidgets('an injected owner widgetsProvider resolves the cards', (
    tester,
  ) async {
    await _pumpAt(tester, 600, widgetsProvider: ownerProfileWidgetsProvider);

    for (final id in ['a', 'b', 'c', 'd']) {
      expect(
        find.byKey(personalizationCardKey(id)),
        findsOneWidget,
        reason: 'card $id resolves through the owner widgets read',
      );
    }
  });
}
