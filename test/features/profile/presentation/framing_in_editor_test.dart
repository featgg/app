import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/art_framing.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_providers.dart';
import 'package:featgg/src/features/profile/domain/profile_widgets_repository.dart';
import 'package:featgg/src/features/profile/presentation/art_framing_control.dart';
import 'package:featgg/src/features/profile/presentation/composition_editor_rows.dart';
import 'package:featgg/src/features/profile/presentation/profile_composition_controller.dart';
import 'package:featgg/src/features/profile/presentation/profile_widgets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Framing inside the editor the owner actually uses, rather than a card
/// mounted on its own.
///
/// The card's own suite mounts the shell straight into a list, which leaves out
/// everything the editor stacks over a card — the drop targets that cover it,
/// the handle, the size toggle — and the page it all scrolls inside. A gesture
/// that has to win an arena is decided by exactly that surrounding structure,
/// so it is the only place a claim about the drag can be trusted.
const _artUrl = 'https://cdn.test/hero-1600x900.jpg';

Future<void> _seedArt(WidgetTester tester) async {
  await tester.runAsync(() async {
    const width = 1600;
    const height = 900;
    final pixels = Uint8List(width * height * 4)
      ..fillRange(0, width * height * 4, 0xFF);
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    PaintingBinding.instance.imageCache.putIfAbsent(
      CachedNetworkImageProvider(_artUrl),
      () => OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: frame.image)),
      ),
    );
  });
}

final class _FakeWidgetsRepository implements ProfileWidgetsRepository {
  _FakeWidgetsRepository(this.widgets);

  final List<ProfileWidget> widgets;
  final List<ArtFraming> written = [];

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets() async =>
      right(widgets);

  @override
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  ) async => right(widgets);

  @override
  Future<Either<Failure, Unit>> setArtFraming(
    ProfileWidget widget,
    ArtFraming framing,
  ) async {
    written.add(framing);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A Steam card carrying real art, so the art widget resolves a picture the
/// frame genuinely crops.
final class _ArtCardsRepository implements CardsRepository {
  GameCard? _card(Platform platform) => platform == Platform.steam
      ? GameCard(
          schemaVersion: 1,
          platform: Platform.steam,
          title: 'Nico',
          subtitle: null,
          iconImage: null,
          heroImage: _artUrl,
          profileUrl: null,
          stats: const [],
          lastUpdated: DateTime.utc(2026),
        )
      : null;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(_card(platform));

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(_card(platform));
}

const _art = ProfileWidget(
  id: 'a',
  kind: ProfileWidgetKind.art,
  platform: null,
  position: 0,
  isEnabled: true,
);

const _profile = Profile(
  id: 'owner-1',
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: null,
  bio: null,
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
);

/// The editor as it ships: inside the page's own scroll view, with that view's
/// physics wired to the framing mode exactly as the profile wires them.
///
/// The wiring is the point. A drag on a card and a scroll of the page are the
/// same gesture, and on a device the page wins the contest — so the page has to
/// step out while a picture is being moved, and a harness that scrolls freely
/// cannot tell whether it does.
class _Page extends ConsumerWidget {
  const _Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final framing = ref.watch(
      profileCompositionProvider.select((s) => s.framingId),
    );
    return SingleChildScrollView(
      physics: framing != null ? const NeverScrollableScrollPhysics() : null,
      child: const CompositionEditorRows(columnWidth: 360),
    );
  }
}

Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PersonalizationTheme(
        palette: PersonalizationPalette.crimson,
        child: const _Page(),
      ),
    ),
  ),
);

Future<ProviderContainer> _openEditor(WidgetTester tester) async {
  await _seedArt(tester);
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      profileWidgetsRepositoryProvider.overrideWithValue(
        _FakeWidgetsRepository(const [_art]),
      ),
      cardsRepositoryProvider.overrideWithValue(_ArtCardsRepository()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(ownerProfileWidgetsProvider.future);
  container.read(profileCompositionProvider.notifier).startEditing(
    _profile,
    const [_art],
  );
  await tester.pumpWidget(_harness(container));
  await tester.pumpAndSettle();
  return container;
}

/// How far the page has scrolled — the editor's own surrounding scroll view.
double _scrolled(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

Future<void> _swipe(WidgetTester tester, Offset total, {int steps = 20}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(CachedNetworkImage).first),
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(total / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the editor offers the mark on a card whose art is cropped', (
    tester,
  ) async {
    await _openEditor(tester);

    expect(find.byType(ArtFramingBadge), findsOneWidget);
  });

  testWidgets('tapping the mark enters framing mode', (tester) async {
    await _openEditor(tester);

    await tester.tap(find.byType(ArtFramingBadge));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('in the mode, a drag on the card moves the picture', (
    tester,
  ) async {
    // The claim the smoke says is false on a device: the drop targets the
    // editor stacks over every card, and the page they scroll inside, are both
    // absent from the card's own suite.
    final container = await _openEditor(tester);
    await tester.tap(find.byType(ArtFramingBadge));
    await tester.pump();

    await _swipe(tester, const Offset(-80, 0));

    expect(
      container.read(profileCompositionProvider).framings['a'],
      isNotNull,
      reason: 'the drag never reached the picture',
    );
  });

  testWidgets('in the mode, the page does not scroll under the drag', (
    tester,
  ) async {
    await _openEditor(tester);
    await tester.tap(find.byType(ArtFramingBadge));
    await tester.pump();

    await _swipe(tester, const Offset(0, -120));

    expect(_scrolled(tester), 0, reason: 'the page moved under the drag');
  });

  testWidgets('outside the mode, a swipe over the card still scrolls', (
    tester,
  ) async {
    await _openEditor(tester);

    await _swipe(tester, const Offset(0, -120));

    expect(_scrolled(tester), greaterThan(0));
  });
}
