import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/bootstrap.dart';
import 'src/core/core.dart';
import 'src/features/auth/data/auth_data.dart';
import 'src/features/auth/domain/auth_domain.dart';
import 'src/features/profile/data/profile_data.dart';
import 'src/features/profile/domain/profile_domain.dart';
import 'src/features/profile/presentation/avatar_picker.dart';

Future<void> main() async {
  await bootstrap(
    () => runApp(
      ProviderScope(
        observers: [const CrashReportingObserver(SentryCrashReporter())],
        overrides: [
          authRepositoryProvider.overrideWith(buildAuthRepository),
          profileRepositoryProvider.overrideWith(buildProfileRepository),
          avatarRepositoryProvider.overrideWith(buildAvatarRepository),
          avatarPickerProvider.overrideWithValue(
            const CropYourImageAvatarPicker(),
          ),
        ],
        child: const App(),
      ),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
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
