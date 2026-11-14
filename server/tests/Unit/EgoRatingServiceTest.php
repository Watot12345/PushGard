<?php

namespace Tests\Unit;

use App\Services\EgoRatingService;
use App\Services\ThresholdsConfig;
use Tests\TestCase;

class EgoRatingServiceTest extends TestCase
{
    private EgoRatingService $elo;

    protected function setUp(): void
    {
        parent::setUp();
        $this->elo = new EgoRatingService(ThresholdsConfig::load());
    }

    public function test_equal_rating_win_and_loss_use_provisional_and_standard_k_factors(): void
    {
        // Provisional (<10 matches): K = 40, expected = 0.5 -> +20 win, -20 loss
        $this->assertSame(20, $this->elo->computeEloDelta(1000, 1000, 1.0, 0));
        $this->assertSame(-20, $this->elo->computeEloDelta(1000, 1000, 0.0, 9));

        // Standard (>=10 matches): K = 24, expected = 0.5 -> +12 win, -12 loss
        $this->assertSame(12, $this->elo->computeEloDelta(1500, 1500, 1.0, 10));
        $this->assertSame(-12, $this->elo->computeEloDelta(1500, 1500, 0.0, 20));
    }

    public function test_draw_against_higher_rated_opponent_gains_ego(): void
    {
        $delta = $this->elo->computeEloDelta(1200, 1600, 0.5, 20);
        $this->assertGreaterThan(0, $delta);
    }

    public function test_rating_floor_prevents_dropping_below_minimum_ego(): void
    {
        $delta = $this->elo->computeEloDelta(105, 105, 0.0, 0);
        $this->assertSame(-5, $delta);
    }

    public function test_rank_tier_boundaries(): void
    {
        $this->assertSame('Spartan', $this->elo->rankTierForEgo(1000));
        $this->assertSame('Vanguard', $this->elo->rankTierForEgo(1300));
        $this->assertSame('Titan', $this->elo->rankTierForEgo(1600));
        $this->assertSame('God of War', $this->elo->rankTierForEgo(1900));
    }
}
