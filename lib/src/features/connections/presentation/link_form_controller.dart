import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/connection.dart';
import '../domain/connections_providers.dart';
import 'connections_provider.dart';

part 'link_form_controller.g.dart';

/// Immutable state for the link-form controller.
final class LinkFormState extends Equatable {
  const LinkFormState({
    required this.submitting,
    this.remoteIdError = false,
    this.failure,
    this.linked = false,
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

  LinkFormState copyWith({
    bool? submitting,
    bool? remoteIdError,
    Failure? failure,
    bool? linked,
    bool clearFailure = false,
    bool clearRemoteIdError = false,
  }) => LinkFormState(
    submitting: submitting ?? this.submitting,
    remoteIdError: clearRemoteIdError
        ? false
        : (remoteIdError ?? this.remoteIdError),
    failure: clearFailure ? null : (failure ?? this.failure),
    linked: linked ?? this.linked,
  );

  @override
  List<Object?> get props => [submitting, remoteIdError, failure, linked];
}

@riverpod
class LinkFormController extends _$LinkFormController {
  @override
  LinkFormState build() => LinkFormState.initial();

  /// Validates [remoteId] and links the platform. On success, invalidates
  /// [myConnectionsProvider] and sets [LinkFormState.linked]. On
  /// [InputFailure], preserves the typed input (the widget owns the
  /// TextEditingController and is never reset here).
  Future<void> submit({
    required Platform platform,
    required String remoteId,
  }) async {
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
      },
    );
  }
}
