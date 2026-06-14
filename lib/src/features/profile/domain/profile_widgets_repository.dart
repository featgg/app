import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../connections/domain/connection.dart';
import 'profile_widget.dart';

/// Reads and mutates the signed-in owner's `profile_widgets` arrangement.
/// All methods return `Either<Failure, T>`; the Shape-2 SDK errors are mapped
/// to [Failure] subtypes in the implementation.
abstract interface class ProfileWidgetsRepository {
  /// Owner's widgets ordered by position. Right([]) when none.
  Future<Either<Failure, List<ProfileWidget>>> fetchMyWidgets();

  /// Inserts a platform widget at [position] with [size], enabled.
  Future<Either<Failure, ProfileWidget>> addPlatformWidget({
    required Platform platform,
    required int position,
    required ProfileWidgetSize size,
  });

  /// Deletes the owner's widget [id].
  Future<Either<Failure, Unit>> removeWidget(String id);

  /// Sets the size (`settings.size`) for [id].
  Future<Either<Failure, Unit>> setSize(String id, ProfileWidgetSize size);

  /// Persists a new ordering: [orderedIds] in target position order.
  Future<Either<Failure, Unit>> reorder(List<String> orderedIds);
}
