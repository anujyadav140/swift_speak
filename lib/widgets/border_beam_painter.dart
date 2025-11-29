import 'package:flutter/material.dart';
import 'dart:math' as math;

class BorderBeamPainter extends CustomPainter {
  final Animation<double> animation;
  final double borderRadius;
  final Color color;

  BorderBeamPainter({
    required this.animation,
    this.borderRadius = 40.0,
    this.color = Colors.white,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final gradient = SweepGradient(
      colors: [
        Colors.transparent,
        color,
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
      startAngle: 0.0,
      endAngle: math.pi * 2,
      transform: GradientRotation(animation.value * 2 * math.pi),
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(BorderBeamPainter oldDelegate) => true;
}
