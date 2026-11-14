<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchAttempt extends Model
{
    protected $fillable = [
        'match_id',
        'user_id',
        'nonce',
        'payload_hash',
        'started_at',
        'expires_at',
        'submitted_at',
        'status',
        'server_valid_reps',
        'rejected_reps',
        'effective_fps',
        'rep_timestamps_json',
        'flags_json',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'expires_at' => 'datetime',
            'submitted_at' => 'datetime',
            'server_valid_reps' => 'integer',
            'rejected_reps' => 'integer',
            'effective_fps' => 'float',
            'rep_timestamps_json' => 'array',
            'flags_json' => 'array',
        ];
    }

    public function match(): BelongsTo
    {
        return $this->belongsTo(GameMatch::class, 'match_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
