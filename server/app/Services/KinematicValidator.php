<?php

namespace App\Services;

/**
 * Server-side deterministic kinematic rep validator (Rule 3: server never trusts client rep counts).
 * Exact parity with mobile RepCycleDetector & MATCH_DATA_FORMAT.md v1.1.
 */
final class KinematicValidator
{
    private const PHASE_WAITING_FOR_INITIAL_TOP = 'waiting_for_initial_top';
    private const PHASE_AT_TOP = 'at_top';
    private const PHASE_DESCENDING = 'descending';
    private const PHASE_ASCENDING = 'ascending';

    private EmaSmoother $elbowSmoother;
    private EmaSmoother $bodySmoother;

    private string $phase = self::PHASE_WAITING_FOR_INITIAL_TOP;
    /** @var array<int, array<string, mixed>> */
    private array $reps = [];

    private int $topPeakMs = 0;
    private float $topPeakAngle = 0.0;

    private int $cycleStartMs = 0;
    private float $cycleStartPeakAngle = 0.0;
    private int $bottomMs = 0;
    private float $troughAngle = 180.0;
    private int $returnPeakMs = 0;
    private float $returnPeakAngle = 0.0;

    private float $maxBodyDeviation = 0.0;
    private float $minConfidence = 1.0;
    private bool $hasTrackingGap = false;
    private ?int $lastTimestampMs = null;

    public function __construct(
        private readonly ThresholdsConfig $config,
    ) {
        $this->elbowSmoother = new EmaSmoother($this->config->emaAlpha);
        $this->bodySmoother = new EmaSmoother($this->config->emaAlpha);
    }

