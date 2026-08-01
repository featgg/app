import 'package:json_annotation/json_annotation.dart';

part 'account_deletion_dto.g.dart';

/// Wire shape for a successful deletion-request response (`{success, otp_sent}`).
@JsonSerializable(createToJson: false)
final class DeletionRequestDto {
  const DeletionRequestDto({required this.success, required this.otpSent});

  final bool success;
  @JsonKey(name: 'otp_sent')
  final bool otpSent;

  factory DeletionRequestDto.fromJson(Map<String, dynamic> json) =>
      _$DeletionRequestDtoFromJson(json);
}

/// Wire shape for a successful deletion-confirm response
/// (`{success, deletion_scheduled_at}`).
@JsonSerializable(createToJson: false)
final class DeletionConfirmDto {
  const DeletionConfirmDto({
    required this.success,
    required this.deletionScheduledAt,
  });

  final bool success;
  @JsonKey(name: 'deletion_scheduled_at')
  final String deletionScheduledAt;

  factory DeletionConfirmDto.fromJson(Map<String, dynamic> json) =>
      _$DeletionConfirmDtoFromJson(json);
}

/// Wire shape for a successful deletion-cancel response
/// (`{success, cancelled}`).
@JsonSerializable(createToJson: false)
final class DeletionCancelDto {
  const DeletionCancelDto({required this.success, required this.cancelled});

  final bool success;
  final bool cancelled;

  factory DeletionCancelDto.fromJson(Map<String, dynamic> json) =>
      _$DeletionCancelDtoFromJson(json);
}

/// Wire shape for the owner-scoped deletion-status read. The operation returns
/// the caller's pending-deletion timestamp as a bare ISO-8601 JSON string, or
/// null when nothing is pending — not an envelope — so this DTO is hand-written
/// rather than generated from a JSON object.
final class DeletionStatusDto {
  const DeletionStatusDto({required this.requestedAt});

  final String? requestedAt;

  /// [payload] is the operation's raw return value. Any other shape is a fault:
  /// it must never be interpreted as "no deletion pending", because that would
  /// silently hide a pending deletion from its owner.
  factory DeletionStatusDto.fromPayload(Object? payload) => switch (payload) {
    null => const DeletionStatusDto(requestedAt: null),
    final String s => DeletionStatusDto(requestedAt: s),
    // The type, never the value: this message reaches the crash reporter and
    // the value is the caller's own deletion timestamp.
    _ => throw FormatException(
      'unexpected deletion-status payload type: ${payload.runtimeType}',
    ),
  };
}
