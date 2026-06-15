import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/data_menu_selection.dart';
import '../domain/profile_widget.dart';
import '../domain/profile_widgets_providers.dart';
import '../domain/profile_widgets_repository.dart';
import 'profile_widgets_provider.dart';

part 'data_menu_controller.g.dart';

/// Persists the owner's data-menu selection for one widget. One repository call
/// inside [AsyncValue.guard], surfacing a failure through the controller's own
/// error state, and invalidating [ownerProfileWidgetsProvider] on success so
/// the read provider stays the single source of truth.
///
/// autoDispose-by-default: it reads autoDispose providers, so a `ref.mounted`
/// guard after the await prevents a write to a disposed notifier.
@riverpod
class DataMenuController extends _$DataMenuController {
  @override
  FutureOr<void> build() {}

  /// Persists [selection] for [widget], preserving the widget's current size.
  Future<void> setSelection(
    ProfileWidget widget,
    DataMenuSelection selection,
  ) async {
    state = const AsyncLoading();
    final repo = ref.read(profileWidgetsRepositoryProvider);
    final next = await AsyncValue.guard(() async {
      final result = await _persist(repo, widget, selection);
      // Throw the Left so a Failure lands in the controller's error state via
      // guard; the Right is discarded (the read provider is re-read on
      // invalidate below).
      result.fold((failure) => throw failure, (_) {});
    });
    // autoDispose: never write state after the notifier has been disposed.
    if (!ref.mounted) return;
    state = next;
    if (!next.hasError) ref.invalidate(ownerProfileWidgetsProvider);
  }

  Future<Either<Failure, Unit>> _persist(
    ProfileWidgetsRepository repo,
    ProfileWidget widget,
    DataMenuSelection selection,
  ) => repo.setDataMenuSelection(widget.id, widget.size, selection);
}
