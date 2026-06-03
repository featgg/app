import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'profile_repository.dart';

part 'profile_providers.g.dart';

/// DI seam for the profile repository. The concrete [ProfileRepositoryImpl] is
/// an outward-layer type, supplied as a composition-root override (see
/// `main.dart`); this declaration keeps the symbol in `domain` so
/// `presentation` depends on the interface, never the implementation.
@riverpod
ProfileRepository profileRepository(Ref ref) =>
    throw UnimplementedError('profileRepositoryProvider must be overridden');
