import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_deletion_data_source.dart';
import 'account_deletion_dto.dart';

final class SupabaseAccountDeletionDataSource
    implements AccountDeletionDataSource {
  SupabaseAccountDeletionDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<DeletionRequestDto> requestDeletion() async {
    final response = await _client.functions
        .invoke(
          'delete-account',
          method: HttpMethod.post,
          body: {'action': 'request'},
        )
        .timeout(const Duration(seconds: 15));
    return DeletionRequestDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<DeletionConfirmDto> confirmDeletion(String code) async {
    final response = await _client.functions
        .invoke(
          'delete-account',
          method: HttpMethod.post,
          body: {'action': 'confirm', 'otp': code},
        )
        .timeout(const Duration(seconds: 15));
    return DeletionConfirmDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<DeletionCancelDto> cancelDeletion() async {
    final response = await _client.functions
        .invoke(
          'cancel-deletion',
          method: HttpMethod.post,
          body: <String, dynamic>{},
        )
        .timeout(const Duration(seconds: 10));
    return DeletionCancelDto.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
