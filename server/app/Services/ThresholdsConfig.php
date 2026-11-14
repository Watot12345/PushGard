<?php

namespace App\Services;

use RuntimeException;

/**
 * Loads canonical PushGard thresholds from server/config/thresholds.json.
 * Zero hard-coded thresholds (Rule 4).
 */
final class ThresholdsConfig
{
    public readonly int $angleSampleRateHz;
    public readonly int $battleTimerSeconds;
    public readonly float $bodyLineTolerance;
    public readonly float $depthElbowAngleMax;
    public readonly int $eloInitialRating;
    public readonly int $eloKFactorProvisional;
    public readonly int $eloKFactorStandard;
    public readonly int $eloProvisionalMatchCount;
    public readonly int $eloRatingFloor;
    public readonly float $eloScaleFactor;
    public readonly float $emaAlpha;
    public readonly float $gapMultiplier;
    public readonly float $hysteresisMarginDegrees;
    public readonly int $knockoutLeadReps;
    public readonly float $lockoutElbowAngleMin;
    public readonly int $maxAllowedGapMs;
    public readonly float $maxRepDurationSeconds;
    public readonly int $maxRepsPerMinuteFlag;
    public readonly float $minAcceptableFps;
    public readonly float $minCycleExcursionDegrees;
    public readonly float $minJointConfidence;
    public readonly float $minRepDurationSeconds;
    public readonly int $rankTierSpartanMinEgo;
    public readonly int $rankTierVanguardMinEgo;
    public readonly int $rankTierTitanMinEgo;
    public readonly int $rankTierGodOfWarMinEgo;

    private function __construct(array $json)
    {
        $this->angleSampleRateHz = (int) $json['angle_sample_rate_hz'];
        $this->battleTimerSeconds = (int) $json['battle_timer_seconds'];
        $this->bodyLineTolerance = (float) $json['body_line_tolerance'];
        $this->depthElbowAngleMax = (float) $json['depth_elbow_angle_max'];
        $this->eloInitialRating = (int) $json['elo_initial_rating'];
        $this->eloKFactorProvisional = (int) $json['elo_k_factor_provisional'];
        $this->eloKFactorStandard = (int) $json['elo_k_factor_standard'];
        $this->eloProvisionalMatchCount = (int) $json['elo_provisional_match_count'];
        $this->eloRatingFloor = (int) $json['elo_rating_floor'];
        $this->eloScaleFactor = (float) $json['elo_scale_factor'];
        $this->emaAlpha = (float) $json['ema_alpha'];
        $this->gapMultiplier = (float) $json['gap_multiplier'];
        $this->hysteresisMarginDegrees = (float) $json['hysteresis_margin_degrees'];
        $this->knockoutLeadReps = (int) $json['knockout_lead_reps'];
        $this->lockoutElbowAngleMin = (float) $json['lockout_elbow_angle_min'];
        $this->maxAllowedGapMs = (int) $json['max_allowed_gap_ms'];
        $this->maxRepDurationSeconds = (float) $json['max_rep_duration_seconds'];
        $this->maxRepsPerMinuteFlag = (int) $json['max_reps_per_minute_flag'];
        $this->minAcceptableFps = (float) $json['min_acceptable_fps'];
        $this->minCycleExcursionDegrees = (float) $json['min_cycle_excursion_degrees'];
        $this->minJointConfidence = (float) $json['min_joint_confidence'];
        $this->minRepDurationSeconds = (float) $json['min_rep_duration_seconds'];
        $this->rankTierSpartanMinEgo = (int) $json['rank_tier_spartan_min_ego'];
        $this->rankTierVanguardMinEgo = (int) $json['rank_tier_vanguard_min_ego'];
        $this->rankTierTitanMinEgo = (int) $json['rank_tier_titan_min_ego'];
        $this->rankTierGodOfWarMinEgo = (int) $json['rank_tier_god_of_war_min_ego'];
    }

    public static function load(?string $path = null): self
    {
        $resolved = $path ?? base_path('config/thresholds.json');
        if (!is_file($resolved)) {
            throw new RuntimeException("Thresholds config not found at {$resolved}");
        }

        $decoded = json_decode((string) file_get_contents($resolved), true);
        if (!is_array($decoded)) {
            throw new RuntimeException("Invalid JSON in thresholds config at {$resolved}");
        }

        return new self($decoded);
    }
}
