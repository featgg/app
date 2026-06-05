import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'avatar_repository.dart';

part 'avatar_providers.g.dart';

/// DI seam for the avatar repository. The concrete [AvatarRepositoryImpl] is
/// supplied as a composition-root override (see `main.dart`); this declaration
/// keeps the symbol in `domain` so `presentation` depends on the interface,
/// never the implementation.
@riverpod
AvatarRepository avatarRepository(Ref ref) =>
    throw UnimplementedError('avatarRepositoryProvider must be overridden');
