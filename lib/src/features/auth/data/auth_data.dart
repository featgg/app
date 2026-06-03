/// Data layer of the auth feature: repository implementation and DI providers.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env/env.dart';
import '../../../core/observability/observability.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_impl.dart';
import 'google_sign_in_client.dart';

part 'auth_data.g.dart';

@riverpod
GoTrueClient goTrueClient(Ref ref) => Supabase.instance.client.auth;

// keepAlive: the wrapper holds the process-wide GoogleSignIn singleton, which
// must be initialized exactly once; auto-dispose cycling would re-create it.
@Riverpod(keepAlive: true)
GoogleSignInClient googleSignInClient(Ref ref) =>
    PackageGoogleSignInClient(webClientId: Env.googleWebClientId);

/// Builds the concrete repository from its Riverpod dependencies. Called only
/// at the composition root to override the domain seam; not a provider itself.
AuthRepository buildAuthRepository(Ref ref) => AuthRepositoryImpl(
  ref.watch(goTrueClientProvider),
  ref.watch(crashReporterProvider),
  ref.watch(googleSignInClientProvider),
);
