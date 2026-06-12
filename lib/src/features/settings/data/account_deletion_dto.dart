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
