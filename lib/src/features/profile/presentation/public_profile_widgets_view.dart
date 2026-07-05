import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/game_card.dart';
import '../domain/profile_widget.dart';
import 'collection_card_view.dart';
import 'composed_card_view.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_screen.dart';
import 'profile_widgets_layout.dart';
import 'public_owner_cards_provider.dart';
import 'public_profile_widgets_provider.dart';
import 'showcase_card_view.dart';
import 'template_card_view.dart';

/// Read-only visitor render of a public profile's `profile_widgets` arrangement.
/// Reads [publicProfileWidgetsProvider], filters to enabled widgets, sorts by
/// position, and renders each widget through the SAME card views the owner uses.
///
/// The card views (template/composed) resolve each row through an injected
/// [CardSource]; this view passes a PUBLIC source ([publicOwnerCardProvider] for
/// [userId]) so a visitor sees the owner's public cards through the SAME views,
/// while the owner path keeps the default (`ownerCardProvider`) untouched. A
/// platform widget resolves its card from the same public source.
///
/// Read-only: no options menu, no reorder, no add affordance.
class PublicProfileWidgetsView extends ConsumerWidget {
  const PublicProfileWidgetsView({
    super.key,
    required this.userId,
    required this.cardBuilder,
  });

  final String userId;
  final OwnerCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgetsState = ref.watch(publicProfileWidgetsProvider(userId));

    return AsyncValueWidget<List<ProfileWidget>>(
      value: widgetsState,
      onRetry: () => ref.invalidate(publicProfileWidgetsProvider(userId)),
      loading: const ProfileCardsSkeleton(),
      data: (widgets) {
        final visible = [
          for (final w in widgets)
            if (w.isEnabled) w,
        ]..sort((a, b) => a.position.compareTo(b.position));

        if (visible.isEmpty) return const _EmptyState();

        return ProfileWidgetsFlow(
          key: const Key('publicProfileWidgetsView'),
          tiles: [
            for (var i = 0; i < visible.length; i++)
              ProfileWidgetTile(
                widget: visible[i],
                child: _VisitorTile(
                  key: Key('publicWidgetTile_${visible[i].id}'),
                  userId: userId,
                  widget: visible[i],
                  cardBuilder: cardBuilder,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Renders a single visitor widget by kind, with no owner affordance. Template
/// and composed widgets render via their own views, passed a public [CardSource];
/// a platform widget resolves its card from `publicOwnerCardProvider` directly,
/// omitting a null card so a card-less platform contributes nothing visible.
class _VisitorTile extends ConsumerWidget {
  const _VisitorTile({
    super.key,
    required this.userId,
    required this.widget,
    required this.cardBuilder,
  });

  final String userId;
  final ProfileWidget widget;
  final OwnerCardBuilder cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The card views resolve each row through the PUBLIC source for this
    // profile, so a visitor sees the owner's public cards through the same view.
    CardSource publicSource() =>
        (platform) => publicOwnerCardProvider(userId, platform);

    if (widget.kind == ProfileWidgetKind.template) {
      return ClipRect(
        child: TemplateCardView(
          widget: widget,
          cardSource: publicSource(),
          // A visitor never sees an empty card — omit it instead of the
          // owner-only "fill a slot" placeholder.
          showEmptyPlaceholder: false,
        ),
      );
    }
    if (widget.kind == ProfileWidgetKind.composed) {
      return ClipRect(
        child: ComposedCardView(
          widget: widget,
          cardSource: publicSource(),
          showEmptyPlaceholder: false,
        ),
      );
    }
    if (widget.kind == ProfileWidgetKind.showcase) {
      return ClipRect(
        child: ShowcaseCardView(
          widget: widget,
          cardSource: publicSource(),
          showEmptyPlaceholder: false,
        ),
      );
    }
    if (widget.kind == ProfileWidgetKind.collection) {
      return ClipRect(
        child: CollectionCardView(
          widget: widget,
          cardSource: publicSource(),
          showEmptyPlaceholder: false,
        ),
      );
    }

    final platform = widget.platform;
    final cardState = platform == null
        ? const AsyncData<GameCard?>(null)
        : ref.watch(publicOwnerCardProvider(userId, platform));
    return AsyncValueWidget<GameCard?>(
      value: cardState,
      onRetry: platform == null
          ? null
          : () => ref.invalidate(publicOwnerCardProvider(userId, platform)),
      // A card-less platform widget renders nothing for a visitor (no
      // owner-only placeholder-with-menu).
      data: (card) => card == null
          ? const SizedBox.shrink()
          : ClipRect(child: cardBuilder(card)),
    );
  }
}

/// Neutral empty state for a public profile with no enabled widget rows.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      l10n.publicProfileNoCards,
      key: const Key('publicProfileNoCards'),
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}
