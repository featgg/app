import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import '../domain/showcase_selection.dart';
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

class _ShowcasePickerSheet extends ConsumerWidget {
  const _ShowcasePickerSheet({required this.existing});

  final List<ProfileWidget> existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

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

    final cardState = ref.watch(ownerCardProvider(Platform.steam));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AsyncValueWidget<GameCard?>(
          value: cardState,
          onRetry: () => ref.invalidate(ownerCardProvider(Platform.steam)),
          data: (card) => _content(
            context,
            ref,
            l10n,
            textTheme,
            card,
            nextPosition,
            alreadyShowcased,
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TextTheme textTheme,
    GameCard? card,
    int nextPosition,
    Set<String> alreadyShowcased,
  ) {
    final data = card?.data;
    final games = data is SteamCardData
        ? data.libraryShowcase
        : const <LibraryShowcaseEntry>[];

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
