import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'rank_badge.dart';

/// Hero Ego Score / Rating Card matching Page 3 of `Pushgard — Logo & App Icon.pdf`,
/// powered by Win/Loss Elo Rating + Tug-of-War KOs + Lifetime Validated Reps.
class EgoCounterCard extends StatefulWidget {
  final int egoScore;
  final int battlesWon;
  final int totalBattles;
  final int koWins;
  final int lifetimeValidReps;
  final int weeklyDelta;
  final VoidCallback? onTap;

  const EgoCounterCard({
    super.key,
    required this.egoScore,
    this.battlesWon = 48,
    this.totalBattles = 54,
    this.koWins = 19,
    this.lifetimeValidReps = 12480,
    this.weeklyDelta = 310,
    this.onTap,
  });

  @override
  State<EgoCounterCard> createState() => _EgoCounterCardState();
}

class _EgoCounterCardState extends State<EgoCounterCard> {
  bool _isPressed = false;

  String _formatNumber(int value) {
    final s = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  ({String nextTier, int floor, int ceiling}) _tierProgress(int ego) {
    if (ego < 1000) return (nextTier: 'SPARTAN', floor: 600, ceiling: 1000);
    if (ego < 1300) return (nextTier: 'VANGUARD', floor: 1000, ceiling: 1300);
    if (ego < 1600) return (nextTier: 'TITAN II', floor: 1300, ceiling: 1600);
    if (ego < 1900) return (nextTier: 'GOD OF WAR', floor: 1600, ceiling: 1900);
    return (nextTier: 'MAX TIER', floor: 1900, ceiling: 2500);
  }

  @override
  Widget build(BuildContext context) {
    final losses = (widget.totalBattles - widget.battlesWon).clamp(0, 99999);
    final tier = _tierProgress(widget.egoScore);
    final span = (tier.ceiling - tier.floor).clamp(1, 9999);
    final progress = ((widget.egoScore - tier.floor) / span).clamp(0.0, 1.0);
    final pointsToNext = (tier.ceiling - widget.egoScore).clamp(0, 9999);

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
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
                  RankBadge(egoScore: widget.egoScore, compact: true),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _formatNumber(widget.egoScore),
                style: AppTypography.heroTitle(color: Colors.white).copyWith(
                  fontSize: 64,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Win/Loss Elo rating · ${widget.battlesWon}W – ${losses}L (${widget.koWins} Tug-of-War KOs)',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              // Next-tier progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: AppColors.background,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(color: AppColors.volt),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      tier.nextTier == 'MAX TIER'
                          ? 'APEX TIER UNLOCKED'
                          : '$pointsToNext EGO TO ${tier.nextTier}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.telemetryCode(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
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
                            text: '+${widget.weeklyDelta} EGO',
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
                      '${_formatNumber(widget.lifetimeValidReps)} valid reps',
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
        ),
      ),
    );
  }
}
