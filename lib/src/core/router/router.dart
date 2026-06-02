/// Router module for featgg core: central go_router configuration.
library;

import 'package:flutter/foundation.dart';
import 'package:featgg/src/features/auth/domain/auth_repository.dart';
import 'package:featgg/src/features/auth/presentation/auth_presentation.dart';
import 'package:featgg/src/features/home/presentation/home_presentation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final status = ref.watch(authStatusProvider);

  // A ValueNotifier bridges Riverpod rebuilds to go_router's refreshListenable
  // so that redirect re-runs whenever the auth status changes.
  final notifier = ValueNotifier<AuthStatus?>(status.value);
  ref.listen<AsyncValue<AuthStatus>>(authStatusProvider, (_, next) {
    notifier.value = next.value;
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final signedIn = status.value == AuthStatus.signedIn;
      final atSignIn = state.matchedLocation == '/sign-in';
      if (!signedIn && !atSignIn) return '/sign-in';
      if (signedIn && atSignIn) return '/';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    ],
  );
}