    /**
     * @param array<int, array<int, int|float>> $rawSamples [[t_ms, raw_elbow, raw_body, conf], ...]
     * @return array<string, mixed>
     */
    public function evaluateAttemptSamples(array $rawSamples): array
    {
        $this->reset();

        $maxWindowMs = $this->config->battleTimerSeconds * 1000;
        $inWindow = array_values(array_filter(
            $rawSamples,
            static fn ($s): bool => is_array($s) && count($s) >= 4 && ((int) $s[0]) <= $maxWindowMs
        ));

        $totalSamples = count($inWindow);
        if ($totalSamples < 2) {
            return [
                'attempt_valid' => false,
                'attempt_reject_reason' => 'LOW_FPS',
                'flags' => [],
                'total_samples' => 0,
                'effective_fps' => 0.0,
                'nominal_interval_ms' => 0.0,
                'dropped_frame_gaps' => [],
                'valid_rep_count' => 0,
                'rejected_rep_count' => 0,
                'valid_rep_timestamps_ms' => [],
                'reps' => [],
            ];
        }

        // Check monotonic timestamps (flag if client sent out-of-order timestamps)
        $flags = [];
        for ($i = 1; $i < $totalSamples; $i++) {
            if (((int) $inWindow[$i][0]) < ((int) $inWindow[$i - 1][0])) {
                $flags[] = 'NON_MONOTONIC_TIMESTAMPS';
                return [
                    'attempt_valid' => false,
                    'attempt_reject_reason' => 'NON_MONOTONIC_TIMESTAMPS',
                    'flags' => $flags,
                    'total_samples' => $totalSamples,
                    'effective_fps' => 0.0,
                    'nominal_interval_ms' => 0.0,
                    'dropped_frame_gaps' => [],
                    'valid_rep_count' => 0,
                    'rejected_rep_count' => 0,
                    'valid_rep_timestamps_ms' => [],
                    'reps' => [],
                ];
            }
        }

        $deltas = [];
        for ($i = 1; $i < $totalSamples; $i++) {
            $dt = ((int) $inWindow[$i][0]) - ((int) $inWindow[$i - 1][0]);
            if ($dt > 0) {
                $deltas[] = $dt;
            }
        }
        sort($deltas);

        $nominalIntervalMs = 0.0;
        $deltaCount = count($deltas);
        if ($deltaCount > 0) {
            if ($deltaCount % 2 === 1) {
                $nominalIntervalMs = (float) $deltas[intdiv($deltaCount, 2)];
            } else {
                $mid = intdiv($deltaCount, 2);
                $nominalIntervalMs = ($deltas[$mid - 1] + $deltas[$mid]) / 2.0;
            }
        }

        $spanMs = ((int) $inWindow[$totalSamples - 1][0]) - ((int) $inWindow[0][0]);
        $effectiveFps = $spanMs > 0 ? ($totalSamples * 1000.0) / $spanMs : 0.0;

        $gaps = [];
        $gapThreshold = $this->config->gapMultiplier * $nominalIntervalMs;
        for ($i = 1; $i < $totalSamples; $i++) {
            $prevT = (int) $inWindow[$i - 1][0];
            $currT = (int) $inWindow[$i][0];
            if (($currT - $prevT) > $gapThreshold) {
                $gaps[] = [$prevT, $currT];
            }
        }

        if ($effectiveFps < $this->config->minAcceptableFps) {
            return [
                'attempt_valid' => false,
                'attempt_reject_reason' => 'LOW_FPS',
                'flags' => ['LOW_FPS'],
                'total_samples' => $totalSamples,
                'effective_fps' => $effectiveFps,
                'nominal_interval_ms' => $nominalIntervalMs,
                'dropped_frame_gaps' => $gaps,
                'valid_rep_count' => 0,
                'rejected_rep_count' => 0,
                'valid_rep_timestamps_ms' => [],
                'reps' => [],
            ];
        }

        foreach ($inWindow as $s) {
            $this->processSample(
                (int) $s[0],
                (float) $s[1],
                (float) $s[2],
                (float) $s[3],
                $nominalIntervalMs,
            );
        }

        $validReps = array_values(array_filter($this->reps, static fn (array $r): bool => $r['valid'] === true));
        $validRepCount = count($validReps);
        $rejectedRepCount = count($this->reps) - $validRepCount;

        if ($spanMs > 0) {
            $repsPerMinute = ($validRepCount * 60000.0) / $spanMs;
            if ($repsPerMinute > $this->config->maxRepsPerMinuteFlag) {
                $flags[] = 'MAX_REPS_PER_MINUTE_EXCEEDED';
            }
        }

        return [
            'attempt_valid' => true,
            'attempt_reject_reason' => null,
            'flags' => $flags,
            'total_samples' => $totalSamples,
            'effective_fps' => round($effectiveFps, 2),
            'nominal_interval_ms' => round($nominalIntervalMs, 2),
            'dropped_frame_gaps' => $gaps,
            'valid_rep_count' => $validRepCount,
            'rejected_rep_count' => $rejectedRepCount,
            'valid_rep_timestamps_ms' => array_map(static fn (array $r): int => (int) $r['top_ms'], $validReps),
            'reps' => $this->reps,
        ];
    }

    /**
     * Replays both players' server-validated rep completion timestamps (ms relative to match start)
     * to determine if either player achieved a +[knockout_lead_reps] (+15) Tug-of-War KO first.
     *
     * @param array<int, int> $playerATimestampsMs
     * @param array<int, int> $playerBTimestampsMs
     * @return array{is_knockout: bool, winner: ?string, ko_timestamp_ms: ?int, lead_at_ko: int}
     */
    public function evaluateTugOfWarKnockout(array $playerATimestampsMs, array $playerBTimestampsMs): array
    {
        $events = [];
        foreach ($playerATimestampsMs as $t) {
            $events[] = ['t' => (int) $t, 'who' => 'A'];
        }
        foreach ($playerBTimestampsMs as $t) {
            $events[] = ['t' => (int) $t, 'who' => 'B'];
        }

        usort($events, static fn (array $x, array $y): int => $x['t'] <=> $y['t']);

        $scoreA = 0;
        $scoreB = 0;
        $koLead = $this->config->knockoutLeadReps;

        $i = 0;
        $n = count($events);
        while ($i < $n) {
            $t = $events[$i]['t'];
            // Process all events at the exact same millisecond before checking KO
            while ($i < $n && $events[$i]['t'] === $t) {
                if ($events[$i]['who'] === 'A') {
                    $scoreA++;
                } else {
                    $scoreB++;
                }
                $i++;
            }

            $diff = $scoreA - $scoreB;
            if ($diff >= $koLead) {
                return [
                    'is_knockout' => true,
                    'winner' => 'A',
                    'ko_timestamp_ms' => $t,
                    'lead_at_ko' => $diff,
                ];
            }
            if (-$diff >= $koLead) {
                return [
                    'is_knockout' => true,
                    'winner' => 'B',
                    'ko_timestamp_ms' => $t,
                    'lead_at_ko' => -$diff,
                ];
            }
        }

        return [
            'is_knockout' => false,
            'winner' => null,
            'ko_timestamp_ms' => null,
            'lead_at_ko' => 0,
        ];
    }

