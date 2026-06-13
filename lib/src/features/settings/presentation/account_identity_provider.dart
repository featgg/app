import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/domain/auth_domain.dart';

part 'account_identity_provider.g.dart';

/// Settings-owned read seam for the signed-in account identity.
///
/// Synchronous derived provider over `authRepositoryProvider`, mirroring the
/// sibling privacy and deletion seams: the account section watches this instead
/// of reaching into the auth repository inside `build`. Synchronous because
/// `currentIdentity()` is an in-memory read of the restored session — there is
/// no loading state to model, so it yields `AccountIdentity?` directly rather
/// than through an `AsyncValue`.
@riverpod
AccountIdentity? accountIdentity(Ref ref) =>
    ref.watch(authRepositoryProvider).currentIdentity();
