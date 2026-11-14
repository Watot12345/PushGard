<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LeaderboardController;
use App\Http\Controllers\Api\MatchController;
use Illuminate\Support\Facades\Route;

Route::get('/health', static fn () => response()->json(['status' => 'ok', 'service' => 'pushgard-api']));

Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/guest', [AuthController::class, 'guest']);
Route::post('/auth/oauth', [AuthController::class, 'oauth']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profile', [AuthController::class, 'profile']);

    Route::get('/matches', [MatchController::class, 'index']);
    Route::post('/matches', [MatchController::class, 'store']);
    Route::post('/matches/{match}/start', [MatchController::class, 'start']);
    Route::post('/matches/{match}/submit', [MatchController::class, 'submit']);

    Route::get('/leaderboards', [LeaderboardController::class, 'index']);
});