    private function reset(): void
    {
        $this->elbowSmoother->reset();
        $this->bodySmoother->reset();
        $this->phase = self::PHASE_WAITING_FOR_INITIAL_TOP;
        $this->reps = [];
        $this->lastTimestampMs = null;
    }

    private function processSample(
        int $tMs,
        float $rawElbow,
        float $rawBody,
        float $conf,
        float $nominalIntervalMs,
    ): void {
        if ($tMs > $this->config->battleTimerSeconds * 1000) {
            return;
        }

        $stepHasSevereGap = false;
        if ($this->lastTimestampMs !== null) {
            $deltaMs = $tMs - $this->lastTimestampMs;
            $gapThreshold = $this->config->gapMultiplier * $nominalIntervalMs;
            if ($deltaMs > $gapThreshold && $deltaMs > $this->config->maxAllowedGapMs) {
                $stepHasSevereGap = true;
            }
        }
        $this->lastTimestampMs = $tMs;

        $smoothedElbow = $this->elbowSmoother->addSample($rawElbow);
        $smoothedBody = $this->bodySmoother->addSample($rawBody);

        switch ($this->phase) {
            case self::PHASE_WAITING_FOR_INITIAL_TOP:
                if ($smoothedElbow >= $this->config->lockoutElbowAngleMin) {
                    $this->phase = self::PHASE_AT_TOP;
                    $this->topPeakAngle = $smoothedElbow;
                    $this->topPeakMs = $tMs;
                }
                return;

            case self::PHASE_AT_TOP:
                if ($smoothedElbow >= $this->topPeakAngle) {
                    $this->topPeakAngle = $smoothedElbow;
                    $this->topPeakMs = $tMs;
                } elseif (($this->topPeakAngle - $smoothedElbow) >= $this->config->hysteresisMarginDegrees) {
                    $this->phase = self::PHASE_DESCENDING;
                    $this->cycleStartMs = $this->topPeakMs;
                    $this->cycleStartPeakAngle = $this->topPeakAngle;
                    $this->troughAngle = $smoothedElbow;
                    $this->bottomMs = $tMs;
                    $this->maxBodyDeviation = $smoothedBody;
                    $this->minConfidence = $conf;
                    $this->hasTrackingGap = $stepHasSevereGap;
                }
                return;

            case self::PHASE_DESCENDING:
                $this->maxBodyDeviation = max($this->maxBodyDeviation, $smoothedBody);
                $this->minConfidence = min($this->minConfidence, $conf);
                if ($stepHasSevereGap) {
                    $this->hasTrackingGap = true;
                }

                if ($smoothedElbow < $this->troughAngle) {
                    $this->troughAngle = $smoothedElbow;
                    $this->bottomMs = $tMs;
                } elseif ($smoothedElbow >= ($this->troughAngle + $this->config->hysteresisMarginDegrees)) {
                    $descentExcursion = $this->cycleStartPeakAngle - $this->troughAngle;
                    if ($descentExcursion < $this->config->minCycleExcursionDegrees) {
                        $this->phase = self::PHASE_AT_TOP;
                        $this->topPeakAngle = $smoothedElbow;
                        $this->topPeakMs = $tMs;
                    } elseif ($smoothedElbow >= $this->config->lockoutElbowAngleMin) {
                        $this->finalizeCycle($tMs, $smoothedElbow);
                        $this->phase = self::PHASE_AT_TOP;
                        $this->topPeakAngle = $smoothedElbow;
                        $this->topPeakMs = $tMs;
                    } else {
                        $this->phase = self::PHASE_ASCENDING;
                        $this->returnPeakAngle = $smoothedElbow;
                        $this->returnPeakMs = $tMs;
                    }
                }
                return;

            case self::PHASE_ASCENDING:
                $this->maxBodyDeviation = max($this->maxBodyDeviation, $smoothedBody);
                $this->minConfidence = min($this->minConfidence, $conf);
                if ($stepHasSevereGap) {
                    $this->hasTrackingGap = true;
                }

                if ($smoothedElbow >= $this->returnPeakAngle) {
                    $this->returnPeakAngle = $smoothedElbow;
                    $this->returnPeakMs = $tMs;
                }

                if ($smoothedElbow >= $this->config->lockoutElbowAngleMin) {
                    $this->finalizeCycle($tMs, $smoothedElbow);
                    $this->phase = self::PHASE_AT_TOP;
                    $this->topPeakAngle = $smoothedElbow;
                    $this->topPeakMs = $tMs;
                    return;
                }

                $ascentExcursion = $this->returnPeakAngle - $this->troughAngle;
                if (
                    $ascentExcursion >= $this->config->minCycleExcursionDegrees &&
                    $smoothedElbow <= ($this->returnPeakAngle - $this->config->hysteresisMarginDegrees)
                ) {
                    $this->finalizeCycle($this->returnPeakMs, $this->returnPeakAngle);
                    $this->phase = self::PHASE_DESCENDING;
                    $this->cycleStartMs = $this->returnPeakMs;
                    $this->cycleStartPeakAngle = $this->returnPeakAngle;
                    $this->troughAngle = $smoothedElbow;
                    $this->bottomMs = $tMs;
                    $this->maxBodyDeviation = $smoothedBody;
                    $this->minConfidence = $conf;
                    $this->hasTrackingGap = $stepHasSevereGap;
                }
                return;
        }
    }

