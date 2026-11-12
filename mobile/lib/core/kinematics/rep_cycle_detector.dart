import 'dart:math' as math;
import '../config/thresholds_config.dart';
import 'ema_smoother.dart';

enum RepPhase {
  waitingForInitialTop,
  atTop,
  descending,
  ascending,
}

class EvaluatedRep {
  final int repIndex;
  final int startMs;
  final int bottomMs;
  final int topMs;
  final double minElbowAngle;
  final double maxElbowAngle;
  final double maxBodyLineDeviation;
  final double minConfidence;
  final bool valid;
  final String? rejectReason;

  const EvaluatedRep({
    required this.repIndex,
    required this.startMs,
    required this.bottomMs,
    required this.topMs,
    required this.minElbowAngle,
    required this.maxElbowAngle,
    required this.maxBodyLineDeviation,
    required this.minConfidence,
    required this.valid,
    this.rejectReason,
  });

  Map<String, dynamic> toJson() => {
        'rep_index': repIndex,
        'start_ms': startMs,
        'bottom_ms': bottomMs,
        'top_ms': topMs,
        'min_elbow_angle': double.parse(minElbowAngle.toStringAsFixed(2)),
        'max_elbow_angle': double.parse(maxElbowAngle.toStringAsFixed(2)),
        'max_body_line_deviation':
            double.parse(maxBodyLineDeviation.toStringAsFixed(2)),
        'min_confidence': double.parse(minConfidence.toStringAsFixed(2)),
        'valid': valid,
        'reject_reason': rejectReason,
      };
}

class AttemptEvaluationResult {
  final bool attemptValid;
  final String? attemptRejectReason;
  final List<String> flags;
  final int totalSamples;
  final double effectiveFps;
  final double nominalIntervalMs;
  final List<List<int>> droppedFrameGaps;
  final List<EvaluatedRep> reps;

  const AttemptEvaluationResult({
    required this.attemptValid,
    this.attemptRejectReason,
    required this.flags,
    required this.totalSamples,
    required this.effectiveFps,
    required this.nominalIntervalMs,
    required this.droppedFrameGaps,
    required this.reps,
  });

  int get validRepCount => reps.where((r) => r.valid).length;
  int get rejectedRepCount => reps.where((r) => !r.valid).length;
}

/// Deterministic top-to-top cycle reversal detector and post-cycle validator.
/// Driven entirely by [ThresholdsConfig] (zero hard-coded constants).
class RepCycleDetector {
  final ThresholdsConfig config;
  late final EmaSmoother _elbowSmoother;
  late final EmaSmoother _bodySmoother;

  RepPhase _phase = RepPhase.waitingForInitialTop;
  final List<EvaluatedRep> _reps = [];

  int _topPeakMs = 0;
  double _topPeakAngle = 0.0;

  int _cycleStartMs = 0;
  double _cycleStartPeakAngle = 0.0;
  int _bottomMs = 0;
  double _troughAngle = 180.0;
  int _returnPeakMs = 0;
  double _returnPeakAngle = 0.0;

  double _maxBodyDeviation = 0.0;
  double _minConfidence = 1.0;
  bool _hasTrackingGap = false;

  int? _lastTimestampMs;

  RepCycleDetector({ThresholdsConfig? config})
      : config = config ?? ThresholdsConfig.instance {
    _elbowSmoother = EmaSmoother(alpha: this.config.emaAlpha);
    _bodySmoother = EmaSmoother(alpha: this.config.emaAlpha);
  }

  RepPhase get phase => _phase;
  List<EvaluatedRep> get reps => List.unmodifiable(_reps);
  int get validRepCount => _reps.where((r) => r.valid).length;
  double? get currentSmoothedElbow => _elbowSmoother.currentValue;
  double? get currentSmoothedBody => _bodySmoother.currentValue;

  void reset() {
    _elbowSmoother.reset();
    _bodySmoother.reset();
    _phase = RepPhase.waitingForInitialTop;
    _reps.clear();
    _lastTimestampMs = null;
  }

