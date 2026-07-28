import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../domain/profile.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'personalization_archetype_cards.dart';
import 'personalization_theme_palette.dart';
import 'profile_header.dart';
import 'profile_owner_cards_provider.dart';
import 'public_profile_widgets_provider.dart';

/// The read-only personalization profile renderer: a fixed 600px center column
/// over theme-derived background art, painting the header and the
/// `profile.layout` rows in order through the profile's theme palette. Every
/// color routes through [PersonalizationTheme], so the palette chosen for this
/// profile re-tints everything without touching a card.
class PersonalizationProfileView extends ConsumerWidget {
  const PersonalizationProfileView({
    super.key,
    required this.profile,
    required this.userId,
    this.cardSource,
    this.widgetsProvider,
    this.rowsBuilder,
    this.headerEditing,
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

  /// The header's edit affordances. Null → a header that is only read; the owner
  /// injects them while editing.
  final ProfileHeaderEditing? headerEditing;

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
                              padding: const EdgeInsets.fromLTRB(
                                PersonalizationLayout.columnSidePadding,
                                AppSpacing.lg,
                                PersonalizationLayout.columnSidePadding,
                                AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ProfileHeader(
                                    profile: profile,
                                    columnWidth: columnWidth,
                                    cardSource: cardSource,
                                    editing: headerEditing,
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
                                          headerPlatform:
                                              profile.headerPlatform,
                                          featuredPlatform:
                                              profile.featuredPlatform,
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

/// Theme-derived background art: two corner glows over the base, so
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

/// Renders `profile.layout` in order: each [FullRow] is one full card;
/// each [PairRow] is two half cards, or a single centered orphan when one slot
/// is null/unresolved. A row never inspects another row — no auto re-flow.
class _LayoutRows extends ConsumerWidget {
  const _LayoutRows({
    required this.layout,
    required this.userId,
    required this.cardSource,
    this.memberSince,
    this.headerPlatform,
    this.featuredPlatform,
    this.widgetsProvider,
  });

  final List<ProfileLayoutRow> layout;
  final String userId;
  final CardSource? cardSource;

  /// Profile creation date, forwarded to the Identity card's footer.
  final DateTime? memberSince;

  /// The profile's art preferences, forwarded to the Art card so an unpointed
  /// card resolves through the cover's full chain.
  final Platform? headerPlatform;
  final Platform? featuredPlatform;

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
        // A profile whose owner never arranged one still shows its cards, in
        // the order the editor would seed — arranging is a refinement, not a
        // precondition for being rendered.
        final effective = layout.isEmpty ? defaultLayoutFor(widgets) : layout;
        final rows = <Widget>[];
        for (final row in effective) {
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
          headerPlatform: headerPlatform,
          featuredPlatform: featuredPlatform,
        );
}
