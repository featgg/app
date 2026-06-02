import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_repository.dart';

part 'auth_providers.g.dart';

/// DI seam for the auth repository. The concrete [AuthRepositoryImpl] is an
/// outward-layer type, so it is supplied as a composition-root override
/// (see `main.dart`); this declaration keeps the symbol in `domain` so
/// `presentation` depends on the interface, never the implementation.
@riverpod
AuthRepository authRepository(Ref ref) =>
    throw UnimplementedError('authRepositoryProvider must be overridden');
