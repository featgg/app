import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import 'composed_card.dart';
import 'data_menu_selection.dart';
import 'profile_widget.dart';
import 'template_catalog.dart';

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

  /// Inserts a template widget for [templateId] at [position] with [size],
  /// enabled and with no slots filled yet (`platform` null).
  Future<Either<Failure, ProfileWidget>> addTemplateWidget({
    required String templateId,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Inserts a composed-card widget at [position] with [size], enabled and with
  /// no items picked yet (`platform` null).
  Future<Either<Failure, ProfileWidget>> addComposedWidget({
    required int position,
    required ProfileWidgetSize size,
  });

  /// Deletes the owner's widget [id].
  Future<Either<Failure, Unit>> removeWidget(String id);

  /// Sets the size (`settings.size`) for [id].
  Future<Either<Failure, Unit>> setSize(String id, ProfileWidgetSize size);

  /// Persists the data-menu [selection] for [id], merged into the existing
  /// `settings` envelope alongside [size] (preserved verbatim). Additive: it
  /// keeps `schema_version` and `size` and never changes the grid behavior.
  Future<Either<Failure, Unit>> setDataMenuSelection(
    String id,
    ProfileWidgetSize size,
    DataMenuSelection selection,
  );

  /// Persists the template [fill] for [id], merged into the existing `settings`
  /// envelope alongside [size] (preserved verbatim). Additive: it keeps
  /// `schema_version` and `size`.
  Future<Either<Failure, Unit>> setTemplateFill(
    String id,
    ProfileWidgetSize size,
    TemplateFill fill,
  );

  /// Persists the composed-card [fill] for [id], merged into the existing
  /// `settings` envelope alongside [size] (preserved verbatim). Additive: it
  /// keeps `schema_version` and `size`.
  Future<Either<Failure, Unit>> setComposedFill(
    String id,
    ProfileWidgetSize size,
    ComposedFill fill,
  );

  /// Persists a new ordering: [orderedIds] in target position order.
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds);
}
