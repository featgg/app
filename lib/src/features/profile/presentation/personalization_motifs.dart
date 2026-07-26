import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../domain/profile_archetype.dart';

/// The archetype's motif, filling a framed card. Drawn on a canvas, never typed:
/// a decorative character depends on a font the app does not ship, so its weight
/// and form change with the device and a reference image cannot capture it.
class PersonalizationMotifField extends StatelessWidget {
  const PersonalizationMotifField({super.key, required this.motif});

  final ProfileMotif motif;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // The bottom paint is the solid mid-tone, never a gradient that can
          // fall to black, so the field stays inside the theme.
          colors: [palette.artC, palette.artB],
        ),
      ),
      child: CustomPaint(
        painter: PersonalizationMotifPainter(motif: motif, palette: palette),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints one motif across the whole field. Public so a test can read back the
/// motif and the palette a card was painted with.
///
/// Every dimension is a fraction of the field's shorter side, so a motif keeps
/// its proportions at every card width, and every color comes from the palette,
/// so a theme swap re-tints it.
class PersonalizationMotifPainter extends CustomPainter {
  const PersonalizationMotifPainter({
    required this.motif,
    required this.palette,
  });

  final ProfileMotif motif;
  final PersonalizationPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PersonalizationLayout.motifStrokeWidth
      ..color = palette.accent;
    final fill = Paint()..color = palette.accentSoft;

    switch (motif) {
      case ProfileMotif.chips:
        for (var i = -1; i <= 1; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(c.dx, c.dy + i * 0.20 * s),
                width: 0.62 * s,
                height: 0.12 * s,
              ),
              const Radius.circular(AppRadii.full),
            ),
            stroke,
          );
        }
      case ProfileMotif.bars:
        final left = c.dx - 0.32 * s;
        final height = 0.06 * s;
        var width = 0.64 * s;
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              left,
              c.dy + (i - 1.5) * 0.13 * s - height / 2,
              width,
              height,
            ),
            fill,
          );
          width *= 0.85;
        }
      case ProfileMotif.capsule:
        final band = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.12 * s
          ..color = palette.accentSoft;
        for (var x = -size.height; x < size.width; x += 0.34 * s) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            band,
          );
        }
      case ProfileMotif.crest:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 0.44 * s)
            ..lineTo(c.dx + 0.30 * s, c.dy - 0.28 * s)
            ..lineTo(c.dx + 0.30 * s, c.dy + 0.06 * s)
            ..lineTo(c.dx, c.dy + 0.44 * s)
            ..lineTo(c.dx - 0.30 * s, c.dy + 0.06 * s)
            ..lineTo(c.dx - 0.30 * s, c.dy - 0.28 * s)
            ..close(),
          stroke,
        );
        canvas.drawCircle(c + Offset(0, -0.04 * s), 0.12 * s, fill);
      case ProfileMotif.emblem:
        canvas.drawCircle(c, 0.30 * s, stroke);
        canvas.drawLine(
          Offset(c.dx, c.dy - 0.42 * s),
          Offset(c.dx, c.dy + 0.42 * s),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 0.42 * s, c.dy),
          Offset(c.dx + 0.42 * s, c.dy),
          stroke,
        );
      case ProfileMotif.orbShelf:
        canvas.drawCircle(c, 0.13 * s, fill);
        for (final dx in const [-0.32, 0.0, 0.32]) {
          canvas.drawCircle(c + Offset(dx * s, 0), 0.13 * s, stroke);
        }
      case ProfileMotif.letterTiles:
        const columns = 4;
        const rows = 2;
        final side = 0.16 * s;
        final gap = 0.08 * s;
        final left = c.dx - (columns * side + (columns - 1) * gap) / 2;
        final top = c.dy - (rows * side + (rows - 1) * gap) / 2;
        for (var row = 0; row < rows; row++) {
          for (var column = 0; column < columns; column++) {
            final tile = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                left + column * (side + gap),
                top + row * (side + gap),
                side,
                side,
              ),
              const Radius.circular(AppRadii.sm),
            );
            canvas
              ..drawRRect(tile, fill)
              ..drawRRect(tile, stroke);
          }
        }
      case ProfileMotif.hatch:
        final hairline = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = PersonalizationLayout.borderWidth
          ..color = palette.accentSoft;
        for (var x = -size.height; x < size.width; x += 0.14 * s) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            hairline,
          );
        }
    }
  }

  @override
  bool shouldRepaint(PersonalizationMotifPainter oldDelegate) =>
      motif != oldDelegate.motif || palette != oldDelegate.palette;
}

/// The muted diamond that brackets the achievement shelf's letters. Drawn rather
/// than typed for the same reason the motifs are.
class PersonalizationDiamond extends StatelessWidget {
  const PersonalizationDiamond({
    super.key,
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _DiamondPainter(color: color)),
  );
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter oldDelegate) => color != oldDelegate.color;
}
