import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'account_deletion_repository.dart';

part 'settings_providers.g.dart';

/// DI seam for the account-deletion repository. The concrete implementation is
/// supplied as a composition-root override in `main.dart`.
@riverpod
AccountDeletionRepository accountDeletionRepository(Ref ref) =>
    throw UnimplementedError(
      'accountDeletionRepositoryProvider must be overridden',
    );
