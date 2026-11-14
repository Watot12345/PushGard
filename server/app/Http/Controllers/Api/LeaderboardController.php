<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\EgoRatingService;
use App\Services\ThresholdsConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeaderboardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $config = ThresholdsConfig::load();
        $elo = new EgoRatingService($config);

        $type = $request->query('type', 'ego');
        $includeProvisional = $request->boolean('include_provisional', false);
        $minMatches = $includeProvisional ? 0 : $config->eloProvisionalMatchCount;

        $query = User::query()
            ->where('is_flagged', false)
            ->when($type === 'ego' && $minMatches > 0, fn ($q) => $q->where('completed_matches', '>=', $minMatches));

        match ($type) {
            'ko' => $query->orderByDesc('ko_wins')->orderByDesc('ego_rating'),
            'reps' => $query->orderByDesc('lifetime_valid_reps')->orderByDesc('ego_rating'),
            default => $query->orderByDesc('ego_rating')->orderByDesc('wins'),
        };

        $entries = $query->limit(50)->get()->values()->map(function (User $player, int $idx) use ($elo): array {
            return [
                'rank' => $idx + 1,
                'id' => $player->id,
                'handle' => $player->handle ?? $player->name,
                'ego_rating' => $player->ego_rating,
                'rank_tier' => $elo->rankTierForEgo($player->ego_rating),
                'completed_matches' => $player->completed_matches,
                'wins' => $player->wins,
                'losses' => $player->losses,
                'ko_wins' => $player->ko_wins,
                'lifetime_valid_reps' => $player->lifetime_valid_reps,
            ];
        });

        /** @var User|null $me */
        $me = $request->user();
        $myRank = null;
        if ($me && !$me->is_flagged) {
            if ($type !== 'ego' || $me->completed_matches >= $minMatches) {
                $ahead = match ($type) {
                    'ko' => User::where('is_flagged', false)->where('ko_wins', '>', $me->ko_wins)->count(),
                    'reps' => User::where('is_flagged', false)->where('lifetime_valid_reps', '>', $me->lifetime_valid_reps)->count(),
                    default => User::where('is_flagged', false)
                        ->when($minMatches > 0, fn ($q) => $q->where('completed_matches', '>=', $minMatches))
                        ->where('ego_rating', '>', $me->ego_rating)
                        ->count(),
                };
                $myRank = $ahead + 1;
            }
        }

        return response()->json([
            'type' => $type,
            'min_matches_required' => $type === 'ego' ? $minMatches : 0,
            'my_rank' => $myRank,
            'leaderboard' => $entries,
        ]);
    }
}
