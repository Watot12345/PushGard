<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('handle', 32)->nullable()->unique()->after('name');
            $table->integer('ego_rating')->default(1000)->index();
            $table->integer('completed_matches')->default(0);
            $table->integer('wins')->default(0);
            $table->integer('losses')->default(0);
            $table->integer('draws')->default(0);
            $table->integer('ko_wins')->default(0)->index();
            $table->integer('lifetime_valid_reps')->default(0);
            $table->boolean('is_flagged')->default(false)->index();
        });

        Schema::create('game_matches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('player_a_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('player_b_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 24)->default('open')->index(); // open, active, completed, expired, flagged
            $table->foreignId('winner_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('win_method', 24)->nullable(); // ko, decision, draw, forfeit
            $table->integer('ko_timestamp_ms')->nullable();
            $table->integer('player_a_ego_delta')->default(0);
            $table->integer('player_b_ego_delta')->default(0);
            $table->timestamp('expires_at');
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('match_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('match_id')->nullable()->constrained('game_matches')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('nonce', 64)->unique();
            $table->string('payload_hash', 64)->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('submitted_at')->nullable();
            $table->string('status', 24)->default('issued')->index(); // issued, started, submitted, forfeited, voided, flagged
            $table->integer('server_valid_reps')->default(0);
            $table->integer('rejected_reps')->default(0);
            $table->float('effective_fps')->nullable();
            $table->json('rep_timestamps_json')->nullable();
            $table->json('flags_json')->nullable();
            $table->timestamps();
        });

        Schema::create('suspicion_flags', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('match_id')->nullable()->constrained('game_matches')->nullOnDelete();
            $table->foreignId('attempt_id')->nullable()->constrained('match_attempts')->nullOnDelete();
            $table->string('code', 64)->index();
            $table->integer('severity_score')->default(10);
            $table->json('details_json')->nullable();
            $table->boolean('resolved')->default(false)->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suspicion_flags');
        Schema::dropIfExists('match_attempts');
        Schema::dropIfExists('game_matches');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'handle',
                'ego_rating',
                'completed_matches',
                'wins',
                'losses',
                'draws',
                'ko_wins',
                'lifetime_valid_reps',
                'is_flagged',
            ]);
        });
    }
};
