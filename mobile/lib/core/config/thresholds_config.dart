import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Reads canonical PushGard rules from `assets/config/thresholds.json`
/// (synced from root `config/thresholds.json`) and provides pure Elo Rating
/// and Tug-of-War battle bar math.
class ThresholdsConfig {
  final int angleSampleRateHz;
  final int battleTimerSeconds;
  final double bodyLineTolerance;
  final double depthElbowAngleMax;
  final int eloInitialRating;
  final int eloKFactorProvisional;
  final int eloKFactorStandard;
  final int eloProvisionalMatchCount;
  final int eloRatingFloor;
  final double eloScaleFactor;
  final double emaAlpha;
  final double gapMultiplier;
  final double hysteresisMarginDegrees;
  final int knockoutLeadReps;
  final double lockoutElbowAngleMin;
  final int maxAllowedGapMs;
  final double maxRepDurationSeconds;
  final int maxRepsPerMinuteFlag;
  final double minAcceptableFps;
  final double minCycleExcursionDegrees;
  final double minJointConfidence;
  final double minRepDurationSeconds;
  final int rankTierSpartanMinEgo;
  final int rankTierVanguardMinEgo;
  final int rankTierTitanMinEgo;
  final int rankTierGodOfWarMinEgo;

  const ThresholdsConfig({
    this.angleSampleRateHz = 20,
    this.battleTimerSeconds = 60,
    this.bodyLineTolerance = 15.0,
    this.depthElbowAngleMax = 90.0,
    this.eloInitialRating = 1000,
    this.eloKFactorProvisional = 40,
    this.eloKFactorStandard = 24,
    this.eloProvisionalMatchCount = 10,
    this.eloRatingFloor = 100,
    this.eloScaleFactor = 400.0,
    this.emaAlpha = 0.35,
    this.gapMultiplier = 2.5,
    this.hysteresisMarginDegrees = 5.0,
    this.knockoutLeadReps = 15,
    this.lockoutElbowAngleMin = 160.0,
    this.maxAllowedGapMs = 500,
    this.maxRepDurationSeconds = 8.0,
    this.maxRepsPerMinuteFlag = 90,
    this.minAcceptableFps = 20.0,
    this.minCycleExcursionDegrees = 25.0,
    this.minJointConfidence = 0.60,
    this.minRepDurationSeconds = 0.5,
    this.rankTierSpartanMinEgo = 1000,
    this.rankTierVanguardMinEgo = 1300,
    this.rankTierTitanMinEgo = 1600,
    this.rankTierGodOfWarMinEgo = 1900,
  });

  static ThresholdsConfig instance = const ThresholdsConfig();
  static bool _isLoaded = false;

