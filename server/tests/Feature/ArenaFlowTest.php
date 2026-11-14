<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ArenaFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_1v1_match_blindness_server_validation_and_elo_settlement(): void
    {
        $regA = $this->postJson('/api/auth/register', [
            'handle' => 'alpha_lift',
            'email' => 'alpha@pushgard.test',
            'password' => 'secret1234',
        ])->assertCreated();

        $regB = $this->postJson('/api/auth/register', [
            'handle' => 'beta_press',
            'email' => 'beta@pushgard.test',
            'password' => 'secret1234',
        ])->assertCreated();

        $tokenA = $regA->json('token');
        $tokenB = $regB->json('token');
        $idA = $regA->json('player.id');
        $idB = $regB->json('player.id');

        // 1. Player A creates a match challenging Player B
        $matchRes = $this->withToken($tokenA)->postJson('/api/matches', [
            'opponent_id' => $idB,
        ])->assertCreated();
        $matchId = $matchRes->json('match.id');

        // 2. Player A starts & gets single-use nonce
        $startA = $this->withToken($tokenA)
            ->postJson("/api/matches/{$matchId}/start")
            ->assertCreated();
        $nonceA = $startA->json('nonce');

        // 3. Player A submits clean 3-rep fixture
        $cleanSamples = json_decode(
            (string) file_get_contents(dirname(base_path()) . '/fixtures/01_clean_multi_rep.json'),
            true
        )['samples'];

        $submitA = $this->withToken($tokenA)->postJson("/api/matches/{$matchId}/submit", [
            'nonce' => $nonceA,
            'samples' => $cleanSamples,
        ])->assertOk();

        $this->assertSame(3, $submitA->json('server_valid_reps'));
        $this->assertSame('active', $submitA->json('match.status'));

        // 4. Blindness check: Player B cannot see Player A's score before submitting
        $this->app['auth']->forgetGuards();
        $listB = $this->withToken($tokenB)->getJson('/api/matches')->assertOk();
        $this->assertSame([], $listB->json('matches.0.attempts'));

        // 5. Idempotent retry succeeds cleanly
        $this->app['auth']->forgetGuards();
        $this->withToken($tokenA)->postJson("/api/matches/{$matchId}/submit", [
            'nonce' => $nonceA,
            'samples' => $cleanSamples,
        ])->assertOk()->assertJsonPath('idempotent', true);

        // 6. Player B starts & submits shallow/no-lockout fixture (0 valid reps)
        $this->app['auth']->forgetGuards();
        $startB = $this->withToken($tokenB)
            ->postJson("/api/matches/{$matchId}/start")
            ->assertCreated();
        $nonceB = $startB->json('nonce');

        $badSamples = json_decode(
            (string) file_get_contents(dirname(base_path()) . '/fixtures/02_shallow_and_no_lockout.json'),
            true
        )['samples'];

        $submitB = $this->withToken($tokenB)->postJson("/api/matches/{$matchId}/submit", [
            'nonce' => $nonceB,
            'samples' => $badSamples,
        ])->assertOk();

        $this->assertSame(1, $submitB->json('server_valid_reps'));
        $this->assertSame('completed', $submitB->json('match.status'));
        $this->assertSame($idA, $submitB->json('match.winner_id'));
        $this->assertSame('decision', $submitB->json('match.win_method'));
        $this->assertSame(20, $submitB->json('match.player_a_ego_delta'));
        $this->assertSame(-20, $submitB->json('match.player_b_ego_delta'));

        // 7. Verify updated profiles
        $this->app['auth']->forgetGuards();
        $this->withToken($tokenA)->getJson('/api/profile')
            ->assertOk()
            ->assertJsonPath('player.ego_rating', 1020)
            ->assertJsonPath('player.wins', 1)
            ->assertJsonPath('player.lifetime_valid_reps', 3);

        // 8. Nonce reuse with different payload triggers NONCE_REUSE flag
        $this->withToken($tokenA)->postJson("/api/matches/{$matchId}/submit", [
            'nonce' => $nonceA,
            'samples' => $badSamples,
        ])->assertStatus(409);

        $this->assertTrue(User::findOrFail($idA)->is_flagged);
    }

    public function test_leaderboards_gate_provisional_players_and_exclude_flagged_accounts(): void
    {
        $viewer = User::factory()->create([
            'handle' => 'VIEWER_ONE',
            'ego_rating' => 1450,
            'completed_matches' => 12,
            'wins' => 9,
            'ko_wins' => 4,
            'lifetime_valid_reps' => 500,
        ]);

        User::factory()->create([
            'handle' => 'TITAN_PRO',
            'ego_rating' => 1750,
            'completed_matches' => 25,
            'wins' => 20,
            'ko_wins' => 11,
            'lifetime_valid_reps' => 2400,
        ]);

        // Only 2 matches (provisional) -> excluded from default EGO leaderboard
        User::factory()->create([
            'handle' => 'ROOKIE_STREAK',
            'ego_rating' => 1850,
            'completed_matches' => 2,
            'wins' => 2,
        ]);

        // Flagged -> always excluded
        User::factory()->create([
            'handle' => 'FLAGGED_BOT',
            'ego_rating' => 2500,
            'completed_matches' => 30,
            'is_flagged' => true,
        ]);

        $res = $this->actingAs($viewer)
            ->getJson('/api/leaderboards?type=ego')
            ->assertOk();

        $handles = array_column($res->json('leaderboard'), 'handle');
        $this->assertSame(['TITAN_PRO', 'VIEWER_ONE'], $handles);
        $this->assertSame(2, $res->json('my_rank'));

        // KO leaderboard
        $koRes = $this->actingAs($viewer)
            ->getJson('/api/leaderboards?type=ko')
            ->assertOk();
        $this->assertSame('TITAN_PRO', $koRes->json('leaderboard.0.handle'));
    }

    public function test_guest_mode_and_social_oauth_create_real_db_players(): void
    {
        // Guest creates a real DB user with a unique generated handle + warning
        $guestRes = $this->postJson('/api/auth/guest')->assertCreated();
        $this->assertTrue($guestRes->json('player.is_guest'));
        $this->assertSame('guest', $guestRes->json('player.provider'));
        $this->assertStringStartsWith('GUEST_', $guestRes->json('player.handle'));
        $this->assertStringContainsString('no backup recovery', $guestRes->json('warning'));

        $guestToken = $guestRes->json('token');
        $this->withToken($guestToken)
            ->getJson('/api/profile')
            ->assertOk()
            ->assertJsonPath('player.id', $guestRes->json('player.id'));

        // Google OAuth creates/signs in a non-guest player
        $this->app['auth']->forgetGuards();
        $googleRes = $this->postJson('/api/auth/oauth', [
            'provider' => 'google',
            'provider_id' => 'google-uid-12345',
            'email' => 'spartan@gmail.com',
            'handle' => 'GMAIL_WARRIOR',
        ])->assertOk();

        $this->assertFalse($googleRes->json('player.is_guest'));
        $this->assertSame('google', $googleRes->json('player.provider'));
        $this->assertSame('GMAIL_WARRIOR', $googleRes->json('player.handle'));

        // Facebook OAuth creates/signs in a non-guest player
        $fbRes = $this->postJson('/api/auth/oauth', [
            'provider' => 'facebook',
            'provider_id' => 'fb-uid-99999',
        ])->assertOk();

        $this->assertFalse($fbRes->json('player.is_guest'));
        $this->assertSame('facebook', $fbRes->json('player.provider'));
        $this->assertStringStartsWith('META_', $fbRes->json('player.handle'));
    }
}
