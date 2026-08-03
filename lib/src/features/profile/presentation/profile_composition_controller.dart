import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../connections/domain/connection.dart';
import '../domain/art_framing.dart';
import '../domain/profile.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_composition.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_providers.dart';
import '../domain/profile_widgets_providers.dart';
import '../domain/profile_widget.dart';
import 'profile_provider.dart';
import 'profile_widgets_provider.dart';

part 'profile_composition_controller.g.dart';

/// The edit session's working state — one session over the whole profile, not
/// just its cards. [working] is the layout being edited and [draft] the identity
/// being edited; [saved] and [savedDraft] are what each was last known to be
/// persisted as. [saveFailed] is a one-shot flag the owner wrapper listens on to
/// show a failure snackbar. [hasPersisted] records whether this session has
/// committed a save — the authoritative "the controller knows the persisted
/// layout" signal, true even when that layout is empty (a cleared composition).
///
/// [draft] and [savedDraft] are null until a session opens, since there is
/// nothing to edit against outside one.
final class ProfileCompositionState extends Equatable {
  const ProfileCompositionState({
    this.editing = false,
    this.working = const [],
    this.saved = const [],
    this.draft,
    this.savedDraft,
    this.framings = const {},
    this.savedFramings = const {},
    this.framingId,
    this.acquiredId,
    this.saving = false,
    this.saveFailed = false,
    this.hasPersisted = false,
  });

  final bool editing;
  final List<ProfileLayoutRow> working;
  final List<ProfileLayoutRow> saved;
  final ProfileEdit? draft;
  final ProfileEdit? savedDraft;

  /// Framings the owner has moved this session, by widget id, and what each was
  /// when they first moved it. Only touched cards appear; every other card
  /// renders the framing its widget already carries.
  final Map<String, ArtFraming> framings;
  final Map<String, ArtFraming> savedFramings;

  /// The card whose picture is being moved right now, or null.
  ///
  /// Session state rather than the editor's own, because it reaches past the
  /// editor: while a picture is being moved the page must not scroll under the
  /// finger, and the page is not the editor's to silence.
  final String? framingId;

  /// The card the last acquire folded in, or null. One-shot: the editor consumes
  /// it to bring the new card into view and clears it immediately, so no rebuild
  /// can replay the reveal.
  final String? acquiredId;

  final bool saving;
  final bool saveFailed;
  final bool hasPersisted;

  /// Whether the arrangement diverges from what was last persisted.
  bool get layoutIsDirty => !listEquals(working, saved);

  /// Whether the identity diverges from what was last persisted.
  bool get draftIsDirty => draft != null && draft != savedDraft;

  /// Whether any picture has been moved off where it was.
  bool get framingIsDirty => !mapEquals(framings, savedFramings);

  /// Whether the session has anything to write — gates the save.
  bool get isDirty => layoutIsDirty || draftIsDirty || framingIsDirty;

  ProfileCompositionState copyWith({
    bool? editing,
    List<ProfileLayoutRow>? working,
    List<ProfileLayoutRow>? saved,
    ProfileEdit? draft,
    ProfileEdit? savedDraft,
    Map<String, ArtFraming>? framings,
    Map<String, ArtFraming>? savedFramings,
    String? Function()? framingId,
    String? Function()? acquiredId,
    bool? saving,
    bool? saveFailed,
    bool? hasPersisted,
  }) => ProfileCompositionState(
    editing: editing ?? this.editing,
    working: working ?? this.working,
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    savedDraft: savedDraft ?? this.savedDraft,
    framings: framings ?? this.framings,
    savedFramings: savedFramings ?? this.savedFramings,
    // Nullary so leaving the mode can be expressed at all.
    framingId: framingId != null ? framingId() : this.framingId,
    acquiredId: acquiredId != null ? acquiredId() : this.acquiredId,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
    hasPersisted: hasPersisted ?? this.hasPersisted,
  );

