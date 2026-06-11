import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure.dart';
import '../l10n/failure_l10n.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';

/// Renders an [AsyncValue] through loading, error, and data states.
///
/// Loading → centered adaptive spinner.
/// Error → full-screen blocking error view with optional Retry action.
/// Data → the caller-supplied [data] builder.
///
/// This is the centralized seam for async state rendering shared across
/// features; build it once here rather than per-feature.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Invoked by the error state's Retry action. Null hides the action.
  final VoidCallback? onRetry;

  /// Replaces the default centered spinner — e.g. a skeleton mirroring the
  /// data layout so content swaps in without reflow. Null keeps the spinner.
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: true,
    skipLoadingOnRefresh: true,
    data: data,
    loading: () =>
        loading ?? const Center(child: CircularProgressIndicator.adaptive()),
    error: (error, _) => _ErrorView(error: error, onRetry: onRetry),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final message = error is Failure
        ? (error as Failure).localizedMessage(l10n)
        : l10n.errorUnexpected;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppSpacing.xl * 2,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.asyncErrorTitle,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('asyncRetryButton'),
                onPressed: onRetry,
                child: Text(l10n.asyncRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
