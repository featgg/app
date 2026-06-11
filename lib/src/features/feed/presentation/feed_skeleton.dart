import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Loading placeholder — a list of shimmer-like card shapes shown while the
/// first feed page is loading. Uses a key so tests can assert it is present
/// (not a raw CircularProgressIndicator).
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  /// Enough rows to fill any reasonable viewport; the lazy builder only
  /// materializes the visible ones, and overflow clips at the screen edge —
  /// the loading state must not look like a half-empty page.
  static const int _count = 12;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      key: const Key('feedSkeleton'),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => _SkeletonCard(colorScheme: colorScheme),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final bg = colorScheme.surfaceContainerHighest;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xl + AppSpacing.md,
              height: AppSpacing.xl + AppSpacing.md,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: AppSpacing.md,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    height: AppSpacing.sm,
                    width: AppSpacing.xl * 3,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
