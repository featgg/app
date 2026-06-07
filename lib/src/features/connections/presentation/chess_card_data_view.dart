import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the Chess.com `data` block: primary mode, per-mode ratings,
/// optional title/FIDE/puzzle-rush/tactics rows, and the primary mode's
/// win/loss/draw record when present.
class ChessCardDataView extends StatelessWidget {
  const ChessCardDataView({super.key, required this.data});

  final ChessCardData data;

  static const _displayOrder = ['rapid', 'blitz', 'bullet', 'daily'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final primaryKey = data.primaryMode.toLowerCase();
    final primaryRecord = data.ratings[primaryKey]?.record;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          key: const Key('chessPrimaryModeLabel'),
          label: l10n.connectionsChessPrimaryMode,
          value: data.primaryMode,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        for (final mode in _displayOrder)
          if (data.ratings.containsKey(mode)) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              key: Key('chessRating_$mode'),
              label: l10n.connectionsChessRatingFor(mode),
              value:
                  '${data.ratings[mode]!.current} (${l10n.connectionsChessBest} ${data.ratings[mode]!.best})',
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          ],
        if (data.titleFlags?.isTitled == true &&
            data.titleFlags?.title != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('chessTitleLabel'),
            label: l10n.connectionsChessTitle,
            value: data.titleFlags!.title!,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.fide != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('chessFideLabel'),
            label: l10n.connectionsChessFide,
            value: '${data.fide}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.puzzleRushScore != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('chessPuzzleRushLabel'),
            label: l10n.connectionsChessPuzzleRush,
            value: '${data.puzzleRushScore}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.tacticsBest != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('chessTacticsLabel'),
            label: l10n.connectionsChessTactics,
            value: '${data.tacticsBest}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (primaryRecord != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('chessRecord'),
            label: l10n.connectionsChessRecord,
            value:
                '${primaryRecord.win} / ${primaryRecord.loss} / ${primaryRecord.draw}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: textTheme.bodySmall),
      ],
    );
  }
}
