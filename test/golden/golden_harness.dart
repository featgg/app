import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:featgg/src/core/error/failure.dart';
import 'package:featgg/src/core/l10n/generated/app_localizations.dart';
import 'package:featgg/src/core/theme/app_theme.dart';
import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/connections/domain/cards_repository.dart';
import 'package:featgg/src/features/connections/domain/connection.dart';
import 'package:featgg/src/features/connections/domain/connections_providers.dart';
import 'package:featgg/src/features/connections/domain/game_card.dart';
import 'package:featgg/src/features/profile/domain/art_selection.dart';
import 'package:featgg/src/features/profile/domain/collection_selection.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/domain/profile_layout.dart';
import 'package:featgg/src/features/profile/domain/profile_widget.dart';
import 'package:featgg/src/features/profile/domain/showcase_selection.dart';
import 'package:featgg/src/features/profile/presentation/personalization_profile_view.dart';
import 'package:featgg/src/features/profile/presentation/profile_owner_cards_provider.dart';
import 'package:featgg/src/features/profile/presentation/public_owner_cards_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// The family the committed test font registers under, applied explicitly by
/// [goldenTheme] so a reference never depends on the host platform's default.
const goldenFontFamily = 'Roboto';

/// Tag carried by every reference-image test. Local runs exclude it: references
/// are rendered by CI on Linux, and no two platforms rasterise identically.
const goldenTag = 'golden';

/// Edge length of the fixture art bitmap. Tiny on purpose — the fill is solid,
/// so scaling it to any box interpolates nothing and the source size never
/// reaches a reference image.
const kGoldenArtEdge = 8;

/// The boundary every golden captures.
const goldenSubjectKey = Key('goldenSubject');

/// Fixture art urls. The host is deliberately unroutable — nothing here ever
/// performs a request; the bytes come from [seedGoldenArt].
const goldenArtUrlA = 'https://cdn.test/golden-art-a.jpg';
const goldenArtUrlB = 'https://cdn.test/golden-art-b.jpg';

/// Two neutral greys, chosen because no curated palette contains them: a human
/// reviewing a reference can tell fixture art from designed art at a glance.
const goldenArtColorA = Color(0xFFB0B0B0);
const goldenArtColorB = Color(0xFF707070);

/// Both fixture urls, for a card that resolves art on every slot.
const goldenArt = <String, Color>{
  goldenArtUrlA: goldenArtColorA,
  goldenArtUrlB: goldenArtColorB,
};

/// Widths a card really gets in the profile column at the narrowest supported
/// width. Derived from the layout tokens, so a token edit moves the references
/// rather than silently invalidating them.
const goldenNarrowViewport = PersonalizationLayout.columnMinWidth;
const goldenFullWidth =
    goldenNarrowViewport - 2 * PersonalizationLayout.columnSidePadding;
const goldenHalfWidth = (goldenFullWidth - PersonalizationLayout.rowGap) / 2;

/// The other end of the column range: past this the column stops growing, so a
/// second whole-profile reference here brackets every width the app ships.
const goldenWideViewport = PersonalizationLayout.columnMaxWidth;

/// Viewport a single-card golden renders into. Generously larger than any card
/// in the catalog, so the subject is never constrained by it — the subject's own
/// [SizedBox] fixes the only dimension that matters.
const _cardViewportSize = Size(900, 1800);

/// The signed-in-user id every fixture profile uses.
const goldenUserId = 'golden-owner';

/// Registers the committed test font so goldens compare real glyphs. Under
/// `flutter test` every glyph is otherwise drawn as a filled box of equal
/// advance, which would make a reference over number-led cards worthless. The
/// file is never declared as an app asset and never reaches a build.
Future<void> loadGoldenFonts() async {
  final file = _packageFile('test/golden/fonts/Roboto-Regular.ttf');
  if (!file.existsSync()) {
    throw StateError(
      'Golden test font not found at ${file.path}. '
      'See test/golden/fonts/README.md for its provenance.',
    );
  }
  final loader = FontLoader(goldenFontFamily);
  final bytes = await file.readAsBytes();
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
  await _loadBundledFont(_iconFontFamily);
}

