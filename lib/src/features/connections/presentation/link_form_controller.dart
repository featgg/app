import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/connection.dart';
import '../domain/connections_providers.dart';
import 'connection_actions_controller.dart';
import 'connections_provider.dart';

part 'link_form_controller.g.dart';

/// Immutable state for the link-form controller.
final class LinkFormState extends Equatable {
  const LinkFormState({
    required this.submitting,
    this.remoteIdError = false,
    this.failure,
    this.linked = false,
    this.fieldErrors = const {},
  });

  factory LinkFormState.initial() => const LinkFormState(submitting: false);

  /// True while the link call is in flight.
  final bool submitting;

  /// True when client validation rejected an empty/blank remote_id.
  final bool remoteIdError;

  /// Last backend failure, or null when none.
  final Failure? failure;

  /// True once the link call succeeded (or ALREADY_LINKED was returned).
  final bool linked;

  /// Form-field keys that failed client-side required validation (multi-field
  /// forms). Empty when all fields pass or validation has not run yet.
  final Set<String> fieldErrors;

  LinkFormState copyWith({
    bool? submitting,
    bool? remoteIdError,
    Failure? failure,
    bool? linked,
    Set<String>? fieldErrors,
    bool clearFailure = false,
    bool clearRemoteIdError = false,
    bool clearFieldErrors = false,
  }) => LinkFormState(
    submitting: submitting ?? this.submitting,
    remoteIdError: clearRemoteIdError
        ? false
        : (remoteIdError ?? this.remoteIdError),
    failure: clearFailure ? null : (failure ?? this.failure),
    linked: linked ?? this.linked,
    fieldErrors: clearFieldErrors
        ? const {}
        : (fieldErrors ?? this.fieldErrors),
  );

  @override
  List<Object?> get props => [
    submitting,
    remoteIdError,
    failure,
    linked,
    fieldErrors,
  ];
}

@riverpod
class LinkFormController extends _$LinkFormController {
  @override
  LinkFormState build(Platform platform) => LinkFormState.initial();

  /// Validates each entry in [fields]; any whose trimmed value is empty is
  /// added to [LinkFormState.fieldErrors] and the backend is not called.
  /// On success, links [platform] via the platform's wire body builder
  /// (passing the trimmed [fields] as formInput), invalidates
  /// [myConnectionsProvider], sets [LinkFormState.linked], and fires the
  /// per-platform sync so the card populates automatically — reusing the
  /// cooldown-aware [ConnectionActionsController.refresh] path.
  /// The widget owns the TextEditingControllers and is never reset here.
  Future<void> submitFields(Map<String, String> fields) async {
    final blanks = fields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toSet();
    if (blanks.isNotEmpty) {
      state = state.copyWith(fieldErrors: blanks, clearFailure: true);
      return;
    }

    state = state.copyWith(
      submitting: true,
      clearFailure: true,
      clearFieldErrors: true,
    );

    final trimmed = {for (final e in fields.entries) e.key: e.value.trim()};
    final repo = ref.read(connectionsRepositoryProvider);
    final result = await repo.link(platform: platform, formInput: trimmed);

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        state = state.copyWith(submitting: false, failure: failure);
      },
      (_) {
        ref.invalidate(myConnectionsProvider);
        state = state.copyWith(
          submitting: false,
          linked: true,
          clearFailure: true,
          clearFieldErrors: true,
        );
        // Auto-populate the card: reuse the per-platform refresh so its
        // cooldown handling and card/connection invalidation are not bypassed.
        // Fire-and-forget — the tile owns the refreshing spinner; the link
        // form's submitting flag must not extend through the sync.
        unawaited(
          ref
              .read(connectionActionsControllerProvider(platform).notifier)
              .refresh(),
        );
      },
    );
  }

  /// Validates [remoteId] and links [platform]. On success, invalidates
  /// [myConnectionsProvider], sets [LinkFormState.linked], and fires the
  /// per-platform sync so the card populates automatically — reusing the
  /// cooldown-aware [ConnectionActionsController.refresh] path. On
  /// [InputFailure], preserves the typed input (the widget owns the
  /// TextEditingController and is never reset here). State is isolated per
  /// [platform] (this controller is a family), so forms rendered side by side
  /// never share submitting / error / linked flags.
  Future<void> submit({required String remoteId}) async {
    // Client-side validation — blank input never reaches the backend.
    if (remoteId.trim().isEmpty) {
      state = state.copyWith(remoteIdError: true, clearFailure: true);
      return;
    }

    state = state.copyWith(
      submitting: true,
      clearFailure: true,
      clearRemoteIdError: true,
    );

    final repo = ref.read(connectionsRepositoryProvider);
    final result = await repo.link(
      platform: platform,
      formInput: {'remote_id': remoteId.trim()},
    );

    if (!ref.mounted) return;

    result.fold(
      (failure) {
        state = state.copyWith(submitting: false, failure: failure);
      },
      (_) {
        ref.invalidate(myConnectionsProvider);
        state = state.copyWith(
          submitting: false,
          linked: true,
          clearFailure: true,
        );
        // Auto-populate the card: reuse the per-platform refresh so its
        // cooldown handling and card/connection invalidation are not bypassed.
        // Fire-and-forget — the tile owns the refreshing spinner; the link
        // form's submitting flag must not extend through the sync.
        unawaited(
          ref
              .read(connectionActionsControllerProvider(platform).notifier)
              .refresh(),
        );
      },
    );
  }
}
