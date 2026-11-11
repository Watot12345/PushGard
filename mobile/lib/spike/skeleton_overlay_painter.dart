import 'package:flutter/material.dart';

class SkeletonOverlayPainter extends CustomPainter {
  final Map<String, List<double>> landmarks;
  final int imageWidth;
  final int imageHeight;
  final bool isFrontCamera;

  SkeletonOverlayPainter({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty || imageWidth == 0 || imageHeight == 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    Offset? getOffset(String key) {
      final point = landmarks[key];
      if (point == null) return null;
      double x = point[0] * scaleX;
      double y = point[1] * scaleY;
      if (isFrontCamera) {
        x = size.width - x;
      }
      return Offset(x, y);
    }

    double getConfidence(String key) {
      final point = landmarks[key];
      if (point == null || point.length < 4) return 0.0;
      return point[3]; // inFrameLikelihood
    }

    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final connections = [
      // Left side
      ('LEFT_SHOULDER', 'LEFT_ELBOW'),
      ('LEFT_ELBOW', 'LEFT_WRIST'),
      ('LEFT_SHOULDER', 'LEFT_HIP'),
      ('LEFT_HIP', 'LEFT_KNEE'),
      ('LEFT_KNEE', 'LEFT_ANKLE'),
      // Right side
      ('RIGHT_SHOULDER', 'RIGHT_ELBOW'),
      ('RIGHT_ELBOW', 'RIGHT_WRIST'),
      ('RIGHT_SHOULDER', 'RIGHT_HIP'),
      ('RIGHT_HIP', 'RIGHT_KNEE'),
      ('RIGHT_KNEE', 'RIGHT_ANKLE'),
      // Torso cross
      ('LEFT_SHOULDER', 'RIGHT_SHOULDER'),
      ('LEFT_HIP', 'RIGHT_HIP'),
    ];

    for (final conn in connections) {
      final p1 = getOffset(conn.$1);
      final p2 = getOffset(conn.$2);
      if (p1 != null && p2 != null) {
        final minConf = [getConfidence(conn.$1), getConfidence(conn.$2)].reduce((a, b) => a < b ? a : b);
        linePaint.color = minConf >= 0.60
            ? Colors.greenAccent.withValues(alpha: 0.8)
            : Colors.redAccent.withValues(alpha: 0.8);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Draw joint nodes
    landmarks.forEach((name, point) {
      final offset = getOffset(name);
      if (offset != null) {
        final conf = getConfidence(name);
        final nodePaint = Paint()
          ..color = conf >= 0.60 ? Colors.greenAccent : Colors.redAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offset, 4.5, nodePaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant SkeletonOverlayPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}