/// Family the bundled icon glyphs come from. An unregistered icon font
/// rasterises every codepoint as the same blank box, so any reference covering a
/// bundled icon would freeze that blank rather than the glyph.
const _iconFontFamily = 'MaterialIcons';

/// Registers a family the asset bundle already carries. `flutter test` builds
/// the bundle the app ships, so this is the same file the device draws from —
/// unlike the text font, nothing is committed for it.
Future<void> _loadBundledFont(String family) async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  final entry = manifest.cast<Map<String, dynamic>>().firstWhere(
    (candidate) => candidate['family'] == family,
    orElse: () => throw StateError(
      'No "$family" family in FontManifest.json. Icon glyphs would render as '
      'blank boxes in every reference image.',
    ),
  );
  final loader = FontLoader(family);
  for (final asset
      in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    loader.addFont(rootBundle.load(asset['asset'] as String));
  }
  await loader.load();
}

/// Resolves [relativePath] against the package root. The test runner's working
/// directory is not guaranteed to be the repo root, so a plain `File('test/…')`
/// is not safe here.
File _packageFile(String relativePath) {
  var directory = Directory.current;
  while (true) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      return File('${directory.path}/$relativePath');
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'No pubspec.yaml above ${Directory.current.path}; '
        'cannot resolve $relativePath.',
      );
    }
    directory = parent;
  }
}

/// The app's real theme with the deterministic family applied, so a golden
/// measures the shipped type scale rather than the harness's own.
ThemeData goldenTheme() {
  final base = AppTheme.light();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: goldenFontFamily),
  );
}

/// Installs a decoded, opaque fill for each url so a card that resolves art
/// renders it, instead of the placeholder every network fetch falls back to
/// under `flutter test`. Seeding the image cache short-circuits the resolve
/// before the package's own loader — which cannot complete in a test, having no
/// temporary directory and no cache database — ever runs.
Future<void> seedGoldenArt(WidgetTester tester, Map<String, Color> art) async {
  if (art.isEmpty) return;
  await tester.runAsync(() async {
    for (final entry in art.entries) {
      final image = await _solidImage(entry.value);
      PaintingBinding.instance.imageCache.putIfAbsent(
        CachedNetworkImageProvider(entry.key),
        () => OneFrameImageStreamCompleter(
          Future<ImageInfo>.value(ImageInfo(image: image)),
        ),
      );
    }
  });
}

