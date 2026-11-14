<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GameMatch;
use App\Models\MatchAttempt;
use App\Models\SuspicionFlag;
use App\Models\User;
use App\Services\EgoRatingService;
use App\Services\KinematicValidator;
use App\Services\ThresholdsConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class MatchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $matches = GameMatch::with(['playerA:id,handle,ego_rating', 'playerB:id,handle,ego_rating', 'attempts'])
            ->where(function ($q) use ($user) {
                $q->where('player_a_id', $user->id)
                    ->orWhere('player_b_id', $user->id)
                    ->orWhere('status', 'open');
            })
            ->latest('id')
            ->limit(25)
            ->get()
            ->map(function (GameMatch $match) use ($user): array {
                $canSeeScores = $match->status === 'completed';

                return [
                    'id' => $match->id,
                    'status' => $match->status,
                    'player_a' => [
                        'id' => $match->playerA->id,
                        'handle' => $match->playerA->handle,
                        'ego_rating' => $match->playerA->ego_rating,
                    ],
                    'player_b' => $match->playerB ? [
                        'id' => $match->playerB->id,
                        'handle' => $match->playerB->handle,
                        'ego_rating' => $match->playerB->ego_rating,
                    ] : null,
                    'winner_id' => $match->winner_id,
                    'win_method' => $match->win_method,
                    'ko_timestamp_ms' => $match->ko_timestamp_ms,
                    'your_ego_delta' => $match->player_a_id === $user->id
                        ? $match->player_a_ego_delta
                        : ($match->player_b_id === $user->id ? $match->player_b_ego_delta : 0),
                    // Blindness rule: never reveal opponent reps until match completes
                    'attempts' => $canSeeScores ? $match->attempts->map(fn (MatchAttempt $a) => [
                        'user_id' => $a->user_id,
                        'server_valid_reps' => $a->server_valid_reps,
                        'rejected_reps' => $a->rejected_reps,
                        'status' => $a->status,
                    ])->values() : [],
                    'expires_at' => $match->expires_at?->toIso8601String(),
                    'completed_at' => $match->completed_at?->toIso8601String(),
                ];
            });

        return response()->json(['matches' => $matches]);
    }

    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $validated = $request->validate([
            'opponent_id' => ['nullable', 'integer', 'exists:users,id'],
        ]);

        if (isset($validated['opponent_id']) && (int) $validated['opponent_id'] === $user->id) {
            return response()->json(['message' => 'Cannot challenge yourself.'], 422);
        }

        $match = GameMatch::create([
            'player_a_id' => $user->id,
            'player_b_id' => $validated['opponent_id'] ?? null,
            'status' => isset($validated['opponent_id']) ? 'active' : 'open',
            'expires_at' => now()->addHours(24),
        ]);

        return response()->json([
            'match' => [
                'id' => $match->id,
                'status' => $match->status,
                'player_a_id' => $match->player_a_id,
                'player_b_id' => $match->player_b_id,
                'expires_at' => $match->expires_at->toIso8601String(),
            ],
        ], 201);
    }

    public function start(Request $request, GameMatch $match): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $config = ThresholdsConfig::load();

        if ($match->expires_at->isPast() || $match->status === 'completed') {
            return response()->json(['message' => 'Match is no longer active.'], 409);
        }

        if ($match->player_a_id !== $user->id && $match->player_b_id !== $user->id) {
            if ($match->player_b_id === null && $match->status === 'open') {
                $match->update([
                    'player_b_id' => $user->id,
                    'status' => 'active',
                ]);
            } else {
                return response()->json(['message' => 'You are not a participant in this match.'], 403);
            }
        }

        $existing = MatchAttempt::where('match_id', $match->id)
            ->where('user_id', $user->id)
            ->whereIn('status', ['issued', 'started', 'submitted'])
            ->first();

        if ($existing) {
            if ($existing->status === 'submitted') {
                return response()->json(['message' => 'You have already submitted an attempt for this match.'], 409);
            }

            return response()->json([
                'nonce' => $existing->nonce,
                'battle_timer_seconds' => $config->battleTimerSeconds,
                'expires_at' => $existing->expires_at->toIso8601String(),
            ]);
        }

        // Allow 60s battle + 30s upload grace window
        $attempt = MatchAttempt::create([
            'match_id' => $match->id,
            'user_id' => $user->id,
            'nonce' => Str::random(40),
            'started_at' => now(),
            'expires_at' => now()->addSeconds($config->battleTimerSeconds + 30),
            'status' => 'started',
        ]);

        return response()->json([
            'nonce' => $attempt->nonce,
            'battle_timer_seconds' => $config->battleTimerSeconds,
            'expires_at' => $attempt->expires_at->toIso8601String(),
        ], 201);
    }

    public function submit(Request $request, GameMatch $match): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $config = ThresholdsConfig::load();

        $validated = $request->validate([
            'nonce' => ['required', 'string'],
            'samples' => ['required', 'array', 'min:2'],
            'samples.*' => ['required', 'array', 'size:4'],
        ]);

        $payloadHash = hash('sha256', json_encode($validated['samples']));

        return DB::transaction(function () use ($match, $user, $validated, $payloadHash, $config): JsonResponse {
            /** @var MatchAttempt|null $attempt */
            $attempt = MatchAttempt::where('match_id', $match->id)
                ->where('user_id', $user->id)
                ->where('nonce', $validated['nonce'])
                ->lockForUpdate()
                ->first();

            if (!$attempt) {
                return response()->json(['message' => 'Invalid match nonce.'], 403);
            }

            // Idempotent retry on identical payload
            if ($attempt->status === 'submitted') {
                if ($attempt->payload_hash === $payloadHash) {
                    return response()->json([
                        'idempotent' => true,
                        'attempt_valid' => true,
                        'server_valid_reps' => $attempt->server_valid_reps,
                        'rejected_reps' => $attempt->rejected_reps,
                        'match_status' => $match->fresh()->status,
                    ]);
                }

                // Nonce reuse with different movement data -> flag!
                SuspicionFlag::create([
                    'user_id' => $user->id,
                    'match_id' => $match->id,
                    'attempt_id' => $attempt->id,
                    'code' => 'NONCE_REUSE',
                    'severity_score' => 50,
                    'details_json' => ['nonce' => $validated['nonce']],
                ]);
                $user->update(['is_flagged' => true]);

                return response()->json(['message' => 'Nonce already consumed with different payload.'], 409);
            }

            if ($attempt->expires_at->isPast()) {
                $attempt->update(['status' => 'forfeited']);
                return response()->json(['message' => 'Submission window expired; attempt forfeited.'], 409);
            }

            $validator = new KinematicValidator($config);
            $eval = $validator->evaluateAttemptSamples($validated['samples']);

            if (!$eval['attempt_valid']) {
                // Technical failure (e.g. LOW_FPS) voids attempt without crashing; flag if non-monotonic
                $isCheatFlag = in_array('NON_MONOTONIC_TIMESTAMPS', $eval['flags'], true);
                $attempt->update([
                    'status' => $isCheatFlag ? 'flagged' : 'voided',
                    'payload_hash' => $payloadHash,
                    'effective_fps' => $eval['effective_fps'],
                    'flags_json' => $eval['flags'],
                ]);

                if ($isCheatFlag) {
                    SuspicionFlag::create([
                        'user_id' => $user->id,
                        'match_id' => $match->id,
                        'attempt_id' => $attempt->id,
                        'code' => 'NON_MONOTONIC_TIMESTAMPS',
                        'severity_score' => 40,
                        'details_json' => $eval['flags'],
                    ]);
                }

                return response()->json([
                    'attempt_valid' => false,
                    'attempt_reject_reason' => $eval['attempt_reject_reason'],
                    'flags' => $eval['flags'],
                ], 422);
            }

            $hasSpeedFlag = in_array('MAX_REPS_PER_MINUTE_EXCEEDED', $eval['flags'], true);
            $attempt->update([
                'status' => $hasSpeedFlag ? 'flagged' : 'submitted',
                'payload_hash' => $payloadHash,
                'submitted_at' => now(),
                'server_valid_reps' => $eval['valid_rep_count'],
                'rejected_reps' => $eval['rejected_rep_count'],
                'effective_fps' => $eval['effective_fps'],
                'rep_timestamps_json' => $eval['valid_rep_timestamps_ms'],
                'flags_json' => $eval['flags'],
            ]);

            $user->increment('lifetime_valid_reps', $eval['valid_rep_count']);

            if ($hasSpeedFlag) {
                SuspicionFlag::create([
                    'user_id' => $user->id,
                    'match_id' => $match->id,
                    'attempt_id' => $attempt->id,
                    'code' => 'MAX_REPS_PER_MINUTE_EXCEEDED',
                    'severity_score' => 25,
                    'details_json' => ['valid_reps' => $eval['valid_rep_count']],
                ]);
                $user->update(['is_flagged' => true]);
            }

            // Check if both players have completed their attempts to settle EGO Rating
            $this->trySettleMatch($match, $validator, new EgoRatingService($config));

            $freshMatch = $match->fresh();
            return response()->json([
                'attempt_valid' => true,
                'server_valid_reps' => $eval['valid_rep_count'],
                'rejected_reps' => $eval['rejected_rep_count'],
                'flags' => $eval['flags'],
                'match' => [
                    'id' => $freshMatch->id,
                    'status' => $freshMatch->status,
                    'winner_id' => $freshMatch->winner_id,
                    'win_method' => $freshMatch->win_method,
                    'ko_timestamp_ms' => $freshMatch->ko_timestamp_ms,
                    'player_a_ego_delta' => $freshMatch->player_a_ego_delta,
                    'player_b_ego_delta' => $freshMatch->player_b_ego_delta,
                ],
            ]);
        });
    }

    private function trySettleMatch(
        GameMatch $match,
        KinematicValidator $validator,
        EgoRatingService $elo,
    ): void {
        if ($match->status === 'completed' || !$match->player_b_id) {
            return;
        }

        $attemptA = MatchAttempt::where('match_id', $match->id)
            ->where('user_id', $match->player_a_id)
            ->whereIn('status', ['submitted', 'flagged'])
            ->first();
        $attemptB = MatchAttempt::where('match_id', $match->id)
            ->where('user_id', $match->player_b_id)
            ->whereIn('status', ['submitted', 'flagged'])
            ->first();

        if (!$attemptA || !$attemptB) {
            return;
        }

        if ($attemptA->status === 'flagged' || $attemptB->status === 'flagged') {
            $match->update([
                'status' => 'flagged',
                'completed_at' => now(),
            ]);
            return;
        }

        /** @var User $playerA */
        $playerA = User::whereKey($match->player_a_id)->lockForUpdate()->firstOrFail();
        /** @var User $playerB */
        $playerB = User::whereKey($match->player_b_id)->lockForUpdate()->firstOrFail();

        $ko = $validator->evaluateTugOfWarKnockout(
            $attemptA->rep_timestamps_json ?? [],
            $attemptB->rep_timestamps_json ?? [],
        );

        $scoreA = 0.5;
        $scoreB = 0.5;
        $winnerId = null;
        $winMethod = 'draw';
        $koTimestampMs = null;

        if ($ko['is_knockout']) {
            $winMethod = 'ko';
            $koTimestampMs = $ko['ko_timestamp_ms'];
            if ($ko['winner'] === 'A') {
                $scoreA = 1.0;
                $scoreB = 0.0;
                $winnerId = $playerA->id;
            } else {
                $scoreA = 0.0;
                $scoreB = 1.0;
                $winnerId = $playerB->id;
            }
        } elseif ($attemptA->server_valid_reps > $attemptB->server_valid_reps) {
            $scoreA = 1.0;
            $scoreB = 0.0;
            $winnerId = $playerA->id;
            $winMethod = 'decision';
        } elseif ($attemptB->server_valid_reps > $attemptA->server_valid_reps) {
            $scoreA = 0.0;
            $scoreB = 1.0;
            $winnerId = $playerB->id;
            $winMethod = 'decision';
        }

        $deltaA = $elo->computeEloDelta($playerA->ego_rating, $playerB->ego_rating, $scoreA, $playerA->completed_matches);
        $deltaB = $elo->computeEloDelta($playerB->ego_rating, $playerA->ego_rating, $scoreB, $playerB->completed_matches);

        $playerA->update([
            'ego_rating' => $playerA->ego_rating + $deltaA,
            'completed_matches' => $playerA->completed_matches + 1,
            'wins' => $playerA->wins + ($scoreA === 1.0 ? 1 : 0),
            'losses' => $playerA->losses + ($scoreA === 0.0 ? 1 : 0),
            'draws' => $playerA->draws + ($scoreA === 0.5 ? 1 : 0),
            'ko_wins' => $playerA->ko_wins + ($winnerId === $playerA->id && $winMethod === 'ko' ? 1 : 0),
        ]);

        $playerB->update([
            'ego_rating' => $playerB->ego_rating + $deltaB,
            'completed_matches' => $playerB->completed_matches + 1,
            'wins' => $playerB->wins + ($scoreB === 1.0 ? 1 : 0),
            'losses' => $playerB->losses + ($scoreB === 0.0 ? 1 : 0),
            'draws' => $playerB->draws + ($scoreB === 0.5 ? 1 : 0),
            'ko_wins' => $playerB->ko_wins + ($winnerId === $playerB->id && $winMethod === 'ko' ? 1 : 0),
        ]);

        $match->update([
            'status' => 'completed',
            'winner_id' => $winnerId,
            'win_method' => $winMethod,
            'ko_timestamp_ms' => $koTimestampMs,
            'player_a_ego_delta' => $deltaA,
            'player_b_ego_delta' => $deltaB,
            'completed_at' => now(),
        ]);
    }
}