  /// Processes a single raw sample `[t_ms, raw_elbow, raw_body, conf]`.
  /// If [nominalIntervalMs] is provided, uses `gap_multiplier * nominalIntervalMs`
  /// and `max_allowed_gap_ms` to detect mid-cycle tracking gaps.
  /// Returns the newly completed [EvaluatedRep] if this sample finished a cycle.
  EvaluatedRep? processSample({
    required int tMs,
    required double rawElbow,
    required double rawBody,
    required double conf,
    double? nominalIntervalMs,
  }) {
    // Drop samples outside the battle timer window (t > battle_timer_seconds * 1000)
    if (tMs > config.battleTimerSeconds * 1000) {
      return null;
    }

    bool stepHasSevereGap = false;
    if (_lastTimestampMs != null) {
      final deltaMs = tMs - _lastTimestampMs!;
      final gapThreshold = nominalIntervalMs != null
          ? config.gapMultiplier * nominalIntervalMs
          : config.maxAllowedGapMs.toDouble();
      if (deltaMs > gapThreshold && deltaMs > config.maxAllowedGapMs) {
        stepHasSevereGap = true;
      }
    }
    _lastTimestampMs = tMs;

    final smoothedElbow = _elbowSmoother.addSample(rawElbow);
    final smoothedBody = _bodySmoother.addSample(rawBody);

    switch (_phase) {
      case RepPhase.waitingForInitialTop:
        if (smoothedElbow >= config.lockoutElbowAngleMin) {
          _phase = RepPhase.atTop;
          _topPeakAngle = smoothedElbow;
          _topPeakMs = tMs;
        }
        return null;

      case RepPhase.atTop:
        if (smoothedElbow >= _topPeakAngle) {
          _topPeakAngle = smoothedElbow;
          _topPeakMs = tMs;
        } else if (_topPeakAngle - smoothedElbow >=
            config.hysteresisMarginDegrees) {
          _phase = RepPhase.descending;
          _cycleStartMs = _topPeakMs;
          _cycleStartPeakAngle = _topPeakAngle;
          _troughAngle = smoothedElbow;
          _bottomMs = tMs;
          _maxBodyDeviation = smoothedBody;
          _minConfidence = conf;
          _hasTrackingGap = stepHasSevereGap;
        }
        return null;

      case RepPhase.descending:
        _maxBodyDeviation = math.max(_maxBodyDeviation, smoothedBody);
        _minConfidence = math.min(_minConfidence, conf);
        if (stepHasSevereGap) {
          _hasTrackingGap = true;
        }

        if (smoothedElbow < _troughAngle) {
          _troughAngle = smoothedElbow;
          _bottomMs = tMs;
        } else if (smoothedElbow >=
            _troughAngle + config.hysteresisMarginDegrees) {
          // Reversal at bottom: verify excursion >= min_cycle_excursion_degrees
          final descentExcursion = _cycleStartPeakAngle - _troughAngle;
          if (descentExcursion < config.minCycleExcursionDegrees) {
            // Micro-jitter smaller than min_cycle_excursion_degrees: not a cycle
            _phase = RepPhase.atTop;
            _topPeakAngle = smoothedElbow;
            _topPeakMs = tMs;
          } else if (smoothedElbow >= config.lockoutElbowAngleMin) {
            final rep = _finalizeCycle(
              topMs: tMs,
              endPeakAngle: smoothedElbow,
            );
            _phase = RepPhase.atTop;
            _topPeakAngle = smoothedElbow;
            _topPeakMs = tMs;
            return rep;
          } else {
            _phase = RepPhase.ascending;
            _returnPeakAngle = smoothedElbow;
            _returnPeakMs = tMs;
          }
        }
        return null;

      case RepPhase.ascending:
        _maxBodyDeviation = math.max(_maxBodyDeviation, smoothedBody);
        _minConfidence = math.min(_minConfidence, conf);
        if (stepHasSevereGap) {
          _hasTrackingGap = true;
        }

        if (smoothedElbow >= _returnPeakAngle) {
          _returnPeakAngle = smoothedElbow;
          _returnPeakMs = tMs;
        }

        // Case A: Full lockout achieved at top
        if (smoothedElbow >= config.lockoutElbowAngleMin) {
          final rep = _finalizeCycle(
            topMs: tMs,
            endPeakAngle: smoothedElbow,
          );
          _phase = RepPhase.atTop;
          _topPeakAngle = smoothedElbow;
          _topPeakMs = tMs;
          return rep;
        }

        // Case B: Reversed downward before lockout after ascending >= min_cycle_excursion_degrees
        final ascentExcursion = _returnPeakAngle - _troughAngle;
        if (ascentExcursion >= config.minCycleExcursionDegrees &&
            smoothedElbow <=
                _returnPeakAngle - config.hysteresisMarginDegrees) {
          final rep = _finalizeCycle(
            topMs: _returnPeakMs,
            endPeakAngle: _returnPeakAngle,
          );
          // Immediately begin next descending cycle from that incomplete peak
          _phase = RepPhase.descending;
          _cycleStartMs = _returnPeakMs;
          _cycleStartPeakAngle = _returnPeakAngle;
          _troughAngle = smoothedElbow;
          _bottomMs = tMs;
          _maxBodyDeviation = smoothedBody;
          _minConfidence = conf;
          _hasTrackingGap = stepHasSevereGap;
          return rep;
        }
        return null;
    }
  }

