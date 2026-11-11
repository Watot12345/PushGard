import 'package:flutter/material.dart';
import '../../../core/config/thresholds_config.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ego_counter_card.dart';
import '../../../core/widgets/pushgard_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../match/screens/framing_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenSpike;

  const HomeScreen({super.key, this.onOpenSpike});

  @override
  Widget build(BuildContext context) {
    final store = PlayerSessionStore.instance;
    final koLead = ThresholdsConfig.instance.knockoutLeadReps;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Official PushGard Header (Page 3 of PDF: Volt Shield + PUSHGARD)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RankShieldCrest(size: 34),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'PUSHGARD',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.brandWordmark(
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '+$koLead LEAD = KO',
                          style: AppTypography.telemetryCode(
                            color: AppColors.volt,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 2. Hero Ego Card (Page 3 of PDF — reactive to PlayerSessionStore)
                  EgoCounterCard(
                    egoScore: store.egoRating,
                    battlesWon: store.battlesWon,
                    totalBattles: store.totalBattles,
                    koWins: store.koWins,
                    lifetimeValidReps: store.lifetimeValidReps,
                    weeklyDelta: store.weeklyEgoDelta,
                  ),

                  const SizedBox(height: 18),

                  // 3. Primary Volt Lime "START BATTLE" Button (Page 3 of PDF)
                  PushGardButton(
                    text: 'START BATTLE',
                    variant: ButtonVariant.primary,
                    height: 60,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FramingScreen(isBattle: true),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // 4. CHALLENGES Section (Page 3 of PDF)
                  Text(
                    'CHALLENGES',
                    style: AppTypography.trackedLabel(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Challenge 1: Your turn with Volt "GO" button
                  _buildChallengeCard(
                    context: context,
                    opponent: 'vs. [CYBER_KONG]',
                    subtitle:
                        'Your turn · Tug-of-War (+13 EGO) · expires in 18h',
                    isActionable: true,
                  ),
                  const SizedBox(height: 12),

                  // Challenge 2: Waiting for opponent
                  _buildChallengeCard(
                    context: context,
                    opponent: 'vs. [MARCUS_FIT]',
                    subtitle: 'Waiting for their attempt · You lead 38 reps',
                    isActionable: false,
                  ),

                  const SizedBox(height: 22),

                  // 5. Secondary Solo Calibration & Hardware Spike Row
                  Row(
                    children: [
                      Expanded(
                        child: PushGardButton(
                          text: 'SOLO WARMUP',
                          variant: ButtonVariant.secondary,
                          height: 48,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FramingScreen(isBattle: false),
                              ),
                            );
                          },
                        ),
                      ),
                      if (onOpenSpike != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: PushGardButton(
                            text: 'STEP 0 SPIKE',
                            variant: ButtonVariant.outline,
                            height: 48,
                            onPressed: onOpenSpike,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard({
    required BuildContext context,
    required String opponent,
    required String subtitle,
    required bool isActionable,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent,
                  style: AppTypography.sectionTitle(color: Colors.white)
                      .copyWith(fontSize: 19),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.body(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (isActionable) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FramingScreen(isBattle: true),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.volt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'GO',
                  style: AppTypography.cardHeadline(
                    color: AppColors.background,
                  ).copyWith(fontSize: 16, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
