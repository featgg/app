import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/core.dart';
import '../domain/profile.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'personalization_archetype_cards.dart';
import 'personalization_hero_canvas.dart';
import 'personalization_theme_palette.dart';
import 'profile_owner_cards_provider.dart';
import 'public_profile_widgets_provider.dart';

/// The read-only personalization profile renderer (`docs/personalization/spec.md` §3/§9):
/// a fixed 600px center column over theme-derived background art, painting a
/// header, a conditional-fit hero, and the `profile.layout` rows in order
/// through the profile's theme palette. Every color routes through
/// [PersonalizationTheme], so the palette chosen for this profile re-tints
/// everything without touching a card.
class PersonalizationProfileView extends ConsumerWidget {
  const PersonalizationProfileView({
    super.key,
    required this.profile,
    required this.userId,
    this.cardSource,
    this.widgetsProvider,
    this.rowsBuilder,
    this.bottomInset = 0,
  });

  /// Carries the layout and the theme that selects this view's palette.
  final Profile profile;

  /// Resolves this profile's public widgets and cards.
  final String userId;

  /// Where each platform's card resolves from. Null → the owner's own card; the
  /// router injects the public source for the visitor render.
  final CardSource? cardSource;

  /// Which widgets read backs the rows. Null → the visitor's public read; the
  /// owner passes their own widgets read.
  final ProviderListenable<AsyncValue<List<ProfileWidget>>>? widgetsProvider;

  /// Builds the rows region given the resolved column width. Null → the
  /// read-only rows; the owner injects the editor rows while editing.
  final Widget Function(BuildContext context, double columnWidth)? rowsBuilder;

