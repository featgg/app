/// Router module for featgg core: central go_router configuration.
library;

export 'router_placeholder_page.dart';

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'router_placeholder_page.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  // ref is the forward seam for session-gated redirects; the router will
  // watch auth state here once the session layer exists.
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const RouterPlaceholderPage(),
      ),
    ],
  );
}
