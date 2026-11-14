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

    /**
     * Creates a real DB user in Guest mode with a unique handle and zero recovery backup.
     */
    public function guest(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'handle' => ['nullable', 'string', 'min:3', 'max:24', 'alpha_dash', 'unique:users,handle'],
        ]);

        $config = ThresholdsConfig::load();
        $handle = isset($validated['handle'])
            ? strtoupper($validated['handle'])
            : $this->generateUniqueHandle('GUEST');

        $user = User::create([
            'name' => $handle,
            'handle' => $handle,
            'provider' => 'guest',
            'is_guest' => true,
            'ego_rating' => $config->eloInitialRating,
        ]);

        $token = $user->createToken('pushgard-guest')->plainTextToken;

        return response()->json([
            'token' => $token,
            'warning' => 'Guest account has no backup recovery. Clearing app data permanently forfeits access.',
            'player' => $this->serializePlayer($user, new EgoRatingService($config)),
        ], 201);
    }

    /**
     * Signs in or creates a player via Google (Gmail) or Facebook OAuth identity.
     */
    public function oauth(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'provider' => ['required', 'string', 'in:google,facebook'],
            'provider_id' => ['required', 'string', 'min:3', 'max:128'],
            'email' => ['nullable', 'email', 'max:255'],
            'handle' => ['nullable', 'string', 'min:3', 'max:24', 'alpha_dash'],
        ]);

        $config = ThresholdsConfig::load();
        $user = User::where('provider', $validated['provider'])
            ->where('provider_id', $validated['provider_id'])
            ->first();

        if (!$user && !empty($validated['email'])) {
            $user = User::where('email', $validated['email'])->first();
            if ($user) {
                $user->update([
                    'provider' => $validated['provider'],
                    'provider_id' => $validated['provider_id'],
                    'is_guest' => false,
                ]);
            }
        }

        if (!$user) {
            $basePrefix = $validated['provider'] === 'google' ? 'GMAIL' : 'META';
            $requestedHandle = isset($validated['handle']) ? strtoupper($validated['handle']) : null;
            $handle = ($requestedHandle && !User::where('handle', $requestedHandle)->exists())
                ? $requestedHandle
                : $this->generateUniqueHandle($basePrefix);

            $user = User::create([
                'name' => $handle,
                'handle' => $handle,
                'provider' => $validated['provider'],
                'provider_id' => $validated['provider_id'],
                'is_guest' => false,
                'email' => $validated['email'] ?? null,
                'ego_rating' => $config->eloInitialRating,
            ]);
        }

        $token = $user->createToken('pushgard-oauth')->plainTextToken;

        return response()->json([
            'token' => $token,
            'player' => $this->serializePlayer($user, new EgoRatingService($config)),
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

    private function generateUniqueHandle(string $prefix): string
    {
        do {
            $suffix = strtoupper(substr(bin2hex(random_bytes(3)), 0, 6));
            $candidate = "{$prefix}_{$suffix}";
        } while (User::where('handle', $candidate)->exists());

        return $candidate;
    }

    private function serializePlayer(User $user, EgoRatingService $elo): array
    {
        return [
            'id' => $user->id,
            'handle' => $user->handle ?? $user->name,
            'provider' => $user->provider ?? 'manual',
            'is_guest' => (bool) $user->is_guest,
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
