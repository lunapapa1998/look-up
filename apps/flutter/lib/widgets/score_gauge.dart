import 'dart:math';

import 'package:flutter/material.dart';

class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 120});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: colorScheme.secondary,
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ScoreGaugePainter(
              score: score,
              trackColor: colorScheme.surfaceContainerHighest,
              progressColor: colorScheme.secondary,
            ),
          ),
          Text('$score', style: textStyle),
        ],
      ),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  _ScoreGaugePainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  final int score;
  final Color trackColor;
  final Color progressColor;

  static const _strokeWidth = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (min(size.width, size.height) - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * (score / 100);
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
