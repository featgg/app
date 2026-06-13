import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import '../domain/profile_widget.dart';
import '../domain/profile_widgets_providers.dart';
import '../domain/profile_widgets_repository.dart';
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

  /// Adds a [platform] widget at the given [position] with [size].
  Future<void> addPlatform({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  }) => _run(
    (repo) => repo.addPlatformWidget(
      platform: platform,
      position: position,
      size: size,
    ),
  );

  /// Removes the widget [id].
  Future<void> remove(String id) => _run((repo) => repo.removeWidget(id));

  /// Sets `is_enabled` on the widget [id].
  Future<void> toggle(String id, bool isEnabled) =>
      _run((repo) => repo.setEnabled(id, isEnabled));

  /// Sets the size on the widget [id].
  Future<void> resize(String id, ProfileWidgetSize size) =>
      _run((repo) => repo.setSize(id, size));

  /// Persists a new ordering of widget ids.
  Future<void> reorder(List<String> orderedIds) =>
      _run((repo) => repo.reorder(orderedIds));

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
