/// Router module for featgg core: central go_router configuration.
library;

import 'package:flutter/foundation.dart';
import 'package:featgg/src/features/auth/domain/auth_repository.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:featgg/src/features/connections/presentation/connections_presentation.dart';
import 'package:featgg/src/features/feed/presentation/feed_presentation.dart';
import 'package:featgg/src/features/home/presentation/home_presentation.dart';
import 'package:featgg/src/features/profile/domain/profile_domain.dart';
import 'package:featgg/src/features/profile/presentation/profile_presentation.dart';
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
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/profile/edit',
        redirect: (context, state) =>
            state.extra is Profile ? null : '/profile',
        builder: (_, state) =>
            ProfileEditScreen(profile: state.extra! as Profile),
      ),
      GoRoute(
        path: '/connections',
        builder: (_, _) => const ConnectionsScreen(),
      ),
      GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
    ],
  );
}
