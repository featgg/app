import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/domain/auth_providers.dart';

part 'sign_out_controller.g.dart';

/// Signs the user out through the auth repository, owning the in-flight state so
/// the screen can disable the action while it runs — a second tap cannot start a
/// duplicate sign-out. A Left surfaces as AsyncError for the screen to localize;
/// on success the auth-status stream drives the redirect to sign-in, so this
/// controller performs no navigation.
@riverpod
class SignOutController extends _$SignOutController {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) return;
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => state = const AsyncData(null),
    );
  }
}
