import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'rank_badge.dart';

/// Hero Ego Score / Rating Card matching Page 3 of `Pushgard — Logo & App Icon.pdf`,
/// powered by Win/Loss Elo Rating + Tug-of-War KOs + Lifetime Validated Reps.
class EgoCounterCard extends StatelessWidget {
  final int egoScore;
  final int battlesWon;
  final int totalBattles;
  final int koWins;
  final int lifetimeValidReps;
  final int weeklyDelta;

  const EgoCounterCard({
    super.key,
    required this.egoScore,
    this.battlesWon = 48,
    this.totalBattles = 54,
    this.koWins = 19,
    this.lifetimeValidReps = 12480,
    this.weeklyDelta = 310,
  });

  String _formatNumber(int value) {
    final s = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final losses = (totalBattles - battlesWon).clamp(0, 99999);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'EGO RANKING',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.trackedLabel(
                    color: AppColors.volt,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RankBadge(egoScore: egoScore, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatNumber(egoScore),
            style: AppTypography.heroTitle(color: Colors.white).copyWith(
              fontSize: 64,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Win/Loss Elo rating · ${battlesWon}W – ${losses}L ($koWins Tug-of-War KOs)',
            style: AppTypography.body(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: AppTypography.body(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    children: [
                      const TextSpan(text: 'This week: '),
                      TextSpan(
                        text: '+$weeklyDelta EGO',
                        style: AppTypography.bodyBold(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_formatNumber(lifetimeValidReps)} valid reps',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.telemetryCode(
                    color: AppColors.volt,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
