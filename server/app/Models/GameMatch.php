<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GameMatch extends Model
{
    protected $table = 'game_matches';

    protected $fillable = [
        'player_a_id',
        'player_b_id',
        'status',
        'winner_id',
        'win_method',
        'ko_timestamp_ms',
        'player_a_ego_delta',
        'player_b_ego_delta',
        'expires_at',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'ko_timestamp_ms' => 'integer',
            'player_a_ego_delta' => 'integer',
            'player_b_ego_delta' => 'integer',
            'expires_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function playerA(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player_a_id');
    }

    public function playerB(): BelongsTo
    {
        return $this->belongsTo(User::class, 'player_b_id');
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(MatchAttempt::class, 'match_id');
    }
}
