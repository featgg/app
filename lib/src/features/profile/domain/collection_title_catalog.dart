/// The stable catalog of collection title keys. Catalog-only: the owner picks
/// one of these keys (no free text), so the stored value re-localizes and never
/// needs a data migration when copy changes. Adding a title = appending ONE key
/// here plus its l10n entry; the iterating totality test needs no new case.
const List<String> collectionTitleCatalog = [
  'collectionTitleFavorites',
  'collectionTitleNowPlaying',
  'collectionTitleBacklog',
  'collectionTitleCompleted',
  'collectionTitleAllTime',
  'collectionTitleHiddenGems',
  'collectionTitleMostPlayed',
];
