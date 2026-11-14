<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SuspicionFlag extends Model
{
    protected $fillable = [
        'user_id',
        'match_id',
        'attempt_id',
        'code',
        'severity_score',
        'details_json',
        'resolved',
    ];

    protected function casts(): array
    {
        return [
            'severity_score' => 'integer',
            'details_json' => 'array',
            'resolved' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
