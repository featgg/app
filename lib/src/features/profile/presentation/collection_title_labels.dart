import '../../../core/l10n/l10n.dart';

/// Resolves a collection catalog title key to its localized string. The single
/// place collection title keys map to [AppLocalizations] getters, keeping copy
/// out of `domain` and tests. A key not handled here returns null — an unknown /
/// stale key soft-resolves to no label at render, and the totality test fails
/// loudly rather than shipping a catalog title with no copy.
String? collectionTitleLabel(AppLocalizations l10n, String titleKey) =>
    switch (titleKey) {
      'collectionTitleFavorites' => l10n.collectionTitleFavorites,
      'collectionTitleNowPlaying' => l10n.collectionTitleNowPlaying,
      'collectionTitleBacklog' => l10n.collectionTitleBacklog,
      'collectionTitleCompleted' => l10n.collectionTitleCompleted,
      'collectionTitleAllTime' => l10n.collectionTitleAllTime,
      'collectionTitleHiddenGems' => l10n.collectionTitleHiddenGems,
      'collectionTitleMostPlayed' => l10n.collectionTitleMostPlayed,
      _ => null,
    };