  /// Extra bottom padding reserved inside the scroll content so a floating
  /// overlay (the owner's composition control bar) never hides the last card at
  /// maximum scroll. Zero for the visitor render, which has no overlay.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PersonalizationTheme(
      palette: paletteForTheme(profile.theme),
      // Builder so descendants can read the palette we just installed.
      child: Builder(
        builder: (context) {
          final palette = PersonalizationTheme.of(context);
          return ColoredBox(
            color: palette.bg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _BackgroundArt(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final outerWidth = math.min(
                      PersonalizationLayout.columnMaxWidth,
                      constraints.maxWidth,
                    );
                    final columnWidth =
                        outerWidth -
                        2 * PersonalizationLayout.columnSidePadding;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: PersonalizationLayout.columnMaxWidth,
                            ),
                            child: Padding(
                              // Reserve extra bottom room for a floating overlay
                              // (the owner control bar); zero for the visitor.
                              padding: EdgeInsets.fromLTRB(
                                PersonalizationLayout.columnSidePadding,
                                AppSpacing.lg,
                                PersonalizationLayout.columnSidePadding,
                                AppSpacing.lg + bottomInset,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _Header(profile: profile),
                                  const SizedBox(
                                    height: PersonalizationLayout.rowGap,
                                  ),
                                  PersonalizationHeroCanvas(
                                    word: _heroWord(profile),
                                    columnWidth: columnWidth,
                                  ),
                                  const SizedBox(
                                    height: PersonalizationLayout.rowGap,
                                  ),
                                  rowsBuilder != null
                                      ? rowsBuilder!(context, columnWidth)
                                      : _LayoutRows(
                                          layout: profile.layout,
                                          userId: userId,
                                          cardSource: cardSource,
                                          memberSince: profile.createdAt,
                                          widgetsProvider: widgetsProvider,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The hero word: the display name, falling back to the handle when it is empty.
String _heroWord(Profile profile) =>
    profile.displayName.isNotEmpty ? profile.displayName : profile.username;

/// Theme-derived background art (spec §3): two corner glows over the base, so
/// the desktop side space around the fixed column is never bare. Painted from
/// tokens — no bundled asset, keeping the public repo binary-free.
class _BackgroundArt extends StatelessWidget {
  const _BackgroundArt();

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: palette.bg),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              colors: [palette.artB, PersonalizationArtColors.transparent],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomRight,
              colors: [palette.artB, PersonalizationArtColors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

/// The profile header (spec §4): avatar + identity, capped at [headerMaxHeight]
/// so header + full hero fit the first paint.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bio = profile.bio;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: PersonalizationLayout.headerMaxHeight,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(
            color: palette.line,
            width: PersonalizationLayout.borderWidth,
          ),
          borderRadius: BorderRadius.circular(palette.radius),
        ),
        child: Row(
          children: [
            _AvatarMonogram(word: _heroWord(profile), palette: palette),
            const SizedBox(width: PersonalizationLayout.rowGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(color: palette.text),
                  ),
                  Text(
                    l10n.profileHandle(profile.username),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A monogram avatar (mockup): a token-gradient rounded square with the first
/// letter, so the header needs no network image.
class _AvatarMonogram extends StatelessWidget {
  const _AvatarMonogram({required this.word, required this.palette});

  final String word;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = word.isEmpty ? '?' : word.substring(0, 1).toUpperCase();

    return Container(
      width: PersonalizationLayout.avatarSize,
      height: PersonalizationLayout.avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.artA, palette.artC]),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.accent, width: AppSpacing.hairline),
      ),
      child: Text(
        initial,
        style: textTheme.headlineSmall?.copyWith(
          color: PersonalizationArtColors.onArt,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

/// Renders `profile.layout` in order (spec §9): each [FullRow] is one full card;
/// each [PairRow] is two half cards, or a single centered orphan when one slot
/// is null/unresolved. A row never inspects another row — no auto re-flow.
class _LayoutRows extends ConsumerWidget {
  const _LayoutRows({
    required this.layout,
    required this.userId,
    required this.cardSource,
    this.memberSince,
    this.widgetsProvider,
  });

  final List<ProfileLayoutRow> layout;
  final String userId;
  final CardSource? cardSource;

  /// Profile creation date, forwarded to the Identity card's footer.
  final DateTime? memberSince;

  /// Which widgets read backs the rows; null → the visitor's public read.
  final ProviderListenable<AsyncValue<List<ProfileWidget>>>? widgetsProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = widgetsProvider ?? publicProfileWidgetsProvider(userId);
    final widgetsAsync = ref.watch(provider);

    return AsyncValueWidget<List<ProfileWidget>>(
      value: widgetsAsync,
      // Both the default and injected reads are refreshable providers; guard the
      // generic listenable type and invalidate the concrete one on retry.
      onRetry: () {
        if (provider is ProviderOrFamily) {
          ref.invalidate(provider as ProviderOrFamily);
        }
      },
      data: (widgets) {
        // A disabled card is dropped from the read render: a full row with a
        // disabled card is omitted; a pair with one disabled side centers the
        // other.
        final byId = {
          for (final w in widgets)
            if (w.isEnabled) w.id: w,
        };
        final rows = <Widget>[];
        for (final row in layout) {
          final built = _buildRow(row, byId);
          if (built == null) continue;
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: PersonalizationLayout.rowGap));
          }
          rows.add(built);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  /// Builds one row, or null when nothing in it resolves (the row is omitted).
  Widget? _buildRow(ProfileLayoutRow row, Map<String, ProfileWidget> byId) {
    switch (row) {
      case FullRow(:final cardId):
        return _card(byId[cardId], ProfileCardSize.full);
      case PairRow(:final left, :final right):
        final leftCard = _card(byId[left], ProfileCardSize.half);
        final rightCard = _card(byId[right], ProfileCardSize.half);
        if (leftCard == null && rightCard == null) return null;
        return personalizationPairFrame(left: leftCard, right: rightCard);
    }
  }

  /// Builds the archetype card for [w] at [size], or null when the widget id did
  /// not resolve to a placed, enabled widget (deleted/hidden).
  Widget? _card(ProfileWidget? w, ProfileCardSize size) => w == null
      ? null
      : personalizationCardFor(
          w,
          size: size,
          cardSource: cardSource,
          memberSince: memberSince,
        );
}