  EvaluatedRep _finalizeCycle({
    required int topMs,
    required double endPeakAngle,
  }) {
    final durationSeconds = (topMs - _cycleStartMs) / 1000.0;
    String? rejectReason;

    if (_hasTrackingGap) {
      rejectReason = 'TRACKING_GAP';
    } else if (_minConfidence < config.minJointConfidence) {
      rejectReason = 'LOW_CONFIDENCE';
    } else if (_troughAngle > config.depthElbowAngleMax) {
      rejectReason = 'SHALLOW';
    } else if (endPeakAngle < config.lockoutElbowAngleMin) {
      rejectReason = 'NO_LOCKOUT';
    } else if (_maxBodyDeviation > config.bodyLineTolerance) {
      rejectReason = 'BODY_LINE';
    } else if (durationSeconds < config.minRepDurationSeconds) {
      rejectReason = 'TOO_FAST';
    } else if (durationSeconds > config.maxRepDurationSeconds) {
      rejectReason = 'TOO_SLOW';
    }

    final rep = EvaluatedRep(
      repIndex: _reps.length + 1,
      startMs: _cycleStartMs,
      bottomMs: _bottomMs,
      topMs: topMs,
      minElbowAngle: _troughAngle,
      maxElbowAngle: endPeakAngle,
      maxBodyLineDeviation: _maxBodyDeviation,
      minConfidence: _minConfidence,
      valid: rejectReason == null,
      rejectReason: rejectReason,
    );
    _reps.add(rep);
    return rep;
  }

  /// Evaluates an entire attempt's raw `samples` array `[[t_ms, raw_elbow, raw_body, conf], ...]`
  /// identically to the server validation pipeline specified in `MATCH_DATA_FORMAT.md` v1.1.
  AttemptEvaluationResult evaluateAttemptSamples(List<List<num>> rawSamples) {
    reset();

    // 1. Filter out samples after battle_timer_seconds * 1000
    final maxWindowMs = config.battleTimerSeconds * 1000;
    final inWindow = rawSamples
        .where((s) => s.length >= 4 && s[0].toInt() <= maxWindowMs)
        .toList();

    final totalSamples = inWindow.length;
    if (totalSamples < 2) {
      return const AttemptEvaluationResult(
        attemptValid: false,
        attemptRejectReason: 'LOW_FPS',
        flags: [],
        totalSamples: 0,
        effectiveFps: 0.0,
        nominalIntervalMs: 0.0,
        droppedFrameGaps: [],
        reps: [],
      );
    }

    // 2. Compute frame intervals, median nominal_interval_ms, and effective_fps
    final deltas = <int>[];
    for (int i = 1; i < inWindow.length; i++) {
      final dt = inWindow[i][0].toInt() - inWindow[i - 1][0].toInt();
      if (dt > 0) deltas.add(dt);
    }
    deltas.sort();
    final double nominalIntervalMs;
    if (deltas.isEmpty) {
      nominalIntervalMs = 0.0;
    } else if (deltas.length.isOdd) {
      nominalIntervalMs = deltas[deltas.length ~/ 2].toDouble();
    } else {
      final mid = deltas.length ~/ 2;
      nominalIntervalMs = (deltas[mid - 1] + deltas[mid]) / 2.0;
    }

    final spanMs = inWindow.last[0].toInt() - inWindow.first[0].toInt();
    final effectiveFps =
        spanMs > 0 ? (totalSamples * 1000.0) / spanMs : 0.0;

    // 3. Identify dropped_frame_gaps where delta_t > gap_multiplier * nominal_interval_ms
    final gaps = <List<int>>[];
    final gapThreshold = config.gapMultiplier * nominalIntervalMs;
    for (int i = 1; i < inWindow.length; i++) {
      final prevT = inWindow[i - 1][0].toInt();
      final currT = inWindow[i][0].toInt();
      if ((currT - prevT) > gapThreshold) {
        gaps.add([prevT, currT]);
      }
    }

    // 4. Reject whole attempt if effective_fps < min_acceptable_fps (20.0)
    if (effectiveFps < config.minAcceptableFps) {
      return AttemptEvaluationResult(
        attemptValid: false,
        attemptRejectReason: 'LOW_FPS',
        flags: const ['LOW_FPS'],
        totalSamples: totalSamples,
        effectiveFps: effectiveFps,
        nominalIntervalMs: nominalIntervalMs,
        droppedFrameGaps: gaps,
        reps: const [],
      );
    }

    // 5. Run cycle detection over in-window samples
    for (final s in inWindow) {
      processSample(
        tMs: s[0].toInt(),
        rawElbow: s[1].toDouble(),
        rawBody: s[2].toDouble(),
        conf: s[3].toDouble(),
        nominalIntervalMs: nominalIntervalMs,
      );
    }

    // 6. Check max_reps_per_minute_flag (soft flag, never a hard reject per Rule 7)
    final flags = <String>[];
    if (spanMs > 0) {
      final repsPerMinute = (validRepCount * 60000.0) / spanMs;
      if (repsPerMinute > config.maxRepsPerMinuteFlag) {
        flags.add('MAX_REPS_PER_MINUTE_EXCEEDED');
      }
    }

    return AttemptEvaluationResult(
      attemptValid: true,
      attemptRejectReason: null,
      flags: flags,
      totalSamples: totalSamples,
      effectiveFps: effectiveFps,
      nominalIntervalMs: nominalIntervalMs,
      droppedFrameGaps: gaps,
      reps: List.unmodifiable(_reps),
    );
  }
}
