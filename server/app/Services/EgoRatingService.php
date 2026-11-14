<?php

namespace App\Services;

/**
 * Pure Win/Loss Elo Ego Rating engine driven by ThresholdsConfig.
 */
final class EgoRatingService
{
    public function __construct(
        private readonly ThresholdsConfig $config,
    ) {}

    public function expectedWinScore(int $playerEgo, int $opponentEgo): float
    {
        $exponent = ($opponentEgo - $playerEgo) / $this->config->eloScaleFactor;
        return 1.0 / (1.0 + pow(10.0, $exponent));
    }

    /**
     * @param float $actualScore 1.0 = Win, 0.5 = Draw, 0.0 = Loss
     */
    public function computeEloDelta(
        int $playerEgo,
        int $opponentEgo,
        float $actualScore,
        int $completedMatches,
    ): int {
        $k = $completedMatches < $this->config->eloProvisionalMatchCount
            ? $this->config->eloKFactorProvisional
            : $this->config->eloKFactorStandard;

        $expected = $this->expectedWinScore($playerEgo, $opponentEgo);
        $rawDelta = (int) round($k * ($actualScore - $expected));
        $updated = max($this->config->eloRatingFloor, $playerEgo + $rawDelta);

        return $updated - $playerEgo;
    }

    public function rankTierForEgo(int $ego): string
    {
        if ($ego >= $this->config->rankTierGodOfWarMinEgo) {
            return 'God of War';
        }
        if ($ego >= $this->config->rankTierTitanMinEgo) {
            return 'Titan';
        }
        if ($ego >= $this->config->rankTierVanguardMinEgo) {
            return 'Vanguard';
        }
        return 'Spartan';
    }
}