  static Future<ThresholdsConfig> loadFromAsset() async {
    if (_isLoaded) return instance;
    try {
      final raw = await rootBundle.loadString('assets/config/thresholds.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      instance = ThresholdsConfig.fromJson(map);
      _isLoaded = true;
      return instance;
    } catch (_) {
      return instance;
    }
  }

  factory ThresholdsConfig.fromJson(Map<String, dynamic> json) {
    return ThresholdsConfig(
      angleSampleRateHz: (json['angle_sample_rate_hz'] as num?)?.toInt() ?? 20,
      battleTimerSeconds: (json['battle_timer_seconds'] as num?)?.toInt() ?? 60,
      bodyLineTolerance: (json['body_line_tolerance'] as num?)?.toDouble() ?? 15.0,
      depthElbowAngleMax: (json['depth_elbow_angle_max'] as num?)?.toDouble() ?? 90.0,
      eloInitialRating: (json['elo_initial_rating'] as num?)?.toInt() ?? 1000,
      eloKFactorProvisional: (json['elo_k_factor_provisional'] as num?)?.toInt() ?? 40,
      eloKFactorStandard: (json['elo_k_factor_standard'] as num?)?.toInt() ?? 24,
      eloProvisionalMatchCount: (json['elo_provisional_match_count'] as num?)?.toInt() ?? 10,
      eloRatingFloor: (json['elo_rating_floor'] as num?)?.toInt() ?? 100,
      eloScaleFactor: (json['elo_scale_factor'] as num?)?.toDouble() ?? 400.0,
      emaAlpha: (json['ema_alpha'] as num?)?.toDouble() ?? 0.35,
      gapMultiplier: (json['gap_multiplier'] as num?)?.toDouble() ?? 2.5,
      hysteresisMarginDegrees: (json['hysteresis_margin_degrees'] as num?)?.toDouble() ?? 5.0,
      knockoutLeadReps: (json['knockout_lead_reps'] as num?)?.toInt() ?? 15,
      lockoutElbowAngleMin: (json['lockout_elbow_angle_min'] as num?)?.toDouble() ?? 160.0,
      maxAllowedGapMs: (json['max_allowed_gap_ms'] as num?)?.toInt() ?? 500,
      maxRepDurationSeconds: (json['max_rep_duration_seconds'] as num?)?.toDouble() ?? 8.0,
      maxRepsPerMinuteFlag: (json['max_reps_per_minute_flag'] as num?)?.toInt() ?? 90,
      minAcceptableFps: (json['min_acceptable_fps'] as num?)?.toDouble() ?? 20.0,
      minCycleExcursionDegrees: (json['min_cycle_excursion_degrees'] as num?)?.toDouble() ?? 25.0,
      minJointConfidence: (json['min_joint_confidence'] as num?)?.toDouble() ?? 0.60,
      minRepDurationSeconds: (json['min_rep_duration_seconds'] as num?)?.toDouble() ?? 0.5,
      rankTierSpartanMinEgo: (json['rank_tier_spartan_min_ego'] as num?)?.toInt() ?? 1000,
      rankTierVanguardMinEgo: (json['rank_tier_vanguard_min_ego'] as num?)?.toInt() ?? 1300,
      rankTierTitanMinEgo: (json['rank_tier_titan_min_ego'] as num?)?.toInt() ?? 1600,
      rankTierGodOfWarMinEgo: (json['rank_tier_god_of_war_min_ego'] as num?)?.toInt() ?? 1900,
    );
  }

  /// Computes Tug-of-War bar ratio in [0.0, 1.0].
  /// Starts at 0.5 (50/50 center).
  /// Hitting +[knockoutLeadReps] (default +15) reaches 1.0 (Instant KO Victory).
  /// Falling behind by -[knockoutLeadReps] reaches 0.0 (Instant KO Defeat).
  double computeTugOfWarRatio({
    required int playerValidReps,
    required int opponentValidReps,
  }) {
    final lead = playerValidReps - opponentValidReps;
    final raw = 0.5 + (lead / (2.0 * knockoutLeadReps));
    return raw.clamp(0.0, 1.0);
  }

  /// Returns true if either player has reached the KO lead differential.
  bool isKnockoutReached({
    required int playerValidReps,
    required int opponentValidReps,
  }) {
    return (playerValidReps - opponentValidReps).abs() >= knockoutLeadReps;
  }

  /// Expected win score E_A in [0.0, 1.0] using standard Elo logistic curve.
  double expectedWinScore({
    required int playerEgo,
    required int opponentEgo,
  }) {
    final exponent = (opponentEgo - playerEgo) / eloScaleFactor;
    return 1.0 / (1.0 + math.pow(10.0, exponent));
  }

  /// Computes integer Ego Rating delta for a match outcome:
  /// actualScore: 1.0 = Win, 0.5 = Draw, 0.0 = Loss.
  int computeEloDelta({
    required int playerEgo,
    required int opponentEgo,
    required double actualScore,
    int completedMatches = 20,
  }) {
    final k = completedMatches < eloProvisionalMatchCount
        ? eloKFactorProvisional
        : eloKFactorStandard;
    final expected = expectedWinScore(
      playerEgo: playerEgo,
      opponentEgo: opponentEgo,
    );
    final rawDelta = (k * (actualScore - expected)).round();
    final updated = math.max(eloRatingFloor, playerEgo + rawDelta);
    return updated - playerEgo;
  }
}
