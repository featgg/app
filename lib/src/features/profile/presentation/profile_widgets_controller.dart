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

  /// Adds a template widget for [templateId] at [position] with [size].
  Future<void> addTemplate({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  }) => _run(
    (repo) => repo.addTemplateWidget(
      templateId: templateId,
      position: position,
      size: size,
    ),
  );

  /// Fills a single [slotId] of template widget [widgetId] with [itemId].
  ///
  /// Read-modify-write against the live read provider, not a snapshot from the
  /// caller: the slot picker captures the widget when it opens, so a fill
  /// computed from that snapshot would clobber a slot saved in the meantime.
  /// No-op if the widget is gone by the time the write runs.
  Future<void> setTemplateSlot({
    required String widgetId,
    required String slotId,
    required String itemId,
  }) => _run((repo) async {
    final widgets = await ref.read(ownerProfileWidgetsProvider.future);
    ProfileWidget? current;
    for (final widget in widgets) {
      if (widget.id == widgetId) {
        current = widget;
        break;
      }
    }
    if (current == null) return right(unit);
    return repo.setTemplateFill(
      current.id,
      current.size,
      current.templateFill.withSlot(slotId, itemId),
    );
  });

  /// Removes the widget [id].
  Future<void> remove(String id) => _run((repo) => repo.removeWidget(id));

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
