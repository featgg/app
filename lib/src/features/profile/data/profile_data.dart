/// Data layer of the profile feature: repository implementation and DI providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/observability/observability.dart';
import '../../../core/supabase/supabase.dart';
import '../domain/avatar_repository.dart';
import '../domain/profile_repository.dart';
import 'avatar_repository_impl.dart';
import 'profile_repository_impl.dart';
import 'supabase_avatar_upload_source.dart';
import 'supabase_profile_data_source.dart';

/// Builds the concrete profile repository from its Riverpod dependencies.
/// Called only at the composition root to override the domain seam.
ProfileRepository buildProfileRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepositoryImpl(
    SupabaseProfileDataSource(client),
    () => client.auth.currentUser?.id,
    ref.watch(crashReporterProvider),
  );
}

/// Builds the concrete avatar repository from its Riverpod dependencies.
/// Called only at the composition root to override the domain seam.
AvatarRepository buildAvatarRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return AvatarRepositoryImpl(
    SupabaseAvatarUploadSource(client),
    ref.watch(crashReporterProvider),
  );
}
