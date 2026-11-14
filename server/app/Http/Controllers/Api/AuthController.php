<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\EgoRatingService;
use App\Services\ThresholdsConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'handle' => ['required', 'string', 'min:3', 'max:24', 'alpha_dash', 'unique:users,handle'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $config = ThresholdsConfig::load();
        $user = User::create([
            'name' => $validated['handle'],
            'handle' => strtoupper($validated['handle']),
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'ego_rating' => $config->eloInitialRating,
        ]);

        $token = $user->createToken('pushgard-mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'player' => $this->serializePlayer($user, new EgoRatingService($config)),
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $validated['email'])->first();
        if (!$user || !Hash::check($validated['password'], $user->password)) {
            return response()->json(['message' => 'Invalid credentials.'], 401);
        }

        $token = $user->createToken('pushgard-mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'player' => $this->serializePlayer($user, new EgoRatingService(ThresholdsConfig::load())),
        ]);
    }

    public function profile(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json([
            'player' => $this->serializePlayer($user, new EgoRatingService(ThresholdsConfig::load())),
        ]);
    }

    private function serializePlayer(User $user, EgoRatingService $elo): array
    {
        return [
            'id' => $user->id,
            'handle' => $user->handle ?? $user->name,
            'ego_rating' => $user->ego_rating,
            'rank_tier' => $elo->rankTierForEgo($user->ego_rating),
            'completed_matches' => $user->completed_matches,
            'wins' => $user->wins,
            'losses' => $user->losses,
            'draws' => $user->draws,
            'ko_wins' => $user->ko_wins,
            'lifetime_valid_reps' => $user->lifetime_valid_reps,
            'is_flagged' => $user->is_flagged,
        ];
    }
}
