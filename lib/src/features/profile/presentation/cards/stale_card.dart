import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../domain/profile_archetype.dart';
import '../personalization_card_shell.dart';

/// The card an owner sees in place of one whose platform data is past the
/// freshness window its provider requires: the archetype's own frame, the
/// platform's art withheld along with its numbers, and a line saying the data
/// is out of date. [onRefresh] makes it actionable; null leaves it inert.
class PersonalizationStaleCard extends StatelessWidget {
  const PersonalizationStaleCard({
    super.key,
    required this.archetype,
    required this.size,
    this.onRefresh,
  });

  final ProfileArchetype archetype;
  final ProfileCardSize size;

  /// Where the owner goes to bring the data back. Null on a surface with no
  /// refresh to offer, which leaves the card inert rather than promising one.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    // Both lines take the primary tone: the fade already reduces them, and
    // stacking it on an already-muted tone is what drops the notice below the
    // contrast floor on the lighter palettes.
    final card = Opacity(
      opacity: PersonalizationLayout.staleCardOpacity,
      child: PersonalizationCardShell(
        archetype: archetype,
        size: size,
        // No art: the shell degrades any archetype to the framed format on its
        // own, so the withheld picture needs no branch on the chassis.
        framedContent: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.personalizationCardStale,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: palette.text,
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.personalizationCardStaleRefresh,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(color: palette.text),
              ),
            ],
          ),
        ),
      ),
    );

    final refresh = onRefresh;
    if (refresh == null) return card;
    return Semantics(
      button: true,
      label: l10n.personalizationCardStaleRefresh,
      child: GestureDetector(
        key: const Key('personalizationStaleRefresh'),
        behavior: HitTestBehavior.opaque,
        onTap: refresh,
        child: card,
      ),
    );
  }
}
