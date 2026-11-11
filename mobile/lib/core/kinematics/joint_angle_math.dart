import 'dart:math' as math;

enum BodySide { left, right }

/// Pure 2D geometric angle calculations and body-side selection for PushGard.
/// Never stores or processes camera pixels—operates strictly on landmark coordinates.
class JointAngleMath {
  static const List<String> requiredJoints = [
    'SHOULDER',
    'ELBOW',
    'WRIST',
    'HIP',
    'KNEE',
    'ANKLE',
  ];

  /// Computes the interior 2D angle (in degrees, [0.0, 180.0]) at vertex [b]
  /// formed by segments BA and BC.
  static double computeThreePointAngleDegrees({
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double cx,
    required double cy,
  }) {
    final v1x = ax - bx;
    final v1y = ay - by;
    final v2x = cx - bx;
    final v2y = cy - by;

    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (mag1 < 1e-6 || mag2 < 1e-6) {
      return 180.0;
    }

    final dot = v1x * v2x + v1y * v2y;
    final cosTheta = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosTheta) * (180.0 / math.pi);
  }

  /// Computes raw elbow angle (shoulder-elbow-wrist) in degrees.
  static double computeElbowAngle({
    required List<double> shoulder,
    required List<double> elbow,
    required List<double> wrist,
  }) {
    return computeThreePointAngleDegrees(
      ax: shoulder[0],
      ay: shoulder[1],
      bx: elbow[0],
      by: elbow[1],
      cx: wrist[0],
      cy: wrist[1],
    );
  }

  /// Computes raw body-line deviation |angle(shoulder-hip-ankle) - 180°| in degrees.
  /// A perfectly straight plank has 0° deviation; hip sag or pike increases deviation.
  static double computeBodyLineDeviation({
    required List<double> shoulder,
    required List<double> hip,
    required List<double> ankle,
  }) {
    final angle = computeThreePointAngleDegrees(
      ax: shoulder[0],
      ay: shoulder[1],
      bx: hip[0],
      by: hip[1],
      cx: ankle[0],
      cy: ankle[1],
    );
    return (180.0 - angle).abs();
  }

  /// Selects the active body side (`left` or `right`) at the start of an attempt
  /// by comparing minimum confidence across the 6 key joints on each side.
  /// Per `MATCH_DATA_FORMAT.md` §4.3, the selected side is fixed for the whole attempt.
  static BodySide selectBodySide(Map<String, List<double>> landmarks) {
    final leftMin = minConfidenceForSide(landmarks, BodySide.left);
    final rightMin = minConfidenceForSide(landmarks, BodySide.right);
    return rightMin >= leftMin ? BodySide.right : BodySide.left;
  }

  /// Returns the minimum confidence score across the 6 required joints of [side].
  static double minConfidenceForSide(
    Map<String, List<double>> landmarks,
    BodySide side,
  ) {
    final prefix = side == BodySide.right ? 'RIGHT' : 'LEFT';
    double minConf = 1.0;
    for (final joint in requiredJoints) {
      final pt = landmarks['${prefix}_$joint'];
      final conf = (pt != null && pt.length >= 4) ? pt[3] : 0.0;
      if (conf < minConf) {
        minConf = conf;
      }
    }
    return minConf;
  }
}
