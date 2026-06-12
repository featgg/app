import 'package:equatable/equatable.dart';

/// The result of a successful deletion confirmation: the backend has scheduled
/// account deletion [scheduledAt] (7-day grace period from the time of confirm).
final class DeletionSchedule extends Equatable {
  const DeletionSchedule({required this.scheduledAt});

  /// UTC timestamp when the account is scheduled for deletion.
  final DateTime scheduledAt;

  @override
  List<Object?> get props => [scheduledAt];
}