  @override
  List<Object?> get props => [
    editing,
    working,
    saved,
    draft,
    savedDraft,
    framings,
    savedFramings,
    framingId,
    acquiredId,
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

/// Drives the in-place edit session: edit on/off, the working vs saved layout
/// and identity, dirty tracking, and a save with rollback.
@riverpod
class ProfileComposition extends _$ProfileComposition {
  // Whether a card supports a full row; rebuilt on each edit-mode entry.
  CardSizeSupport _supportsFull = (_) => true;

  @override
  ProfileCompositionState build() => const ProfileCompositionState();

  /// Enter edit mode seeded from [profile] and the owner's [widgets].
  /// Normalizes the layout seed against the known ids so a deleted-widget id can
  /// never reach the save, and captures the full-size predicate for the
  /// mutations.
  void startEditing(Profile profile, List<ProfileWidget> widgets) {
    final byId = {for (final w in widgets) w.id: w};
    _captureSupport(byId);
    // Once this session has persisted, its own `saved` is authoritative — right
    // after a save it holds the just-persisted layout while the profile refetch
    // is still in flight, so a stale passed layout must not override it (in
    // either direction — reviving a cleared layout or wiping a saved one). On a
    // fresh mount nothing has persisted and the profile is authoritative.
    final seed = state.hasPersisted ? state.saved : profile.layout;
    // A profile whose owner never arranged one opens on what the read view is
    // already showing. Seeding empty here would open an empty editor over a
    // profile full of cards.
    final normalized = seed.isEmpty && !state.hasPersisted
        ? defaultLayoutFor(widgets, supportsFull: _supportsFull)
        : normalizeLayout(seed, byId.keys.toSet());
    final draft = _draftOf(profile);
    state = state.copyWith(
      editing: true,
      working: normalized,
      // Unarranged opens dirty on purpose: the arrangement it shows is derived,
      // not persisted, so Save has something to write.
      saved: seed.isEmpty && !state.hasPersisted ? const [] : normalized,
      // The identity always seeds from the live profile, including the two
      // fields edited in settings rather than here. An update writes every
      // field, so a session opened on a stale value would write it back —
      // which is why the entry point stays closed while the profile refetches.
      draft: draft,
      savedDraft: draft,
      framings: const {},
      savedFramings: const {},
      framingId: () => null,
      // A reveal the previous session never consumed dies with it, so opening
      // the editor again does not scroll to a card acquired long ago.
      acquiredId: () => null,
      saveFailed: false,
    );
  }

  /// Records where the owner moved the picture on the widget [widgetId], whose
  /// stored framing is [was]. Kept in the session, written by Save, dropped by
  /// Cancel — the same contract as every other edit here.
  void setFraming(
    String widgetId, {
    required ArtFraming was,
    required ArtFraming now,
  }) {
    if (state.saving || !state.editing) return;
    state = state.copyWith(
      framings: {...state.framings, widgetId: now},
      // Recorded on the first move only, so the comparison Save makes is
      // against where the picture started, not where the last drag left it.
      savedFramings: state.savedFramings.containsKey(widgetId)
          ? state.savedFramings
          : {...state.savedFramings, widgetId: was},
    );
  }

  /// The writable fields of [profile], trimmed the way the editors produce them
  /// so an untouched session never reads as dirty.
  ProfileEdit _draftOf(Profile profile) {
    final bio = (profile.bio ?? '').trim();
    return ProfileEdit(
      displayName: profile.displayName.trim(),
      bio: bio.isEmpty ? null : bio,
      theme: profile.theme,
      privacy: profile.privacy,
      featuredPlatform: profile.featuredPlatform,
      headerPlatform: profile.headerPlatform,
    );
  }

  /// Replace the name and bio from the identity sheet. The sheet validates
  /// before applying, so the draft only ever holds a submittable edit.
  void editIdentity({required String displayName, required String? bio}) =>
      _amend(
        (draft) => draft.copyWith(displayName: displayName, bio: () => bio),
      );

  /// Pick the profile's theme. Applies to the draft only, so the render
  /// re-tints on the spot and nothing is written until the session is saved.
  void selectTheme(ProfileTheme theme) =>
      _amend((draft) => draft.copyWith(theme: theme));

  /// Pick which platform's art the cover shows, or null for automatic.
  void selectHeaderPlatform(Platform? platform) =>
      _amend((draft) => draft.copyWith(headerPlatform: () => platform));

  // Saving-gated like the layout mutations: a save has snapshotted the draft and
  // must persist exactly that.
  void _amend(ProfileEdit Function(ProfileEdit draft) change) {
    final draft = state.draft;
    if (state.saving || draft == null) return;
    state = state.copyWith(draft: change(draft));
  }

  /// Folds any enabled [widgets] not already referenced by the working layout in
  /// at its end, each seeded by the same rule as the bootstrap (full-supporting →
  /// [FullRow], half-only → single-slot [PairRow] orphan; defensive, as no current
  /// archetype is half-only). Driven reactively off
  /// each refetch of the owner's widgets while composing, so a card acquired from
  /// any channel becomes placeable; the acquired row makes the composition dirty
  /// and Save persists it. Recaptures the full-size predicate from [widgets] so a
  /// newly-acquired half-only card seeds correctly. Idempotent: a widget already
  /// placed is skipped, so repeated emissions never duplicate a row. Only runs
  /// while editing and never mid-save — a save has snapshotted `working` and must
  /// persist exactly that, so an emission arriving mid-save is dropped rather than
  /// mutating the sent snapshot.
  void appendUnplacedWidgets(List<ProfileWidget> widgets) {
    if (!state.editing || state.saving) return;
    final byId = {for (final w in widgets) w.id: w};
    _captureSupport(byId);
    final placed = <String>{};
    for (final row in state.working) {
      switch (row) {
        case FullRow(:final cardId):
          placed.add(cardId);
        case PairRow(:final left, :final right):
          if (left != null) placed.add(left);
          if (right != null) placed.add(right);
      }
    }
    final additions = [
      for (final w in widgets)
        if (w.isEnabled && !placed.contains(w.id)) w,
    ]..sort((a, b) => a.position.compareTo(b.position));
    if (additions.isEmpty) return;
    state = state.copyWith(
      working: [
        ...state.working,
        for (final w in additions)
          _supportsFull(w.id) ? FullRow(w.id) : PairRow(left: w.id),
      ],
      // The first of the batch: the appended cards are contiguous, so its top is
      // where the run of new rows begins and where the eye should land.
      acquiredId: () => additions.first.id,
    );
  }

  /// Clears the pending reveal once the editor has acted on it, so the scroll
  /// and its mark fire exactly once per acquire.
  void acknowledgeAcquired() {
    if (state.acquiredId == null) return;
    state = state.copyWith(acquiredId: () => null);
  }

  // Records whether each card supports a full row, from the owner's widgets. Full
  // is the safe default for an unknown id (every archetype supports full). It
  // seeds a card that has no placement yet — the bootstrap layout and a card
  // acquired mid-session — which is the only case with no row type to read the
  // size from; the editor rows read half-support locally.
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
  void cancelEditing() => state = state.copyWith(
    editing: false,
    working: state.saved,
    draft: state.savedDraft,
    framings: const {},
    savedFramings: const {},
    framingId: () => null,
  );

  /// Puts [widgetId]'s picture into the framing mode, or null to leave it. One
  /// at a time: entering on a second card hands the mode over.
  void setFramingTarget(String? widgetId) {
    if (state.saving || !state.editing) return;
    if (state.framingId == widgetId) return;
    state = state.copyWith(framingId: () => widgetId);
  }

  void onGapDrop(String id, int gapIndex) {
    // A save snapshots the working layout; ignore edits until it resolves so a
    // mid-flight change can never be silently folded into `saved` unsent.
    if (state.saving) return;
    state = state.copyWith(working: moveToGap(state.working, id, gapIndex));
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

  /// Drops [id] from the working layout (marks dirty). Saving-gated like the
  /// other editor mutations, so a delete cannot mutate an in-flight save
  /// snapshot. The acquired widget itself is deleted by the caller via
  /// ProfileWidgetsController, mirroring how an acquired card is created there
  /// and folded in on invalidate.
  void removeCardFromLayout(String id) {
    if (state.saving) return;
    state = state.copyWith(working: removeCard(state.working, id));
  }

  /// Persist whatever the session changed — the identity, the arrangement, or
  /// both. Nothing to save (not dirty) just exits edit mode. On any failure edit
  /// mode stays open and [saveFailed] flips so the wrapper surfaces the error.
  ///
  /// The identity goes first because it is the cheaper thing to lose: a failed
  /// arrangement is redone with a few drags, whereas the layout rolling back
  /// after the identity was already written would leave the two halves of one
  /// Done disagreeing about what happened. A failed identity write keeps the
  /// draft rather than rolling it back — typed text has no other copy.
  Future<void> save() async {
    if (!state.isDirty) {
      state = state.copyWith(editing: false);
      return;
    }
    final draft = state.draft;
    final savingDraft = state.draftIsDirty && draft != null;
    final savingLayout = state.layoutIsDirty;
    final savingFramings = state.framingIsDirty;
    state = state.copyWith(saving: true, saveFailed: false);
    final repo = ref.read(profileRepositoryProvider);

    if (savingDraft) {
      final result = await repo.updateMyProfile(draft);
      // autoDispose: never write state or invalidate after the notifier has been
      // disposed (the owner may leave the screen while the save is in flight).
      if (!ref.mounted) return;
      if (result.isLeft()) {
        state = state.copyWith(saving: false, saveFailed: true);
        return;
      }
      state = state.copyWith(savedDraft: draft);
    }

    if (savingLayout) {
      final result = await repo.setMyLayout(state.working);
      if (!ref.mounted) return;
      if (result.isLeft()) {
        // The identity may already be written; reconcile the render to it rather
        // than leaving the screen showing a value the server no longer holds.
        if (savingDraft) ref.invalidate(profileProvider);
        state = state.copyWith(
          saving: false,
          saveFailed: true,
          working: state.saved,
        );
        return;
      }
    }

    if (savingFramings) {
      final byId = {
        for (final w in ref.read(ownerProfileWidgetsProvider).value ?? const [])
          w.id: w,
      };
      final widgetsRepo = ref.read(profileWidgetsRepositoryProvider);
      for (final entry in state.framings.entries) {
        if (entry.value == state.savedFramings[entry.key]) continue;
        final target = byId[entry.key];
        // A card deleted in the same session has no framing left to write.
        if (target == null) continue;
        final result = await widgetsRepo.setArtFraming(target, entry.value);
        if (!ref.mounted) return;
        if (result.isLeft()) {
          if (savingDraft) ref.invalidate(profileProvider);
          ref.invalidate(ownerProfileWidgetsProvider);
          state = state.copyWith(saving: false, saveFailed: true);
          return;
        }
      }
      ref.invalidate(ownerProfileWidgetsProvider);
    }

    // The profile read reconciles to what was persisted. `hasPersisted` marks
    // that this session now knows the persisted state (save or clear), so the
    // gate/seed trust `saved` over the still-stale profile refetch.
    ref.invalidate(profileProvider);
    state = state.copyWith(
      saving: false,
      editing: false,
      saved: state.working,
      framings: const {},
      savedFramings: const {},
      framingId: () => null,
      hasPersisted: true,
    );
  }

  /// Clear the one-shot save-failure flag after the wrapper has shown it.
  void acknowledgeSaveFailure() => state = state.copyWith(saveFailed: false);
}
