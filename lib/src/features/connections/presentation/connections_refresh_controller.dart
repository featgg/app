import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure.dart';
import '../domain/connections_providers.dart';
import 'connections_provider.dart';

part 'connections_refresh_controller.g.dart';

/// Anti-spam debounce: a resume that re-fires within this window of the
/// last attempt is skipped. Short and bypassable — the server's
/// per-platform cooldown is the real throttle (refresh-all self-throttles).
const Duration _resumeDebounce = Duration(seconds: 10);

/// Fallback back-off when a 429 carries no usable `retry_after`.
const Duration _refreshAllFallbackBackoff = Duration(seconds: 60);

// The app root holds a listener on this controller (see `lib/main.dart`) so it
// lives for the app's lifetime. It stays autoDispose-by-default — it reads
// autoDispose providers, so it must not itself be `keepAlive` — and relies on
// that root listener instead: without it the controller would be disposed
// between open/resume events, losing its in-flight/debounce/back-off state and,
// worse, being torn down mid-request so a returning refresh-all never
// invalidates the cards (`ref.mounted` would be false).
@riverpod
class ConnectionsRefreshController extends _$ConnectionsRefreshController {
  Future<void>? _inFlight; // coalescing: at most one call in flight
  DateTime? _lastAttemptAt; // resume-window debounce
  DateTime? _backoffUntil; // 429 back-off; never call before this

  @override
  void build() {} // no state; this is a fire-and-forget seam

  /// Fire a coalesced refresh-all. No-op when one is in flight, when
  /// inside the resume-debounce window, or when inside the 429 back-off.
  /// Never throws; the Either is folded internally.
  Future<void> refreshAllOnOpen() {
    // clock.now() (not DateTime.now()) so the debounce/back-off windows are
    // controllable under FakeAsync in tests.
    final now = clock.now();

    // In-flight coalescing: return the existing future rather than starting a
    // second call.
    if (_inFlight != null) return _inFlight!;

    // 429 back-off: refuse to call before the server-derived deadline.
    if (_backoffUntil != null && now.isBefore(_backoffUntil!)) {
      return Future.value();
    }

    // Resume-debounce: skip rapid successive open/resume events.
    if (_lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < _resumeDebounce) {
      return Future.value();
    }

    _lastAttemptAt = now;
    _inFlight = _doRefresh();
    return _inFlight!;
  }

  Future<void> _doRefresh() async {
    try {
      final result = await ref.read(connectionsRepositoryProvider).refreshAll();

      if (!ref.mounted) return;

      result.fold(
        (failure) {
          if (failure is SyncCooldownFailure) {
            final backoff = failure.retryAfterSeconds != null
                ? Duration(seconds: failure.retryAfterSeconds!)
                : _refreshAllFallbackBackoff;
            // Anchor to the handling time (now), not the request start: the
            // server's retry_after is the window remaining as of the response,
            // so a slow call must not shorten the back-off.
            _backoffUntil = clock.now().add(backoff);
          }
          // Other Left: repo already crash-reported unexpected ones; nothing
          // to surface here (background path is intentionally silent).
        },
        (refreshResult) {
          if (!ref.mounted) return;
          final refreshed = refreshResult.refreshedPlatforms;
          for (final p in refreshed) {
            ref.invalidate(cardProvider(p));
          }
          if (refreshed.isNotEmpty) {
            ref.invalidate(myConnectionsProvider);
          }
        },
      );
    } finally {
      _inFlight = null;
    }
  }
}
