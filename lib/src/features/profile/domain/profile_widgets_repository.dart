import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import 'art_framing.dart';
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

  /// Inserts a platform widget at [position], enabled.
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a showcase widget for [platform] with [selection] at [position], enabled.
  Future<Either<Failure, ProfileWidget>> addShowcaseWidget({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
  });

  /// Inserts a collection widget with [selection] at [position], enabled and with a null platform (a collection spans multiple games).
  Future<Either<Failure, ProfileWidget>> addCollectionWidget({
    required CollectionSelection selection,
    required int position,
  });

  /// Inserts a game-collector widget bound to [platform] at [position], enabled. Platform-bound (the library it aggregates); the settings
  /// envelope is bare — no per-widget selection sub-object.
  Future<Either<Failure, ProfileWidget>> addGameCollectorWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a completionist widget bound to [platform] at [position], enabled. Platform-bound (the library whose perfect-games count it
  /// surfaces); the settings envelope is bare — no per-widget
  /// selection sub-object.
  Future<Either<Failure, ProfileWidget>> addCompletionistWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a passport widget at [position], enabled and with a
  /// null platform (it aggregates every linked platform). The settings envelope
  /// is bare — no per-widget selection sub-object.
  Future<Either<Failure, ProfileWidget>> addPassportWidget({
    required int position,
  });

  /// Inserts an art widget at [position], enabled. Left without a
  /// [source] — the normal add — the card resolves its picture at render time
  /// (best available art, else the theme's ground). A source pins it to one
  /// platform's art; it rides in the settings envelope, not the platform
  /// column, because an art card reads no account data — the seam through
  /// which non-platform sources (an uploaded image) arrive later.
  Future<Either<Failure, ProfileWidget>> addArtWidget({
    Platform? source,
    required int position,
  });

  /// Inserts a rank widget bound to [platform] at [position], enabled.
  /// Platform-bound (the competitive rank/rating it surfaces); the settings
  /// envelope is bare — no per-widget selection sub-object.
  Future<Either<Failure, ProfileWidget>> addRankWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a main widget bound to [platform] at [position], enabled.
  /// Platform-bound (the primary game/character/mode it surfaces); the settings
  /// envelope is bare — no per-widget selection sub-object.
  Future<Either<Failure, ProfileWidget>> addMainWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a recent widget bound to [platform] at [position], enabled.
  /// Platform-bound (the platform whose recent activity it surfaces); the
  /// settings envelope is bare — no per-widget selection sub-object.
  Future<Either<Failure, ProfileWidget>> addRecentWidget({
    required Platform platform,
    required int position,
  });

  /// Inserts a rarest-achievement widget bound to [platform] at [position],
  /// enabled. Platform-bound (the platform whose achievement rarity it
  /// surfaces); the settings envelope is bare — no per-widget selection
  /// sub-object.
  Future<Either<Failure, ProfileWidget>> addRarestAchievementWidget({
    required Platform platform,
    required int position,
  });

  /// Deletes the owner's widget [id].
  Future<Either<Failure, Unit>> removeWidget(String id);

  /// Replaces the game [selection] of the showcase widget [id].
  Future<Either<Failure, Unit>> setShowcaseSelection(
    String id,
    ShowcaseSelection selection,
  );

  /// Replaces the game [selection] of the collection widget [id].
  Future<Either<Failure, Unit>> setCollectionSelection(
    String id,
    CollectionSelection selection,
  );

  /// Replaces how [widget]'s picture is framed. Takes the widget rather than
  /// its id because framing shares the envelope with the widget's own
  /// selection, and the write emits the envelope whole.
  Future<Either<Failure, Unit>> setArtFraming(
    ProfileWidget widget,
    ArtFraming framing,
  );
}
