import 'dart:math' as math;
import 'native_camera_controller.dart';

class SpikeBenchmarkSample {
  final int timestampMs;
  final int inferenceMs;
  final double deltaMs;
  final Map<String, double> inFrameLikelihoods;
  final double upperArmLength;
  final double forearmLength;
  final double torsoLength;
  final double elbowAngle;
  final bool isDropout;

  SpikeBenchmarkSample({
    required this.timestampMs,
    required this.inferenceMs,
    required this.deltaMs,
    required this.inFrameLikelihoods,
    required this.upperArmLength,
    required this.forearmLength,
    required this.torsoLength,
    required this.elbowAngle,
    required this.isDropout,
  });
}

class SpikeBenchmarkRecorder {
  final List<SpikeBenchmarkSample> samples = [];
  int? _lastTimestampMs;
  bool isRecording = false;

  void start() {
    samples.clear();
    _lastTimestampMs = null;
    isRecording = true;
  }

  void stop() {
    isRecording = false;
  }

  void recordFrame(PoseFrame frame) {
    if (!isRecording) return;

    final t = frame.timestampMs;
    final delta = _lastTimestampMs != null ? (t - _lastTimestampMs!).toDouble() : 33.3;
    _lastTimestampMs = t;

    // Determine active body side (highest min likelihood)
    final leftJoints = ['LEFT_SHOULDER', 'LEFT_ELBOW', 'LEFT_WRIST', 'LEFT_HIP', 'LEFT_KNEE', 'LEFT_ANKLE'];
    final rightJoints = ['RIGHT_SHOULDER', 'RIGHT_ELBOW', 'RIGHT_WRIST', 'RIGHT_HIP', 'RIGHT_KNEE', 'RIGHT_ANKLE'];

    double getLikelihood(String key) => frame.landmarks[key] != null && frame.landmarks[key]!.length >= 4
        ? frame.landmarks[key]![3]
        : 0.0;

    final minLeft = leftJoints.map(getLikelihood).reduce(math.min);
    final minRight = rightJoints.map(getLikelihood).reduce(math.min);
    final isRight = minRight >= minLeft;
    final activePrefix = isRight ? 'RIGHT_' : 'LEFT_';

    final shoulder = frame.landmarks['${activePrefix}SHOULDER'];
    final elbow = frame.landmarks['${activePrefix}ELBOW'];
    final wrist = frame.landmarks['${activePrefix}WRIST'];
    final hip = frame.landmarks['${activePrefix}HIP'];

    double dist(List<double>? p1, List<double>? p2) {
      if (p1 == null || p2 == null) return 0.0;
      final dx = p1[0] - p2[0];
      final dy = p1[1] - p2[1];
      final dz = (p1.length > 2 && p2.length > 2) ? p1[2] - p2[2] : 0.0;
      return math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    double calculateAngle(List<double>? a, List<double>? b, List<double>? c) {
      if (a == null || b == null || c == null) return 180.0;
      final v1x = a[0] - b[0];
      final v1y = a[1] - b[1];
      final v2x = c[0] - b[0];
      final v2y = c[1] - b[1];
      final dot = v1x * v2x + v1y * v2y;
      final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
      final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
      if (mag1 == 0 || mag2 == 0) return 180.0;
      final cosTheta = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
      return math.acos(cosTheta) * (180.0 / math.pi);
    }

    final upperArm = dist(shoulder, elbow);
    final forearm = dist(elbow, wrist);
    final torso = dist(shoulder, hip);
    final elbowAngle = calculateAngle(shoulder, elbow, wrist);

    final likelihoods = <String, double>{};
    bool dropout = false;
    for (final j in (isRight ? rightJoints : leftJoints)) {
      final l = getLikelihood(j);
      likelihoods[j] = l;
      if (l < 0.60) {
        dropout = true;
      }
    }

    samples.add(SpikeBenchmarkSample(
      timestampMs: t,
      inferenceMs: frame.inferenceMs,
      deltaMs: delta,
      inFrameLikelihoods: likelihoods,
      upperArmLength: upperArm,
      forearmLength: forearm,
      torsoLength: torso,
      elbowAngle: elbowAngle,
      isDropout: dropout,
    ));
  }

  Map<String, dynamic> computeReport({required String deviceModel}) {
    if (samples.isEmpty) return {'error': 'No samples recorded'};

    final durationMs = samples.last.timestampMs - samples.first.timestampMs;
    final totalSamples = samples.length;
    final effectiveFps = durationMs > 0 ? (totalSamples * 1000.0) / durationMs : 0.0;

    // Median interval
    final deltas = samples.map((s) => s.deltaMs).toList()..sort();
    final medianInterval = deltas[deltas.length ~/ 2];

    // Dropped frame gaps
    final gapThreshold = 2.5 * medianInterval;
    int gapCount = 0;
    for (final s in samples) {
      if (s.deltaMs > gapThreshold) {
        gapCount++;
      }
    }

    // Dropout rate (< 0.60 likelihood)
    final dropoutCount = samples.where((s) => s.isDropout).length;
    final dropoutRate = (dropoutCount / totalSamples) * 100.0;

    // Bone length variation coefficient: std_dev / mean
    double cv(List<double> vals) {
      if (vals.isEmpty) return 0.0;
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      if (mean == 0.0) return 0.0;
      final variance = vals.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / vals.length;
      return (math.sqrt(variance) / mean) * 100.0;
    }

    final upperArmCv = cv(samples.map((s) => s.upperArmLength).where((l) => l > 0).toList());
    final forearmCv = cv(samples.map((s) => s.forearmLength).where((l) => l > 0).toList());
    final torsoCv = cv(samples.map((s) => s.torsoLength).where((l) => l > 0).toList());

    // Confidence at bottom of reps (elbowAngle <= 95 deg) vs top lockout (elbowAngle >= 155 deg)
    final bottomSamples = samples.where((s) => s.elbowAngle <= 95.0).toList();
    final topSamples = samples.where((s) => s.elbowAngle >= 155.0).toList();

    double avgLikelihood(List<SpikeBenchmarkSample> subset, String joint) {
      if (subset.isEmpty) return 0.0;
      final vals = subset
          .map((s) => s.inFrameLikelihoods.entries.firstWhere((e) => e.key.endsWith(joint), orElse: () => MapEntry('', 0.0)).value)
          .where((v) => v > 0)
          .toList();
      return vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
    }

    return {
      'device_model': deviceModel,
      'duration_seconds': (durationMs / 1000.0).toStringAsFixed(1),
      'total_samples': totalSamples,
      'effective_fps': effectiveFps.toStringAsFixed(1),
      'median_interval_ms': medianInterval.toStringAsFixed(1),
      'gap_count': gapCount,
      'dropout_rate_pct': dropoutRate.toStringAsFixed(2),
      'bone_length_variation_pct': {
        'upper_arm': upperArmCv.toStringAsFixed(2),
        'forearm': forearmCv.toStringAsFixed(2),
        'torso': torsoCv.toStringAsFixed(2),
      },
      'confidence_at_bottom': {
        'shoulder': avgLikelihood(bottomSamples, 'SHOULDER').toStringAsFixed(2),
        'elbow': avgLikelihood(bottomSamples, 'ELBOW').toStringAsFixed(2),
        'wrist': avgLikelihood(bottomSamples, 'WRIST').toStringAsFixed(2),
        'hip': avgLikelihood(bottomSamples, 'HIP').toStringAsFixed(2),
      },
      'confidence_at_top': {
        'shoulder': avgLikelihood(topSamples, 'SHOULDER').toStringAsFixed(2),
        'elbow': avgLikelihood(topSamples, 'ELBOW').toStringAsFixed(2),
        'wrist': avgLikelihood(topSamples, 'WRIST').toStringAsFixed(2),
        'hip': avgLikelihood(topSamples, 'HIP').toStringAsFixed(2),
      },
      'pass_criteria': {
        'fps_pass': effectiveFps >= 25.0,
        'dropout_pass': dropoutRate < 5.0,
        'bottom_conf_pass': avgLikelihood(bottomSamples, 'ELBOW') >= 0.60 && avgLikelihood(bottomSamples, 'WRIST') >= 0.60,
      }
    };
  }
}
