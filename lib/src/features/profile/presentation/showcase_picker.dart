import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/completionist_value_resolver.dart';
import '../domain/game_collector_value_resolver.dart';
import '../domain/main_value_resolver.dart';
import '../domain/personal_best_value_resolver.dart';
import '../domain/profile_widget.dart';
import '../domain/rank_value_resolver.dart';
import '../domain/rarest_achievement_value_resolver.dart';
import '../domain/recent_value_resolver.dart';
import '../domain/showcase_selection.dart';
import 'collection_picker.dart';
import 'featured_platform_provider.dart';
import 'profile_owner_cards_provider.dart';
import 'profile_widgets_controller.dart';

/// Opens the add-card catalog as a modal bottom sheet: a flat, archetype-grouped
/// list of the cards the owner can add. Auto cards (Identity, Rank, Main,
/// Collector, Completionist) add in one tap; curated cards (Milestone, curated
/// Collection) push their picker as an in-sheet step. Every add lands at
/// [existing]'s next position (max+1, the same rule the other adds use).
///
/// The name is retained (the sheet no longer only picks showcases) to keep its
/// call sites and the acquire-race guardrail untouched.
Future<void> showShowcasePicker(
  BuildContext context, {
  required List<ProfileWidget> existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CatalogSheet(existing: existing),
);

/// The catalog universe: every platform some archetype can draw from. Unlinked
/// members are omitted per row and drive the "connect more" footer;
/// `minecraftHypixel` backs no archetype yet, so it is excluded and never nags.
final Set<Platform> _catalogUniverse = {
  Platform.steam,
  ...kRankPlatforms,
  ...kPersonalBestPlatforms,
  ...kMainPlatforms,
  ...kRecentPlatforms,
  ...kRarestAchievementPlatforms,
};

/// Showcase text sits on the dark art scrim in BOTH themes, so its neutral
/// color must always be light — dark theme's `onSurface` already is, light
/// theme needs the inverse role. Mirrors the showcase card view.
Color _onArtColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.onSurface
    : scheme.onInverseSurface;

/// The in-sheet step: the grouped catalog, or a curated picker reached from it.
/// Genuinely ephemeral visual state — it never outlives the sheet and has no
/// domain meaning — so `setState` is the sanctioned mechanism, and keeping one
/// modal route preserves the acquire rows' pop-guard semantics.
enum _Step { catalog, milestone, collection }

/// One line of the catalog: the row to draw, plus what the platform filter needs
/// to decide whether it belongs on screen. [platform] is null for the cards that
/// are no single platform's — Identity draws on every linked account and Art on
/// none — so filtering to a platform leaves them out.
typedef _Entry = ({String label, Platform? platform, Widget row});

class _CatalogSheet extends ConsumerStatefulWidget {
  const _CatalogSheet({required this.existing});

  final List<ProfileWidget> existing;

  @override
  ConsumerState<_CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends ConsumerState<_CatalogSheet> {
  _Step _step = _Step.catalog;

  /// The platform the catalog is narrowed to, or null for all of them. A second
  /// axis over the categories rather than a replacement for them: a fully
  /// connected owner reads one platform's cards without losing the grouping that
  /// tells them what each card answers.
  Platform? _platform;

  /// The row whose write is in flight, by its key, or null. Held here rather
  /// than in the row: a filter change can take the row off screen while the
  /// write is pending, and a lifecycle owned by the row would be disposed with
  /// it — leaving the sheet open and the card addable a second time.
  Key? _acquiring;

  @override
  Widget build(BuildContext context) {
    final nextPosition = _nextPosition(widget.existing);
    final connected = ref.watch(connectedPlatformsProvider);
    final linked = connected.value?.toSet() ?? const <Platform>{};
    // Only linked universe platforms are fetched — an unlinked platform is
    // never watched, so nothing is fetched for a card that cannot be offered.
    final cardStates = <Platform, AsyncValue<GameCard?>>{
      for (final platform in _catalogUniverse)
        if (linked.contains(platform))
          platform: ref.watch(ownerCardProvider(platform)),
    };

    // One scroll surface for the whole sheet, capped so short content still hugs
    // its own height and only tall content scrolls.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * AppSheet.maxHeightFraction,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: switch (_step) {
              _Step.catalog => AsyncValueWidget<List<Platform>>(
                value: connected,
                onRetry: () => ref.invalidate(connectedPlatformsProvider),
                data: (_) => _catalog(linked, cardStates, nextPosition),
              ),
              _Step.milestone => _milestoneBody(cardStates, nextPosition),
              _Step.collection => _collectionBody(cardStates, nextPosition),
            },
          ),
        ),
      ),
    );
  }

  Widget _catalog(
    Set<Platform> linked,
    Map<Platform, AsyncValue<GameCard?>> cardStates,
    int nextPosition,
  ) {
    // Deterministic load: one spinner while any linked card resolves, so rows
    // never flicker in one at a time.
    if (cardStates.values.any((state) => state.isLoading)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    // An errored or cross-wired card reads as absent data (non-blocking): a card
    // must belong to the platform it was fetched for to resolve for it.
    GameCard? cardFor(Platform platform) {
      final state = cardStates[platform];
      if (state == null || state.hasError) return null;
      final card = state.value;
      if (card == null || card.platform != platform) return null;
      return card;
    }

    final steamLinked = linked.contains(Platform.steam);
    final steamCard = steamLinked ? cardFor(Platform.steam) : null;
    final steamLibrary = _steamLibrary(steamCard);

    // Grouped by the question a card answers, never by archetype: the same
    // order drives a fresh composition's default order.
    final whoIAmRows = [_identityRow(l10n, linked, nextPosition)];
    final whatIPlayRows = <_Entry>[
      for (final platform in kMainPlatforms)
        if (linked.contains(platform))
          _kindRow(
            l10n: l10n,
            kind: ProfileWidgetKind.main,
            platform: platform,
            hasData: resolveMain(cardFor(platform)) != null,
            reason: l10n.addCatalogReasonMainNoData,
            nextPosition: nextPosition,
          ),
      for (final platform in kRecentPlatforms)
        if (linked.contains(platform))
          _recentRow(
            l10n,
            platform,
            resolveRecent(cardFor(platform)) != null,
            nextPosition,
          ),
    ];
    final howGoodIAmRows = <_Entry>[
      for (final platform in kRankPlatforms)
        if (linked.contains(platform))
          _kindRow(
            l10n: l10n,
            kind: ProfileWidgetKind.rank,
            platform: platform,
            hasData: resolveRank(cardFor(platform)) != null,
            reason: l10n.addCatalogReasonRankNoData,
            nextPosition: nextPosition,
          ),
      // Driven by the platform set, so a platform publishing no best-ever
      // figure gets no row at all rather than a disabled one.
      for (final platform in kPersonalBestPlatforms)
        if (linked.contains(platform))
          _personalBestRow(
            l10n,
            platform,
            resolvePersonalBest(cardFor(platform)) != null,
            nextPosition,
          ),
    ];
    // The Steam-derived rows render only when Steam is linked.
    final whatIAchievedRows = <_Entry>[
      if (steamLinked) ...[
        _milestoneRow(l10n, steamLibrary),
        _completionistRow(l10n, steamCard, nextPosition),
      ],
      // Driven by the platform set, so a platform publishing no achievement
      // rarity gets no row at all rather than a disabled one.
      for (final platform in kRarestAchievementPlatforms)
        if (linked.contains(platform))
          _rarestRow(
            l10n,
            platform,
            resolveRarestAchievement(cardFor(platform)) != null,
            nextPosition,
          ),
    ];
    final whatIOwnRows = steamLinked
        ? _collectionRows(l10n, steamCard, steamLibrary, nextPosition)
        : const <_Entry>[];
    final artRows = [_artRow(l10n, nextPosition)];

    final groups = <(Key, String, List<_Entry>)>[
      (const Key('catalogGroupWhoIAm'), l10n.addCatalogGroupWhoIAm, whoIAmRows),
      (
        const Key('catalogGroupWhatIPlay'),
        l10n.addCatalogGroupWhatIPlay,
        whatIPlayRows,
      ),
      (
        const Key('catalogGroupHowGoodIAm'),
        l10n.addCatalogGroupHowGoodIAm,
        howGoodIAmRows,
      ),
      (
        const Key('catalogGroupWhatIAchieved'),
        l10n.addCatalogGroupWhatIAchieved,
        whatIAchievedRows,
      ),
      (
        const Key('catalogGroupWhatIOwn'),
        l10n.addCatalogGroupWhatIOwn,
        whatIOwnRows,
      ),
      // Last: every category above answers a question with data; the visual
      // family answers with a picture.
      (const Key('catalogGroupArt'), l10n.addCatalogGroupArt, artRows),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.addCatalogTitle,
          key: const Key('addCatalogTitle'),
          style: textTheme.titleLarge,
        ),
        _platformFilter(l10n, groups),
        for (final (key, header, entries) in groups)
          _group(key, header, entries),
        if (_catalogUniverse.any((platform) => !linked.contains(platform)))
          _footer(l10n),
      ],
    );
  }

  /// The platform axis, offered only for the platforms the catalog actually has
  /// rows for — a filter that can empty the whole list is a dead end, not a
  /// choice. Absent entirely below two platforms, where it would only ask the
  /// owner to confirm what they can already see.
  Widget _platformFilter(
    AppLocalizations l10n,
    List<(Key, String, List<_Entry>)> groups,
  ) {
    final platforms = <Platform>{
      for (final (_, _, entries) in groups)
        for (final entry in entries)
          if (entry.platform != null) entry.platform!,
    }.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (platforms.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            key: const Key('catalogPlatformChip_all'),
            label: Text(l10n.addCatalogFilterAll),
            selected: _platform == null,
            onSelected: (_) => setState(() => _platform = null),
          ),
          for (final platform in platforms)
            ChoiceChip(
              key: Key('catalogPlatformChip_${platform.name}'),
              label: Text(_brand(platform)),
              selected: _platform == platform,
              // Re-tapping the held chip clears it, so All is reachable without
              // aiming at a different target.
              onSelected: (selected) =>
                  setState(() => _platform = selected ? platform : null),
            ),
        ],
      ),
    );
  }

  /// Runs one row's write and closes the sheet. One at a time: a second tap
  /// while a write is pending is ignored, so a card is never added twice.
  ///
  /// Placement is reactive — the owner wrapper folds each refetch of the widgets
  /// read into the working layout — so this deliberately does not couple the
  /// placement to the pop.
  Future<void> _acquire(
    Key rowKey,
    Future<void> Function(ProfileWidgetsController) onAcquire,
  ) async {
    if (_acquiring != null) return;
    setState(() => _acquiring = rowKey);
    final controller = ref.read(profileWidgetsControllerProvider.notifier);
    // The controller routes any failure through its own error state and never
    // throws, so this completes on success and failure alike.
    await onAcquire(controller);
    if (!mounted) return;
    setState(() => _acquiring = null);
    // Close only if this sheet is still the active route: it may have been
    // dismissed through another channel while the write was in flight, and an
    // unconditional pop would land on the screen beneath it.
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  /// Keeps the entries the active filter admits. A platform-less card belongs to
  /// no platform, so narrowing to one leaves it out rather than pinning it to
  /// every list.
  List<_Entry> _visible(List<_Entry> entries) {
    final platform = _platform;
    if (platform == null) return entries;
    return [
      for (final entry in entries)
        if (entry.platform == platform) entry,
    ];
  }

  /// A group renders its header only when the filter leaves it something to
  /// show, so a narrowed catalog carries no empty headers.
  Widget _group(Key headerKey, String header, List<_Entry> entries) {
    final visible = _visible(entries);
    if (visible.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(header, key: headerKey, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        for (final entry in visible) entry.row,
      ],
    );
  }

  /// Identity (Passport) is cross-platform: placed reads as added; with no
  /// linked platform it is disabled; otherwise it offers. Never offered empty.
  _Entry _identityRow(
    AppLocalizations l10n,
    Set<Platform> linked,
    int nextPosition,
  ) {
    final label = l10n.passportLabel;
    ({String label, Platform? platform, Widget row}) entry(Widget row) =>
        (label: label, platform: null, row: row);
    if (widget.existing.any((w) => w.kind == ProfileWidgetKind.passport)) {
      return entry(_addedRow(const Key('passportAddedRow'), label));
    }
    if (linked.isEmpty) {
      return entry(
        _disabledRow(
          const Key('passportDisabledRow'),
          label,
          l10n.addCatalogReasonNoPlatforms,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: const Key('passportAddRow'),
        label: label,
        busy: _acquiring == const Key('passportAddRow'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(const Key('passportAddRow'), (controller) =>
            controller.addPassport(position: nextPosition)),
      ),
    );
  }

  /// A per-platform Rank or Main row: added when already placed, disabled with a
  /// reason when the card carries no data, otherwise a single-tap offer.
  _Entry _kindRow({
    required AppLocalizations l10n,
    required ProfileWidgetKind kind,
    required Platform platform,
    required bool hasData,
    required String reason,
    required int nextPosition,
  }) {
    final label = _brand(platform);
    final prefix = kind == ProfileWidgetKind.rank ? 'rank' : 'main';
    _Entry entry(Widget row) => (label: label, platform: platform, row: row);
    if (widget.existing.any((w) => w.kind == kind && w.platform == platform)) {
      return entry(_addedRow(Key('${prefix}AddedRow_${platform.name}'), label));
    }
    if (!hasData) {
      return entry(
        _disabledRow(
          Key('${prefix}DisabledRow_${platform.name}'),
          label,
          reason,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: Key('${prefix}AddRow_${platform.name}'),
        label: label,
        busy: _acquiring == Key('${prefix}AddRow_${platform.name}'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(Key('${prefix}AddRow_${platform.name}'), (controller) => kind == ProfileWidgetKind.rank
            ? controller.addRank(platform: platform, position: nextPosition)
            : controller.addMain(platform: platform, position: nextPosition)),
      ),
    );
  }

  /// The Recent row for [platform]: added when already placed, disabled with a
  /// reason when the platform published no recent activity, otherwise a
  /// single-tap offer. Labelled by card name rather than by platform — the
  /// group's Main rows already carry the platform names, so a second one would
  /// be ambiguous.
  _Entry _recentRow(
    AppLocalizations l10n,
    Platform platform,
    bool hasData,
    int nextPosition,
  ) {
    final label = l10n.addCatalogRowRecent;
    _Entry entry(Widget row) => (label: label, platform: platform, row: row);
    if (widget.existing.any(
      (w) => w.kind == ProfileWidgetKind.recent && w.platform == platform,
    )) {
      return entry(_addedRow(Key('recentAddedRow_${platform.name}'), label));
    }
    if (!hasData) {
      return entry(
        _disabledRow(
          Key('recentDisabledRow_${platform.name}'),
          label,
          l10n.addCatalogReasonRecentNoData,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: Key('recentAddRow_${platform.name}'),
        label: label,
        busy: _acquiring == Key('recentAddRow_${platform.name}'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(Key('recentAddRow_${platform.name}'), (controller) =>
            controller.addRecent(platform: platform, position: nextPosition)),
      ),
    );
  }

  /// The Personal Best row for [platform]: added when already placed, disabled
  /// with a reason when the platform published no peak figure, otherwise a
  /// single-tap offer. Labelled by card name rather than by platform — the
  /// group's Rank rows already carry the platform names, so a second one would
  /// be ambiguous.
  _Entry _personalBestRow(
    AppLocalizations l10n,
    Platform platform,
    bool hasData,
    int nextPosition,
  ) {
    final label = l10n.addCatalogRowPersonalBest;
    _Entry entry(Widget row) => (label: label, platform: platform, row: row);
    if (widget.existing.any(
      (w) => w.kind == ProfileWidgetKind.personalBest && w.platform == platform,
    )) {
      return entry(
        _addedRow(Key('personalBestAddedRow_${platform.name}'), label),
      );
    }
    if (!hasData) {
      return entry(
        _disabledRow(
          Key('personalBestDisabledRow_${platform.name}'),
          label,
          l10n.addCatalogReasonPersonalBestNoData,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: Key('personalBestAddRow_${platform.name}'),
        label: label,
        busy: _acquiring == Key('personalBestAddRow_${platform.name}'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(Key('personalBestAddRow_${platform.name}'), (controller) => controller.addPersonalBest(
          platform: platform,
          position: nextPosition),
        ),
      ),
    );
  }

  /// The Rarest Achievement row for [platform]: added when already placed,
  /// disabled with a reason when the platform published no achievement rarity,
  /// otherwise a single-tap offer. Labelled by card name rather than by
  /// platform, like the Recent row.
  _Entry _rarestRow(
    AppLocalizations l10n,
    Platform platform,
    bool hasData,
    int nextPosition,
  ) {
    final label = l10n.addCatalogRowRarest;
    _Entry entry(Widget row) => (label: label, platform: platform, row: row);
    if (widget.existing.any(
      (w) =>
          w.kind == ProfileWidgetKind.rarestAchievement &&
          w.platform == platform,
    )) {
      return entry(_addedRow(Key('rarestAddedRow_${platform.name}'), label));
    }
    if (!hasData) {
      return entry(
        _disabledRow(
          Key('rarestDisabledRow_${platform.name}'),
          label,
          l10n.addCatalogReasonRarestNoData,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: Key('rarestAddRow_${platform.name}'),
        label: label,
        busy: _acquiring == Key('rarestAddRow_${platform.name}'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(Key('rarestAddRow_${platform.name}'), (controller) => controller.addRarestAchievement(
          platform: platform,
          position: nextPosition),
        ),
      ),
    );
  }

  /// The single Art row. One tap adds the card unpointed; it resolves its own
  /// picture at render time (best available art, else the theme's ground), so
  /// the row never asks the owner to choose between platforms and is never
  /// disabled — the fallback is the answer to having nothing to show.
  _Entry _artRow(AppLocalizations l10n, int nextPosition) {
    final label = l10n.addCatalogRowArt;
    _Entry entry(Widget row) => (label: label, platform: null, row: row);
    if (widget.existing.any((w) => w.kind == ProfileWidgetKind.art)) {
      return entry(_addedRow(const Key('artAddedRow'), label));
    }
    return entry(
      _AddRow(
        rowKey: const Key('artAddRow'),
        label: label,
        busy: _acquiring == const Key('artAddRow'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(const Key('artAddRow'), (controller) => controller.addArt(
          position: nextPosition,
          // A picture is the point, so it lands as a full-width card.
        )),
      ),
    );
  }

  /// Milestone offers a single-game showcase picked in step 2. An empty Steam
  /// library disables the row rather than creating a card that reads as empty.
  _Entry _milestoneRow(
    AppLocalizations l10n,
    List<LibraryShowcaseEntry> library,
  ) {
    final label = l10n.addCatalogRowMilestone;
    _Entry entry(Widget row) =>
        (label: label, platform: Platform.steam, row: row);
    if (library.isEmpty) {
      return entry(
        _disabledRow(
          const Key('milestoneDisabledRow'),
          label,
          l10n.showcasePickerEmpty,
        ),
      );
    }
    return entry(
      _stepRow(
        const Key('milestoneStepRow'),
        label,
        () => setState(() => _step = _Step.milestone),
      ),
    );
  }

  /// The Collection group: a curated set (step 2) and the whole-library
  /// Collector variant (single tap).
  List<_Entry> _collectionRows(
    AppLocalizations l10n,
    GameCard? steamCard,
    List<LibraryShowcaseEntry> library,
    int nextPosition,
  ) {
    _Entry entry(String label, Widget row) =>
        (label: label, platform: Platform.steam, row: row);
    final Widget curated;
    if (library.isEmpty) {
      curated = _disabledRow(
        const Key('collectionCuratedDisabledRow'),
        l10n.addCatalogRowCollectionCurated,
        l10n.showcasePickerEmpty,
      );
    } else {
      curated = _stepRow(
        const Key('collectionCuratedRow'),
        l10n.addCatalogRowCollectionCurated,
        () => setState(() => _step = _Step.collection),
      );
    }

    final Widget collector;
    final resolved = resolveGameCollector(steamCard);
    if (widget.existing.any(
      (w) =>
          w.kind == ProfileWidgetKind.gameCollector &&
          w.platform == Platform.steam,
    )) {
      collector = _addedRow(
        const Key('collectorAddedRow_steam'),
        l10n.addCatalogRowCollectionLibrary,
      );
    } else if (resolved == null || resolved.gamesOwned == 0) {
      // A would-be-empty collector is never offered.
      collector = _disabledRow(
        const Key('collectorDisabledRow_steam'),
        l10n.addCatalogRowCollectionLibrary,
        l10n.gameCollectorPickerEmpty,
      );
    } else {
      collector = _AddRow(
        rowKey: const Key('collectorAddRow_steam'),
        label: l10n.addCatalogRowCollectionLibrary,
        busy: _acquiring == const Key('collectorAddRow_steam'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(const Key('collectorAddRow_steam'), (controller) => controller.addGameCollector(
          platform: Platform.steam,
          position: nextPosition),
        ),
      );
    }
    return [
      entry(l10n.addCatalogRowCollectionCurated, curated),
      entry(l10n.addCatalogRowCollectionLibrary, collector),
    ];
  }

  /// Achievement Grid offers the whole-library Completionist variant. A card
  /// with no perfect games is disabled rather than created empty.
  _Entry _completionistRow(
    AppLocalizations l10n,
    GameCard? steamCard,
    int nextPosition,
  ) {
    final label = l10n.completionistLabel;
    _Entry entry(Widget row) =>
        (label: label, platform: Platform.steam, row: row);
    final resolved = resolveCompletionist(steamCard);
    if (widget.existing.any(
      (w) =>
          w.kind == ProfileWidgetKind.completionist &&
          w.platform == Platform.steam,
    )) {
      return entry(_addedRow(const Key('completionistAddedRow_steam'), label));
    }
    if (resolved == null || resolved.gamesPerfect == 0) {
      return entry(
        _disabledRow(
          const Key('completionistDisabledRow_steam'),
          label,
          l10n.completionistPickerEmpty,
        ),
      );
    }
    return entry(
      _AddRow(
        rowKey: const Key('completionistAddRow_steam'),
        label: label,
        busy: _acquiring == const Key('completionistAddRow_steam'),
        onTap: _acquiring != null
            ? null
            : () => _acquire(const Key('completionistAddRow_steam'), (controller) => controller.addCompletionist(
          platform: Platform.steam,
          position: nextPosition),
        ),
      ),
    );
  }

  Widget _footer(AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        key: const Key('catalogConnectMoreLink'),
        // Capture the router BEFORE popping: the pop unmounts this context, so
        // navigating on it afterwards would use a defunct element.
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push('/connections');
        },
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.smMd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_link,
                size: AppSpacing.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.addCatalogConnectMore,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addedRow(Key key, String label) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.smMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.addCatalogAdded,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// The reason sits under the label rather than beside it so a long reason
  /// never competes for width — the row cannot overflow on a narrow phone.
  Widget _disabledRow(Key key, String label, String reason) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.smMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(Key key, String label, VoidCallback onTap) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.smMd,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: textTheme.bodyMedium)),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// Back affordance for a step-2 body. Its tooltip reuses the platform's
  /// back-button label so no new string is introduced.
  Widget _backBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: const Key('catalogStepBack'),
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => setState(() => _step = _Step.catalog),
      ),
    );
  }

  Widget _milestoneBody(
    Map<Platform, AsyncValue<GameCard?>> cardStates,
    int nextPosition,
  ) {
    final state = cardStates[Platform.steam];
    if (state == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AsyncValueWidget<GameCard?>(
      value: state,
      data: (card) {
        final games = _steamLibrary(card);
        // A game already placed as a showcase is never offered again.
        final alreadyShowcased = {
          for (final w in widget.existing)
            if (w.kind == ProfileWidgetKind.showcase &&
                w.platform == Platform.steam)
              w.showcaseSelection.gameRef,
        };
        final addable = [
          for (final game in games)
            if (!alreadyShowcased.contains(game.appId.toString())) game,
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _backBar(),
            Text(
              l10n.showcasePickerTitle,
              key: const Key('showcasePickerTitle'),
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (addable.isEmpty)
              Text(
                l10n.showcasePickerAllAdded,
                key: const Key('showcasePickerAllAdded'),
                style: textTheme.bodyMedium,
              )
            else
              _tileGrid(addable, nextPosition),
          ],
        );
      },
    );
  }

  Widget _collectionBody(
    Map<Platform, AsyncValue<GameCard?>> cardStates,
    int nextPosition,
  ) {
    final state = cardStates[Platform.steam];
    if (state == null) return const SizedBox.shrink();
    return AsyncValueWidget<GameCard?>(
      value: state,
      data: (card) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backBar(),
          CollectionPickerBody(
            games: _steamLibrary(card),
            nextPosition: nextPosition,
          ),
        ],
      ),
    );
  }

  /// Two columns, mobile-first: the tile width is derived from the sheet's own
  /// constraints, and the tiles scroll with the shared sheet surface.
  Widget _tileGrid(List<LibraryShowcaseEntry> games, int nextPosition) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final game in games)
              SizedBox(
                width: tileWidth,
                child: _GameTile(entry: game, nextPosition: nextPosition),
              ),
          ],
        );
      },
    );
  }

  List<LibraryShowcaseEntry> _steamLibrary(GameCard? card) {
    final data = card?.data;
    return data is SteamCardData
        ? data.libraryShowcase
        : const <LibraryShowcaseEntry>[];
  }

  /// Append after the current max position to avoid a foreseeable unique
  /// collision; the backend constraint stays authoritative.
  int _nextPosition(List<ProfileWidget> existing) => existing.isEmpty
      ? 0
      : existing.map((w) => w.position).reduce((a, b) => a > b ? a : b) + 1;

  /// Brand-correct platform name (proper noun, intentionally not localized).
  String _brand(Platform platform) =>
      platformDescriptors[platform]?.displayName ?? platform.name;
}

/// One tappable auto-acquire row: a label with an Add affordance. It owns no
/// acquisition state of its own — the sheet does. A row can be taken off screen
/// by a filter while its write is still in flight, and a lifecycle living here
/// would die with it: the sheet would never close, and because the placed-card
/// check reads the snapshot taken when the sheet opened, clearing the filter
/// would offer the same card again and add it twice.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.rowKey,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.smMd,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: textTheme.bodyMedium)),
            const SizedBox(width: AppSpacing.sm),
            if (busy)
              SizedBox(
                width: AppSpacing.md,
                height: AppSpacing.md,
                child: CircularProgressIndicator(
                  strokeWidth: AppSpacing.hairline,
                  color: colorScheme.primary,
                ),
              )
            else
              Text(
                l10n.addCatalogActionAdd,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
          ],
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
