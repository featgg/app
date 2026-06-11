import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-page loading placeholder mirroring a profile layout — avatar circle,
/// identity lines, and card-shaped blocks — so the real content swaps in
/// without the page reflowing or re-centering.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    const avatarSize = AppSpacing.xl * 3;

    return SingleChildScrollView(
      key: const Key('profileSkeleton'),
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            ),
            const SizedBox(height: AppSpacing.md),
            _Bar(width: AppSpacing.xl * 5, height: AppSpacing.md, color: bg),
            const SizedBox(height: AppSpacing.sm),
            _Bar(width: AppSpacing.xl * 3, height: AppSpacing.sm, color: bg),
            const SizedBox(height: AppSpacing.md),
            _Bar(width: AppSpacing.xl * 6, height: AppSpacing.sm, color: bg),
            const SizedBox(height: AppSpacing.lg),
            const ProfileCardsSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// Card-shaped loading blocks for a profile's cards section, sized like the
/// real platform cards so the section does not jump when they resolve.
class ProfileCardsSkeleton extends StatelessWidget {
  const ProfileCardsSkeleton({super.key, this.count = 2});

  /// Number of placeholder blocks; a typical profile resolves to a few cards.
  final int count;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      key: const Key('profileCardsSkeleton'),
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              width: double.infinity,
              height: AppSpacing.xl * 4,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
    );
  }
}
