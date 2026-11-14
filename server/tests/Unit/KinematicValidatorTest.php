<?php

namespace Tests\Unit;

use App\Services\KinematicValidator;
use App\Services\ThresholdsConfig;
use Tests\TestCase;

class KinematicValidatorTest extends TestCase
{
    private KinematicValidator $validator;

    protected function setUp(): void
    {
        parent::setUp();
        $this->validator = new KinematicValidator(ThresholdsConfig::load());
    }

    public function test_shared_fixtures_match_expected_outputs(): void
    {
        $fixtures = [
            '01_clean_multi_rep.json',
            '02_shallow_and_no_lockout.json',
            '03_bad_body_line_and_speed.json',
            '04_tracking_gap_and_low_conf.json',
            '05_jitter_and_out_of_window.json',
            '06_low_fps_attempt.json',
        ];

        foreach ($fixtures as $fileName) {
            $path = dirname(base_path()) . '/fixtures/' . $fileName;
            $this->assertFileExists($path, "Missing shared fixture {$fileName}");

            $data = json_decode((string) file_get_contents($path), true);
            $expected = $data['expected'];

            $result = $this->validator->evaluateAttemptSamples($data['samples']);

            $this->assertSame($expected['attempt_valid'], $result['attempt_valid'], "attempt_valid mismatch in {$fileName}");
            $this->assertSame($expected['attempt_reject_reason'], $result['attempt_reject_reason'], "attempt_reject_reason mismatch in {$fileName}");
            $this->assertSame($expected['valid_rep_count'], $result['valid_rep_count'], "valid_rep_count mismatch in {$fileName}");
            $this->assertSame($expected['rejected_rep_count'], $result['rejected_rep_count'], "rejected_rep_count mismatch in {$fileName}");
            $this->assertCount(count($expected['reps']), $result['reps'], "cycle count mismatch in {$fileName}");

            foreach ($expected['reps'] as $i => $expRep) {
                $actRep = $result['reps'][$i];
                $this->assertSame($expRep['rep_index'], $actRep['rep_index'], "rep_index mismatch in {$fileName}");
                $this->assertSame($expRep['valid'], $actRep['valid'], "rep #{$expRep['rep_index']} valid mismatch in {$fileName}");
                $this->assertSame($expRep['reject_reason'], $actRep['reject_reason'], "rep #{$expRep['rep_index']} reject_reason mismatch in {$fileName}");
            }
        }
    }

    public function test_non_monotonic_timestamps_are_rejected_and_flagged(): void
    {
        $samples = [
            [0, 165.0, 5.0, 0.92],
            [40, 150.0, 5.0, 0.92],
            [20, 130.0, 5.0, 0.92],
        ];

        $result = $this->validator->evaluateAttemptSamples($samples);

        $this->assertFalse($result['attempt_valid']);
        $this->assertSame('NON_MONOTONIC_TIMESTAMPS', $result['attempt_reject_reason']);
        $this->assertContains('NON_MONOTONIC_TIMESTAMPS', $result['flags']);
    }

    public function test_tug_of_war_knockout_detects_first_player_to_reach_15_rep_lead(): void
    {
        // Player A hits 15 valid reps by 15000ms while B has 0 -> A wins by KO at 15000ms
        $a = range(1000, 16000, 1000);
        $b = [16500, 17500];

        $ko = $this->validator->evaluateTugOfWarKnockout($a, $b);

        $this->assertTrue($ko['is_knockout']);
        $this->assertSame('A', $ko['winner']);
        $this->assertSame(15000, $ko['ko_timestamp_ms']);
        $this->assertSame(15, $ko['lead_at_ko']);
    }
}