    private function finalizeCycle(int $topMs, float $endPeakAngle): void
    {
        $durationSeconds = ($topMs - $this->cycleStartMs) / 1000.0;
        $rejectReason = null;

        if ($this->hasTrackingGap) {
            $rejectReason = 'TRACKING_GAP';
        } elseif ($this->minConfidence < $this->config->minJointConfidence) {
            $rejectReason = 'LOW_CONFIDENCE';
        } elseif ($this->troughAngle > $this->config->depthElbowAngleMax) {
            $rejectReason = 'SHALLOW';
        } elseif ($endPeakAngle < $this->config->lockoutElbowAngleMin) {
            $rejectReason = 'NO_LOCKOUT';
        } elseif ($this->maxBodyDeviation > $this->config->bodyLineTolerance) {
            $rejectReason = 'BODY_LINE';
        } elseif ($durationSeconds < $this->config->minRepDurationSeconds) {
            $rejectReason = 'TOO_FAST';
        } elseif ($durationSeconds > $this->config->maxRepDurationSeconds) {
            $rejectReason = 'TOO_SLOW';
        }

        $this->reps[] = [
            'rep_index' => count($this->reps) + 1,
            'start_ms' => $this->cycleStartMs,
            'bottom_ms' => $this->bottomMs,
            'top_ms' => $topMs,
            'min_elbow_angle' => round($this->troughAngle, 2),
            'max_elbow_angle' => round($endPeakAngle, 2),
            'max_body_line_deviation' => round($this->maxBodyDeviation, 2),
            'min_confidence' => round($this->minConfidence, 2),
            'valid' => $rejectReason === null,
            'reject_reason' => $rejectReason,
        ];
    }
}
