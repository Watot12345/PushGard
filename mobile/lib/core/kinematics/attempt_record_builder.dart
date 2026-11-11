import '../config/thresholds_config.dart';
import 'joint_angle_math.dart';
import 'rep_cycle_detector.dart';

/// Builds the v1.1 continuous raw angle series payload defined in `docs/MATCH_DATA_FORMAT.md`.
/// Never includes `player_id` (identified via server auth token) and never includes camera frames.
class AttemptRecordBuilder {
  static const String formatVersion = '1.1';

  final String attemptId;
  final String? matchId;
  final String nonce;
  final BodySide bodySideSelected;
  final String appVersion;
  final String platform;
  final String deviceModel;
  final String poseModelVersion;
  final String thresholdsHash;
  final ThresholdsConfig config;

  final List<List<num>> _rawSamples = [];
  late final RepCycleDetector _detector;

  AttemptRecordBuilder({
    required this.attemptId,
    this.matchId,
    required this.nonce,
    required this.bodySideSelected,
    this.appVersion = '1.0.0+1',
    this.platform = 'android',
    this.deviceModel = 'generic-device',
    this.poseModelVersion = 'mlkit-pose-fast-v1',
    this.thresholdsHash =
        'a17a465b15ef575f6fdabda355c4d2a331a812a998ff46b9e0542bef296c1eeb',
    ThresholdsConfig? config,
  }) : config = config ?? ThresholdsConfig.instance {
    _detector = RepCycleDetector(config: this.config);
  }

  RepCycleDetector get detector => _detector;
  List<List<num>> get rawSamples => List.unmodifiable(_rawSamples);

  /// Appends a raw frame sample `[t_ms, raw_elbow, raw_body, conf]` and updates
  /// the live on-device cycle detector for HUD preview.
  EvaluatedRep? addRawSample({
    required int tMs,
    required double rawElbow,
    required double rawBody,
    required double conf,
  }) {
    if (tMs < 0) return null;
    _rawSamples.add([
      tMs,
      double.parse(rawElbow.toStringAsFixed(2)),
      double.parse(rawBody.toStringAsFixed(2)),
      double.parse(conf.toStringAsFixed(2)),
    ]);
    return _detector.processSample(
      tMs: tMs,
      rawElbow: rawElbow,
      rawBody: rawBody,
      conf: conf,
    );
  }

  /// Appends a raw landmark frame from the native camera plugin using the locked [bodySideSelected].
  EvaluatedRep? addLandmarkFrame({
    required int tMs,
    required Map<String, List<double>> landmarks,
  }) {
    final prefix = bodySideSelected == BodySide.right ? 'RIGHT' : 'LEFT';
    final shoulder = landmarks['${prefix}_SHOULDER'];
    final elbow = landmarks['${prefix}_ELBOW'];
    final wrist = landmarks['${prefix}_WRIST'];
    final hip = landmarks['${prefix}_HIP'];
    final ankle = landmarks['${prefix}_ANKLE'];

    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        ankle == null) {
      return null;
    }

    final rawElbow = JointAngleMath.computeElbowAngle(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
    );
    final rawBody = JointAngleMath.computeBodyLineDeviation(
      shoulder: shoulder,
      hip: hip,
      ankle: ankle,
    );
    final conf =
        JointAngleMath.minConfidenceForSide(landmarks, bodySideSelected);

    return addRawSample(
      tMs: tMs,
      rawElbow: rawElbow,
      rawBody: rawBody,
      conf: conf,
    );
  }

  /// Produces the canonical v1.1 JSON payload matching `docs/MATCH_DATA_FORMAT.md`.
  Map<String, dynamic> buildPayload() {
    final eval = _detector.evaluateAttemptSamples(_rawSamples);
    final maxWindowMs = config.battleTimerSeconds * 1000;
    final inWindowSamples =
        _rawSamples.where((s) => s[0].toInt() <= maxWindowMs).toList();

    return {
      'version': formatVersion,
      'attempt_id': attemptId,
      'match_id': matchId,
      'nonce': nonce,
      'client': {
        'app_version': appVersion,
        'platform': platform,
        'device_model': deviceModel,
        'pose_model_version': poseModelVersion,
        'thresholds_hash': thresholdsHash,
      },
      'metrics': {
        'body_side_selected':
            bodySideSelected == BodySide.right ? 'right' : 'left',
        'effective_fps':
            double.parse(eval.effectiveFps.toStringAsFixed(2)),
        'total_samples': eval.totalSamples,
        'nominal_interval_ms':
            double.parse(eval.nominalIntervalMs.toStringAsFixed(2)),
        'dropped_frame_gaps': eval.droppedFrameGaps,
      },
      'samples': inWindowSamples,
      'client_claimed_reps': eval.reps.map((r) => r.toJson()).toList(),
    };
  }
}
