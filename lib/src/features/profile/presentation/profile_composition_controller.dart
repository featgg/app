import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_providers.dart';
import '../domain/profile_widget.dart';
import 'profile_provider.dart';

part 'profile_composition_controller.g.dart';

/// The composition editor's working state. [working] is the layout being edited;
/// [saved] is the last-persisted layout the editor rolls back to on failure or
/// cancel. [saveFailed] is a one-shot flag the owner wrapper listens on to show
/// a failure snackbar. [hasPersisted] records whether this session has committed
/// a save — the authoritative "the controller knows the persisted layout" signal,
/// true even when that layout is empty (a cleared composition).
final class ProfileCompositionState extends Equatable {
  const ProfileCompositionState({
    this.editing = false,
    this.working = const [],
    this.saved = const [],
    this.saving = false,
    this.saveFailed = false,
    this.hasPersisted = false,
  });

  final bool editing;
  final List<ProfileLayoutRow> working;
  final List<ProfileLayoutRow> saved;
  final bool saving;
  final bool saveFailed;
  final bool hasPersisted;

  /// Whether the working layout diverges from the saved one — gates the save.
  bool get isDirty => !listEquals(working, saved);

  ProfileCompositionState copyWith({
    bool? editing,
    List<ProfileLayoutRow>? working,
    List<ProfileLayoutRow>? saved,
    bool? saving,
    bool? saveFailed,
    bool? hasPersisted,
  }) => ProfileCompositionState(
    editing: editing ?? this.editing,
    working: working ?? this.working,
    saved: saved ?? this.saved,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
    hasPersisted: hasPersisted ?? this.hasPersisted,
  );

  @override
  List<Object?> get props => [
    editing,
    working,
    saved,
    saving,
    saveFailed,
    hasPersisted,
  ];
}

/// Whether the profile screen shows the personalization surface (vs the legacy
/// grid). While [editing], always. Once the session has persisted
/// ([hasPersisted]), its own [savedIsNotEmpty] is authoritative even through the
/// profile refetch — so a cleared composition (persisted-but-empty) routes to the
/// grid immediately and a saved one holds, regardless of a still-stale
/// [profileHasLayout]. A fresh controller (nothing persisted) defers to the
/// profile.
bool showsCompositionSurface({
  required bool editing,
  required bool hasPersisted,
  required bool savedIsNotEmpty,
  required bool profileHasLayout,
}) => editing || (hasPersisted ? savedIsNotEmpty : profileHasLayout);

/// Drives the in-place composition editor: edit on/off, the working vs saved
/// layout, dirty tracking, and an optimistic save with rollback.
@riverpod
class ProfileComposition extends _$ProfileComposition {
  // Whether a card supports a full row; rebuilt on each edit-mode entry.
  CardSizeSupport _supportsFull = (_) => true;

  @override
  ProfileCompositionState build() => const ProfileCompositionState();

  /// Enter edit mode seeded from the current [layout] and the owner's [widgets].
  /// Normalizes the seed against the known ids so a deleted-widget id can never
  /// reach the save, and captures the full-size predicate for the mutations.
  void startEditing(
    List<ProfileLayoutRow> layout,
    List<ProfileWidget> widgets,
  ) {
    final byId = {for (final w in widgets) w.id: w};
    _captureSupport(byId);
    // Once this session has persisted, its own `saved` is authoritative — right
    // after a save it holds the just-persisted layout while the profile refetch
    // is still in flight, so a stale passed [layout] must not override it (in
    // either direction — reviving a cleared layout or wiping a saved one). On a
    // fresh mount nothing has persisted and [layout] is authoritative.
    final seed = state.hasPersisted ? state.saved : layout;
    final normalized = normalizeLayout(seed, byId.keys.toSet());
    state = state.copyWith(
      editing: true,
      working: normalized,
      saved: normalized,
      saveFailed: false,
    );
  }

  /// Enter edit mode from a not-yet-composed profile, seeding a bootstrap working
  /// layout of every enabled widget as a full row in display order (disabled
  /// widgets are excluded; no auto-pairing). `saved` stays empty — the persisted
  /// state — so a plain Save persists the bootstrap and Cancel keeps nothing.
  void startComposing(List<ProfileWidget> widgets) {
    final byId = {for (final w in widgets) w.id: w};
    _captureSupport(byId);
    final enabled = [
      for (final w in widgets)
        if (w.isEnabled) w,
    ]..sort((a, b) => a.position.compareTo(b.position));
    state = state.copyWith(
      editing: true,
      // A half-only archetype (e.g. Rank) can't seed as a full row; it bootstraps
      // as a single-slot pair (centered orphan) so its slot is legal from the
      // start, matching the moveToGap rule.
      working: [
        for (final w in enabled)
          _supportsFull(w.id) ? FullRow(w.id) : PairRow(left: w.id),
      ],
      saved: const [],
      saveFailed: false,
    );
  }

  // Records whether each card supports a full row, from the owner's widgets. Full
  // is the safe default for an unknown id (every archetype supports full); only
  // moveToGap needs it, the editor rows read half-support locally.
  void _captureSupport(Map<String, ProfileWidget> byId) {
    _supportsFull = (id) {
      final widget = byId[id];
      return widget == null ||
          supportedSizes(
            archetypeForWidget(widget),
          ).contains(ProfileCardSize.full);
    };
  }

  /// Leave edit mode discarding any working changes.
  void cancelEditing() =>
      state = state.copyWith(editing: false, working: state.saved);

  void onGapDrop(String id, int gapIndex) {
    // A save snapshots the working layout; ignore edits until it resolves so a
    // mid-flight change can never be silently folded into `saved` unsent.
    if (state.saving) return;
    state = state.copyWith(
      working: moveToGap(
        state.working,
        id,
        gapIndex,
        supportsFull: _supportsFull,
      ),
    );
  }

  void onPairDrop(String dragId, String targetId, DropSide side) {
    if (state.saving) return;
    state = state.copyWith(
      working: pairBeside(state.working, dragId, targetId, side),
    );
  }

  void onToggleSize(String id) {
    if (state.saving) return;
    state = state.copyWith(working: toggleSize(state.working, id));
  }

  /// Persist the working layout. Nothing to save (not dirty) just exits edit
  /// mode. On any failure the working layout rolls back to the saved one, edit
  /// mode stays open, and [saveFailed] flips so the wrapper surfaces the error.
  Future<void> save() async {
    if (!state.isDirty) {
      state = state.copyWith(editing: false);
      return;
    }
    state = state.copyWith(saving: true, saveFailed: false);
    final result = await ref
        .read(profileRepositoryProvider)
        .setMyLayout(state.working);
    // autoDispose: never write state or invalidate after the notifier has been
    // disposed (the owner may leave the screen while the save is in flight).
    if (!ref.mounted) return;
    result.fold(
      (_) => state = state.copyWith(
        saving: false,
        saveFailed: true,
        working: state.saved,
      ),
      (_) {
        // The profile read reconciles to the persisted layout. `hasPersisted`
        // marks that this session now knows the persisted state (save or clear),
        // so the gate/seed trust `saved` over the still-stale profile refetch.
        ref.invalidate(profileProvider);
        state = state.copyWith(
          saving: false,
          editing: false,
          saved: state.working,
          hasPersisted: true,
        );
      },
    );
  }

  /// Clear the one-shot save-failure flag after the wrapper has shown it.
  void acknowledgeSaveFailure() => state = state.copyWith(saveFailed: false);
}
