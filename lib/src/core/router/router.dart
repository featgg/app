/// Router module for featgg core: central go_router configuration.
library;

import 'package:flutter/foundation.dart';
import 'package:featgg/src/features/auth/domain/auth_repository.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:featgg/src/features/connections/presentation/connections_presentation.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
import 'package:featgg/src/features/settings/presentation/settings_presentation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  // Build the GoRouter ONCE: read (not watch) the seed status, so an auth-status
  // change does not rebuild this provider. Rebuilding would recreate the router
  // and reset the navigation stack — including on the ~hourly token refresh. A
  // ValueNotifier kept current by the listener below is go_router's
  // refreshListenable; it alone drives redirect re-evaluation, and redirect
  // reads the notifier's live value rather than a captured one.
  final notifier = ValueNotifier<AuthStatus?>(
    ref.read(authStatusProvider).value,
  );
  ref.listen<AsyncValue<AuthStatus>>(authStatusProvider, (_, next) {
    notifier.value = next.value;
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final signedIn = notifier.value == AuthStatus.signedIn;
      final atSignIn = state.matchedLocation == '/sign-in';
      if (!signedIn && !atSignIn) return '/sign-in';
      if (signedIn && atSignIn) return '/';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const FeedScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/profile/:id',
        // The visitor widgets view and the card renderer live in the profile and
        // connections features; the visitor screen lives in feed. The router is
        // the composition root that may import every presentation, so it
        // assembles the widgets view (with the connections card builder) and
        // injects it to keep the features decoupled.
        builder: (_, state) {
          final userId = state.pathParameters['id']!;
          return PublicProfileScreen(
            userId: userId,
            // Reads each platform's public card through the visitor source.
            personalizationBuilder: (profile, id) => PersonalizationProfileView(
              profile: profile,
              userId: id,
              cardSource: (platform) => publicOwnerCardProvider(id, platform),
            ),
            chromeBuilder: (profile) {
              final palette = paletteForTheme(profile.theme);
              return (background: palette.bg, foreground: palette.text);
            },
          );
        },
      ),
      GoRoute(
        path: '/connections',
        builder: (_, _) => const ConnectionsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) => const AccountDeletionScreen(),
      ),
    ],
  );
}
