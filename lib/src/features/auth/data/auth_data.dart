/// Data layer of the auth feature: repository implementation and DI providers.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/observability/observability.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_impl.dart';

part 'auth_data.g.dart';

@riverpod
GoTrueClient goTrueClient(Ref ref) => Supabase.instance.client.auth;

/// Builds the concrete repository from its Riverpod dependencies. Called only
/// at the composition root to override the domain seam; not a provider itself.
AuthRepository buildAuthRepository(Ref ref) => AuthRepositoryImpl(
  ref.watch(goTrueClientProvider),
  ref.watch(crashReporterProvider),
);
