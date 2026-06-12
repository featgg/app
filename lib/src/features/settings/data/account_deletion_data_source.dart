import 'account_deletion_dto.dart';

/// Thin seam over the Supabase SDK for the account-deletion edge-function
/// calls. Extracted so tests can fake the SDK without constructing real network
/// clients. The repository is the only caller.
abstract interface class AccountDeletionDataSource {
  /// Requests deletion: sends `{"action":"request"}` to the deletion function.
  /// Returns [DeletionRequestDto] on 200. Throws on non-2xx or transport fault.
  Future<DeletionRequestDto> requestDeletion();

  /// Confirms deletion with [code]: sends `{"action":"confirm","otp":code}`.
  /// Returns [DeletionConfirmDto] on 200. Throws on non-2xx or transport fault.
  Future<DeletionConfirmDto> confirmDeletion(String code);

  /// Cancels a pending deletion: sends `{}` to the cancel function.
  /// Returns [DeletionCancelDto] on 200. Throws on non-2xx or transport fault.
  Future<DeletionCancelDto> cancelDeletion();
}
