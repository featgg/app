/// Data layer of the settings feature: DTOs, data sources, repository
/// implementations, and DI builder functions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/observability/observability.dart';
import '../../../core/supabase/supabase.dart';
import '../domain/account_deletion_repository.dart';
import 'account_deletion_repository_impl.dart';
import 'supabase_account_deletion_data_source.dart';

/// Builds the concrete account-deletion repository. Called at the composition
/// root to override the domain seam.
AccountDeletionRepository buildAccountDeletionRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return AccountDeletionRepositoryImpl(
    SupabaseAccountDeletionDataSource(client),
    ref.watch(crashReporterProvider),
  );
}
