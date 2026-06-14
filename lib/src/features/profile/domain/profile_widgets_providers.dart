import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'profile_widgets_repository.dart';

part 'profile_widgets_providers.g.dart';

/// DI seam for the profile-widgets repository. The concrete implementation is
/// an outward-layer type, supplied as a composition-root override (see
/// `main.dart`); this declaration keeps the symbol in `domain` so
/// `presentation` depends on the interface, never the implementation.
@riverpod
ProfileWidgetsRepository profileWidgetsRepository(Ref ref) =>
    throw UnimplementedError(
      'profileWidgetsRepositoryProvider must be overridden',
    );
