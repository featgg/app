import 'connection.dart';

/// Per-platform wire configuration. Kept in `domain` so both the data layer
/// and the presentation layer can reference it without a circular dependency.
/// The widget halves (link form, data-block view) live in a presentation-side
/// registry keyed by the same [Platform] enum.
///
/// The abstraction is justified by six confirmed second callers (the other
/// platform stories). Each later platform adds one entry here (and one entry
/// to the data-layer card-parser registry and the presentation widget
/// registry) — each a single-line addition that is conflict-free when stories
/// run in parallel worktrees.
final class PlatformDescriptor {
  const PlatformDescriptor({
    required this.platform,
    required this.displayName,
    required this.shortName,
    required this.wireValue,
    required this.syncFunctionName,
  });

  /// The [Platform] enum value this descriptor covers.
  final Platform platform;

  /// Brand-correct display name shown in the UI (e.g. 'Steam', not the enum
  /// token). These are proper nouns and are intentionally not localized.
  final String displayName;

  /// The name for a surface that has room for a word, not a title — a card
  /// label naming what a number is about. Chosen to survive being uppercased,
  /// which is how a label renders: an abbreviation whose meaning lives in its
  /// camel case loses it there, so this prefers the readable word over the
  /// shorter initialism. Proper nouns, so not localized either.
  final String shortName;

  /// Wire platform token used in every API request body and Shape-2 query.
  final String wireValue;

  /// Edge-function name for the sync operation (e.g. `sync-steam`).
  final String syncFunctionName;
}

/// All registered platform descriptors. Each story adds one entry here
/// (alongside the data-layer card-parser registry and presentation widget
/// registry) — additive and conflict-free across parallel worktrees.
const Map<Platform, PlatformDescriptor> platformDescriptors = {
  Platform.steam: PlatformDescriptor(
    platform: Platform.steam,
    displayName: 'Steam',
    shortName: 'Steam',
    wireValue: 'steam',
    syncFunctionName: 'sync-steam',
  ),
  Platform.minecraftHypixel: PlatformDescriptor(
    platform: Platform.minecraftHypixel,
    displayName: 'Minecraft (Hypixel)',
    shortName: 'Hypixel',
    wireValue: 'minecraft_hypixel',
    syncFunctionName: 'sync-minecraft-hypixel',
  ),
  Platform.retroachievements: PlatformDescriptor(
    platform: Platform.retroachievements,
    displayName: 'RetroAchievements',
    shortName: 'Retro',
    wireValue: 'retroachievements',
    syncFunctionName: 'sync-retroachievements',
  ),
  Platform.leagueOfLegends: PlatformDescriptor(
    platform: Platform.leagueOfLegends,
    displayName: 'League of Legends',
    shortName: 'League',
    wireValue: 'league_of_legends',
    syncFunctionName: 'sync-league-of-legends',
  ),
  Platform.wowRetail: PlatformDescriptor(
    platform: Platform.wowRetail,
    displayName: 'World of Warcraft (Retail)',
    shortName: 'WoW',
    wireValue: 'wow_retail',
    syncFunctionName: 'sync-wow-retail',
  ),
  Platform.chess: PlatformDescriptor(
    platform: Platform.chess,
    displayName: 'Chess.com',
    shortName: 'Chess',
    wireValue: 'chess',
    syncFunctionName: 'sync-chess',
  ),
  Platform.gw2: PlatformDescriptor(
    platform: Platform.gw2,
    displayName: 'Guild Wars 2',
    shortName: 'GW2',
    wireValue: 'gw2',
    syncFunctionName: 'sync-gw2',
  ),
};
