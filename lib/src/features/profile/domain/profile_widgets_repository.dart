import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import 'collection_selection.dart';
import 'profile_widget.dart';
import 'showcase_selection.dart';

/// Reads and mutates the signed-in owner's `profile_widgets` arrangement.
/// All methods return `Either<Failure, T>`; the Shape-2 SDK errors are mapped
/// to [Failure] subtypes in the implementation.
abstract interface class ProfileWidgetsRepository {
  /// Owner's widgets ordered by position. Right([]) when none.
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets();

  /// Any user's widgets ordered by position for the public visitor render, with
  /// no auth gate. Right([]) when none — a private or non-existent profile
  /// returns no rows (RLS), so the visitor sees the empty state.
  Future<Either<Failure, List<ProfileWidget>>> fetchPublicWidgets(
    String userId,
  );

  /// Inserts a platform widget at [position] with [size], enabled.
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a showcase widget for [platform] with [selection] at [position]
  /// and [size], enabled.
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a collection widget with [selection] at [position] and [size],
  /// enabled and with a null platform (a collection spans multiple games).
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a game-collector widget bound to [platform] at [position] with
  /// [size], enabled. Platform-bound (the library it aggregates); the settings
  /// envelope carries only the size (no per-widget selection sub-object).
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a completionist widget bound to [platform] at [position] with
  /// [size], enabled. Platform-bound (the library whose perfect-games count it
  /// surfaces); the settings envelope carries only the size (no per-widget
  /// selection sub-object).
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a passport widget at [position] with [size], enabled and with a
  /// null platform (it aggregates every linked platform). The settings envelope
  /// carries only the size (no per-widget selection sub-object).
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts an art widget at [position] with [size], enabled. Left without a
  /// [source] — the normal add — the card resolves its picture at render time
  /// (best available art, else the theme's ground). A source pins it to one
  /// platform's art; it rides in the settings envelope, not the platform
  /// column, because an art card reads no account data — the seam through
  /// which non-platform sources (an uploaded image) arrive later.
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a rank widget bound to [platform] at [position] with [size],
  /// enabled. Platform-bound (the competitive rank/rating it surfaces); the
  /// settings envelope carries only the size (no per-widget selection sub-object).
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a main widget bound to [platform] at [position] with [size],
  /// enabled. Platform-bound (the primary game/character/mode it surfaces); the
  /// settings envelope carries only the size (no per-widget selection sub-object).
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Deletes the owner's widget [id].
  Future<Either<Failure, Unit>> removeWidget(String id);

  /// Sets the size (`settings.size`) for [id].
  Future<Either<Failure, Unit>> setSize(String id, ProfileWidgetSize size);

  /// Sets the size for the showcase widget [id]. The settings envelope
  /// carries the game [selection] alongside the size, so a size change must
  /// rewrite both — a size-only write would drop the selection.
  Future<Either<Failure, Unit>> setShowcaseSize(
    String id,
    ProfileWidgetSize size,
    ShowcaseSelection selection,
  );

  /// Sets the size for the collection widget [id]. The settings envelope carries
  /// the game [selection] alongside the size, so a size change must rewrite both
  /// — a size-only write would drop the games and title.
  Future<Either<Failure, Unit>> setCollectionSize(
    String id,
    ProfileWidgetSize size,
    CollectionSelection selection,
  );
}
