import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import '../domain/art_framing.dart';
import '../domain/collection_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/profile_widgets_providers.dart';
import '../domain/profile_widgets_repository.dart';
import '../domain/showcase_selection.dart';
import 'profile_widgets_provider.dart';

part 'profile_widgets_controller.g.dart';

/// Mutates the owner's profile-widget arrangement. Each method runs one
/// repository call inside [AsyncValue.guard], surfacing a failure through the
/// controller's own error state, and invalidates [ownerProfileWidgetsProvider]
/// on success so the read provider stays the single source of truth.
///
/// autoDispose-by-default: it reads autoDispose providers, so it must not be
/// kept alive. A `ref.mounted` guard after the await prevents a write to a
/// disposed notifier.
@riverpod
class ProfileWidgetsController extends _$ProfileWidgetsController {
  @override
  FutureOr<void> build() {}

  /// Adds a [platform] widget at the given [position].
  Future<void> addPlatform({
    required Platform platform,
    required int position,
  }) => _run(
    (repo) => repo.addPlatformWidget(platform: platform, position: position),
  );

  /// Adds a showcase widget for [platform] and [selection] at [position].
  Future<void> addShowcase({
    required Platform platform,
    required ShowcaseSelection selection,
    required int position,
  }) => _run(
    (repo) => repo.addShowcaseWidget(
      platform: platform,
      selection: selection,
      position: position,
    ),
  );

  /// Adds a collection widget for [selection] at [position].
  Future<void> addCollection({
    required CollectionSelection selection,
    required int position,
  }) => _run(
    (repo) =>
        repo.addCollectionWidget(selection: selection, position: position),
  );

  /// Adds a game-collector widget bound to [platform] at [position].
  Future<void> addGameCollector({
    required Platform platform,
    required int position,
  }) => _run(
    (repo) =>
        repo.addGameCollectorWidget(platform: platform, position: position),
  );

  /// Adds a completionist widget bound to [platform] at [position].
  Future<void> addCompletionist({
    required Platform platform,
    required int position,
  }) => _run(
    (repo) =>
        repo.addCompletionistWidget(platform: platform, position: position),
  );

  /// Replaces the games and title on the collection widget [id].
  Future<void> setCollectionSelection(
    String id,
    CollectionSelection selection,
  ) => _run((repo) => repo.setCollectionSelection(id, selection));

  /// Adds a passport widget at [position].
  Future<void> addPassport({required int position}) =>
      _run((repo) => repo.addPassportWidget(position: position));

  /// Adds a rank widget bound to [platform] at [position].
  Future<void> addRank({required Platform platform, required int position}) =>
      _run(
        (repo) => repo.addRankWidget(platform: platform, position: position),
      );

  /// Adds a main widget bound to [platform] at [position].
  Future<void> addMain({required Platform platform, required int position}) =>
      _run(
        (repo) => repo.addMainWidget(platform: platform, position: position),
      );

  /// Adds a recent widget bound to [platform] at [position].
  Future<void> addRecent({required Platform platform, required int position}) =>
      _run(
        (repo) => repo.addRecentWidget(platform: platform, position: position),
      );

  /// Adds an art widget at [position]. Without [source] the card
  /// resolves its own picture at render time; with one it pins that platform.
  Future<void> addArt({Platform? source, required int position}) =>
      _run((repo) => repo.addArtWidget(source: source, position: position));

  /// Removes the widget [id].
  Future<void> remove(String id) => _run((repo) => repo.removeWidget(id));

  /// Sets the hero stat on the showcase widget [id]. The envelope holds the
  /// whole selection, so the hero change is one rewrite of it.
  Future<void> setShowcaseHero(String id, ShowcaseSelection selection) =>
      _run((repo) => repo.setShowcaseSelection(id, selection));

  /// Moves the picture inside [widget]'s frame.
  Future<void> setArtFraming(ProfileWidget widget, ArtFraming framing) =>
      _run((repo) => repo.setArtFraming(widget, framing));

  Future<void> _run(
    Future<Either<Failure, Object?>> Function(ProfileWidgetsRepository repo) op,
  ) async {
    state = const AsyncLoading();
    final repo = ref.read(profileWidgetsRepositoryProvider);
    final next = await AsyncValue.guard(() async {
      final result = await op(repo);
      // Throw the Left so a Failure lands in the controller's error state via
      // guard; the Right value is discarded (the read provider is the source
      // of truth, re-read on invalidate below).
      result.fold((failure) => throw failure, (_) {});
    });
    // autoDispose: never write state after the notifier has been disposed.
    if (!ref.mounted) return;
    state = next;
    if (!next.hasError) ref.invalidate(ownerProfileWidgetsProvider);
  }
}
