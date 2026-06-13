import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/bootstrap.dart';
import 'src/core/core.dart';
import 'src/features/auth/data/auth_data.dart';
import 'src/features/auth/domain/auth_domain.dart';
import 'src/features/connections/data/connections_data.dart';
import 'src/features/connections/domain/connections_providers.dart';
import 'src/features/connections/presentation/connections_presentation.dart';
import 'src/features/feed/data/feed_data.dart';
import 'src/features/feed/domain/feed_providers.dart';
import 'src/features/profile/data/profile_data.dart';
import 'src/features/profile/domain/profile_domain.dart';
import 'src/features/profile/presentation/avatar_picker.dart';
import 'src/features/settings/data/settings_data.dart';
import 'src/features/settings/domain/settings_domain.dart';

Future<void> main() async {
  await bootstrap(
    () => runApp(
      ProviderScope(
        observers: [const CrashReportingObserver(SentryCrashReporter())],
        overrides: [
          authRepositoryProvider.overrideWith(buildAuthRepository),
          profileRepositoryProvider.overrideWith(buildProfileRepository),
          profileWidgetsRepositoryProvider.overrideWith(
            buildProfileWidgetsRepository,
          ),
          avatarRepositoryProvider.overrideWith(buildAvatarRepository),
          avatarPickerProvider.overrideWithValue(
            const CropYourImageAvatarPicker(),
          ),
          connectionsRepositoryProvider.overrideWith(
            buildConnectionsRepository,
          ),
          cardsRepositoryProvider.overrideWith(buildCardsRepository),
          feedRepositoryProvider.overrideWith(buildFeedRepository),
          accountDeletionRepositoryProvider.overrideWith(
            buildAccountDeletionRepository,
          ),
        ],
        child: const App(),
      ),
    ),
  );
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onOpen);
    // Cold-start trigger: fire after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  void _onOpen() {
    // Read currentStatus() synchronously rather than authStatusProvider.value:
    // the async status stream has not emitted yet on the first post-frame
    // callback, so .value would be null and the cold-start refresh would be
    // skipped. currentStatus() reflects the restored session immediately.
    if (ref.read(authRepositoryProvider).currentStatus() ==
        AuthStatus.signedIn) {
      ref
          .read(connectionsRefreshControllerProvider.notifier)
          .refreshAllOnOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Hold a listener on the refresh controller for the app's lifetime so it is
    // not auto-disposed between open/resume events: its throttle state must
    // persist and it must outlive an in-flight refresh-all.
    ref.watch(connectionsRefreshControllerProvider);
    return MaterialApp.router(
      title: 'Feat.gg',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