/// A decoded [edge]×[edge] image of a single flat [color].
Future<ui.Image> _solidImage(Color color, {int edge = kGoldenArtEdge}) async {
  final red = (color.r * 255).round();
  final green = (color.g * 255).round();
  final blue = (color.b * 255).round();
  final alpha = (color.a * 255).round();
  final pixels = Uint8List(edge * edge * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = red;
    pixels[i + 1] = green;
    pixels[i + 2] = blue;
    pixels[i + 3] = alpha;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: edge,
    height: edge,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// A golden test. Tagged so local runs exclude it.
void goldenTest(String description, WidgetTesterCallback body) =>
    testWidgets(description, body, tags: goldenTag);

/// Renders one archetype [card] at [width] over the profile background, ready to
/// be captured through [goldenSubjectKey]. The card surface is translucent, so
/// without the background behind it the composite is not what ships.
Future<void> pumpCardGolden(
  WidgetTester tester, {
  required Widget card,
  required double width,
  Map<Platform, GameCard?> cards = const {},
  Map<String, Color> art = const {},
  PersonalizationPalette palette = PersonalizationPalette.crimson,
}) async {
  await seedGoldenArt(tester, art);
  _fixViewport(tester, _cardViewportSize);

  await tester.pumpWidget(
    _goldenApp(
      cards: cards,
      child: Center(
        child: RepaintBoundary(
          key: goldenSubjectKey,
          child: ColoredBox(
            color: palette.bg,
            child: SizedBox(
              width: width,
              child: PersonalizationTheme(palette: palette, child: card),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Renders a whole profile at [width]×[height]. [widgets] is injected
/// synchronously so the rows never pass through a loading state — a live
/// progress indicator would hang `pumpAndSettle` rather than fail fast.
Future<void> pumpProfileGolden(
  WidgetTester tester, {
  required double width,
  required double height,
  required Profile profile,
  required List<ProfileWidget> widgets,
  Map<Platform, GameCard?> cards = const {},
  Map<String, Color> art = const {},
}) async {
  await seedGoldenArt(tester, art);
  _fixViewport(tester, Size(width, height));

  final widgetsProvider = Provider<AsyncValue<List<ProfileWidget>>>(
    (ref) => AsyncData(widgets),
  );

  await tester.pumpWidget(
    _goldenApp(
      cards: cards,
      child: RepaintBoundary(
        key: goldenSubjectKey,
        child: SizedBox(
          width: width,
          height: height,
          child: PersonalizationProfileView(
            profile: profile,
            userId: goldenUserId,
            cardSource: goldenCardSource,
            widgetsProvider: widgetsProvider,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How far the profile column can still scroll. Zero proves the reference
/// captured the whole composition rather than a clipped prefix.
double profileScrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable))
    .position
    .maxScrollExtent;

/// Pins the render surface to logical pixels so references are captured at
/// design size.
void _fixViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The app shell every golden renders inside: the shipped theme with the
/// deterministic family, a pinned locale so the host cannot change the render,
/// and the repository the public card source reads through.
Widget _goldenApp({
  required Widget child,
  required Map<Platform, GameCard?> cards,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      cardsRepositoryProvider.overrideWithValue(_PublicCardsRepository(cards)),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: goldenTheme(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

/// Resolves each platform's card from the injected public source, the shipped
/// visitor path.
CardSource get goldenCardSource =>
    (platform) => publicOwnerCardProvider(goldenUserId, platform);

/// Serves the injected cards on the public read; the owner read is never used by
/// a golden.
final class _PublicCardsRepository implements CardsRepository {
  _PublicCardsRepository(this._public);

  final Map<Platform, GameCard?> _public;

  @override
  Future<Either<Failure, GameCard?>> fetchMyCard(Platform platform) async =>
      right(null);

  @override
  Future<Either<Failure, GameCard?>> fetchPublicCard(
    String userId,
    Platform platform,
  ) async => right(_public[platform]);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A card envelope. Every field a golden depends on is explicit — nothing here
/// reads a clock or a random source.
GameCard goldenCard(
  Platform platform, {
  String title = 'golden-card',
  String? heroImage,
  List<CardStat> stats = const [],
  CardData? data,
}) => GameCard(
  schemaVersion: 1,
  platform: platform,
  title: title,
  subtitle: null,
  iconImage: null,
  heroImage: heroImage,
  profileUrl: null,
  stats: stats,
  lastUpdated: DateTime.utc(2026, 6, 1),
  data: data,
);

/// A placed, enabled widget of [kind].
ProfileWidget goldenWidget({
  required String id,
  required ProfileWidgetKind kind,
  Platform? platform,
  ShowcaseSelection showcaseSelection = ShowcaseSelection.empty,
  CollectionSelection collectionSelection = CollectionSelection.empty,
  ArtSelection artSelection = ArtSelection.empty,
}) => ProfileWidget(
  id: id,
  kind: kind,
  platform: platform,
  position: 0,
  isEnabled: true,
  size: ProfileWidgetSize.small,
  showcaseSelection: showcaseSelection,
  collectionSelection: collectionSelection,
  artSelection: artSelection,
);

/// A Steam library entry.
LibraryShowcaseEntry goldenLibraryEntry({
  required int appId,
  required String title,
  required num hours,
  String? heroImage,
}) => LibraryShowcaseEntry(
  appId: appId,
  title: title,
  hours: hours,
  heroImage: heroImage,
);

/// The profile every whole-profile golden renders. It carries an avatar so the
/// reference captures the shipped header rather than its monogram fallback.
Profile goldenProfile(List<ProfileLayoutRow> layout) => Profile(
  id: goldenUserId,
  username: 'nico',
  displayName: 'Nico',
  avatarUrl: goldenArtUrlA,
  bio: 'Chasing perfect runs and unreasonable backlogs.',
  theme: ProfileTheme.crimson,
  privacy: ProfilePrivacy.public,
  featuredPlatform: null,
  layout: layout,
  createdAt: DateTime.utc(2025, 3, 1),
);
