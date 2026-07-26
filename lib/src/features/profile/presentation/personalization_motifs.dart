import 'package:flutter/material.dart';

/// The muted diamond that brackets the achievement shelf's letters. Drawn rather
/// than typed: a decorative character depends on a font the app does not ship,
/// so its weight and form change with the device and a reference image cannot
/// capture it.
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
