import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_domain.dart';

part 'auth_status_provider.g.dart';

/// Reactive auth status the router gates on.
///
/// Yields [AuthStatus.currentStatus] immediately so the router redirect is
/// correct on the first frame (restored session after restart), then forwards
/// every subsequent [AuthRepository.statusChanges] emission.
@riverpod
class AuthStatusNotifier extends _$AuthStatusNotifier {
  @override
  Stream<AuthStatus> build() async* {
    final repo = ref.watch(authRepositoryProvider);
    yield repo.currentStatus();
    yield* repo.statusChanges();
  }
}
