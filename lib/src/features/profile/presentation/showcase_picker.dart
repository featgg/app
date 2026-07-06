import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';
import 'collection_picker.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_widgets_controller.dart';

/// Opens the visual add-card picker as a modal bottom sheet: the connected
/// Steam account's library-showcase games as art tiles. Tapping a tile adds a
/// showcase widget for that game at [existing]'s next position (max+1, the same
/// rule the other adds use) through the host-observed controller and closes.
///
/// Steam-first this slice: `personalization.md` binds a showcase to a non-null
/// platform and client rendering is Steam-only, so a non-Steam showcase would
/// render unavailable — the tile source is the owner's Steam card.
Future<void> showShowcasePicker(
  BuildContext context, {
  required List<ProfileWidget> existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShowcasePickerSheet(existing: existing),
);

/// Showcase text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light
/// theme needs the inverse role. Mirrors the showcase card view.
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

/// The three add-card modes the sheet toggles between: a single-game showcase
/// (default), a multi-game collection, or a whole-library game collector.
enum _AddCardMode { showcase, collection, collector }

class _ShowcasePickerSheet extends ConsumerStatefulWidget {
  const _ShowcasePickerSheet({required this.existing});

  final List<ProfileWidget> existing;

  @override
  ConsumerState<_ShowcasePickerSheet> createState() =>
      _ShowcasePickerSheetState();
}

class _ShowcasePickerSheetState extends ConsumerState<_ShowcasePickerSheet> {
  _AddCardMode _mode = _AddCardMode.showcase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final existing = widget.existing;

    // Append after the current max position to avoid a foreseeable unique
    // collision; the backend constraint stays authoritative.
    final nextPosition = existing.isEmpty
        ? 0
        : existing.map((w) => w.position).reduce((a, b) => a > b ? a : b) + 1;
    // Steam games already placed as a showcase, keyed by the stored game ref, so
    // the picker never offers a game that is already on the profile.
    final alreadyShowcased = {
      for (final w in existing)
        if (w.kind == ProfileWidgetKind.showcase &&
            w.platform == Platform.steam)
          w.showcaseSelection.gameRef,
    };
    // A game collector is platform-bound (Steam) and carries no game selection,
    // so at most one Steam collector belongs on the profile; the picker offers
    // Add only when none is placed yet.
    final alreadyHasCollector = existing.any(
      (w) =>
          w.kind == ProfileWidgetKind.gameCollector &&
          w.platform == Platform.steam,
    );

    final cardState = ref.watch(ownerCardProvider(Platform.steam));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeToggle(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: AsyncValueWidget<GameCard?>(
                value: cardState,
                onRetry: () =>
                    ref.invalidate(ownerCardProvider(Platform.steam)),
                data: (card) {
                  final data = card?.data;
                  final games = data is SteamCardData
                      ? data.libraryShowcase
                      : const <LibraryShowcaseEntry>[];
                  return switch (_mode) {
                    _AddCardMode.showcase => _showcaseBody(
                      l10n,
                      textTheme,
                      games,
                      nextPosition,
                      alreadyShowcased,
                    ),
                    _AddCardMode.collection => CollectionPickerBody(
                      games: games,
                      nextPosition: nextPosition,
                    ),
                    _AddCardMode.collector => _collectorBody(
                      l10n,
                      textTheme,
                      nextPosition,
                      alreadyHasCollector,
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _showcaseBody(
    AppLocalizations l10n,
    TextTheme textTheme,
    List<LibraryShowcaseEntry> games,
    int nextPosition,
    Set<String> alreadyShowcased,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.showcasePickerTitle,
          key: const Key('showcasePickerTitle'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (games.isEmpty)
          Text(
            l10n.showcasePickerEmpty,
            key: const Key('showcasePickerEmpty'),
            style: textTheme.bodyMedium,
          )
        else
          _tilesOrAllAdded(
            l10n,
            textTheme,
            games,
            nextPosition,
            alreadyShowcased,
          ),
      ],
    );
  }

  /// The Collector mode: a whole-library card bound to Steam. There is no game
  /// to pick, so the body is a hint plus an Add action — or the already-added
  /// state (no Add) when a Steam collector is already on the profile.
  Widget _collectorBody(
    AppLocalizations l10n,
    TextTheme textTheme,
    int nextPosition,
    bool alreadyHasCollector,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gameCollectorPickerTitle,
          key: const Key('gameCollectorPickerTitle'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (alreadyHasCollector)
          Text(
            l10n.gameCollectorPickerAlreadyAdded,
            key: const Key('gameCollectorPickerAllAdded'),
            style: textTheme.bodyMedium,
          )
        else ...[
          Text(l10n.gameCollectorPickerHint, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('gameCollectorPickerAddButton'),
            onPressed: () {
              ref
                  .read(profileWidgetsControllerProvider.notifier)
                  .addGameCollector(
                    platform: Platform.steam,
                    position: nextPosition,
                    size: ProfileWidgetSize.small,
                  );
              Navigator.of(context).pop();
            },
            child: Text(l10n.gameCollectorPickerAdd),
          ),
        ],
      ],
    );
  }

  Widget _tilesOrAllAdded(
    AppLocalizations l10n,
    TextTheme textTheme,
    List<LibraryShowcaseEntry> games,
    int nextPosition,
    Set<String> alreadyShowcased,
  ) {
    final addable = [
      for (final game in games)
        if (!alreadyShowcased.contains(game.appId.toString())) game,
    ];
    if (addable.isEmpty) {
      return Text(
        l10n.showcasePickerAllAdded,
        key: const Key('showcasePickerAllAdded'),
        style: textTheme.bodyMedium,
      );
    }

    // Two columns, mobile-first: derive the tile width from the sheet's own
    // constraints rather than querying the screen, so the layout stays local.
    return Flexible(
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final game in addable)
                  SizedBox(
                    width: tileWidth,
                    child: _GameTile(entry: game, nextPosition: nextPosition),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The mode toggle at the top of the add-card sheet: Game (a single-game
/// showcase, the default), Collection (a multi-game collection), or Collector (a
/// whole-library game collector).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _AddCardMode mode;
  final ValueChanged<_AddCardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<_AddCardMode>(
      key: const Key('addCardModeToggle'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: _AddCardMode.showcase,
          label: Text(l10n.addCardModeShowcase),
        ),
        ButtonSegment(
          value: _AddCardMode.collection,
          label: Text(l10n.addCardModeCollection),
        ),
        ButtonSegment(
          value: _AddCardMode.collector,
          label: Text(l10n.addCardModeCollector),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// One library-showcase game as a square art tile: the real art behind a bottom
/// scrim with the uppercased title. A null/erroring art url degrades to a
/// neutral surface (never a broken-image glyph). Tapping it adds a small
/// showcase widget for the game and closes the sheet.
class _GameTile extends ConsumerWidget {
  const _GameTile({required this.entry, required this.nextPosition});

  final LibraryShowcaseEntry entry;
  final int nextPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final surface = colorScheme.surfaceContainerHighest;
    final url = entry.heroImage;

    return GestureDetector(
      key: Key('showcasePickerTile_${entry.appId}'),
      onTap: () {
        ref
            .read(profileWidgetsControllerProvider.notifier)
            .addShowcase(
              platform: Platform.steam,
              selection: ShowcaseSelection(gameRef: entry.appId.toString()),
              position: nextPosition,
              size: ProfileWidgetSize.small,
            );
        Navigator.of(context).pop();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                ColoredBox(color: surface)
              else
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: surface),
                  errorWidget: (_, _, _) => ColoredBox(color: surface),
                ),
              const _TileScrim(),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Text(
                  entry.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: _onArtColor(colorScheme),
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-anchored scrim over the art for title legibility. Mirrors the
/// showcase card view's fade.
class _TileScrim extends StatelessWidget {
  const _TileScrim();

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [scrim.withValues(alpha: 0.55), scrim.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
