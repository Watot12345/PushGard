import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/thresholds_config.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ego_counter_card.dart';
import '../../../core/widgets/pushgard_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../auth/screens/auth_screen.dart';
import '../../match/screens/framing_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenSpike;

  const HomeScreen({super.key, this.onOpenSpike});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _marcusNudged = false;

  void _showRankLadderSheet(BuildContext context, int egoRating) {
    final tiers = [
      (name: 'GOD OF WAR', range: '1,900+ EGO', min: 1900, max: 99999),
      (name: 'TITAN II', range: '1,600 – 1,899 EGO', min: 1600, max: 1899),
      (name: 'VANGUARD', range: '1,300 – 1,599 EGO', min: 1300, max: 1599),
      (name: 'SPARTAN', range: '1,000 – 1,299 EGO', min: 1000, max: 1299),
      (name: 'IRON', range: '< 1,000 EGO', min: 0, max: 999),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EGO RANK TIERS',
                style: AppTypography.trackedLabel(
                  color: AppColors.volt,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Win/Loss Elo Ladder',
                style: AppTypography.sectionTitle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              for (final t in tiers) ...[
                Builder(
                  builder: (_) {
                    final isCurrent = egoRating >= t.min && egoRating <= t.max;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: isCurrent
                            ? Border.all(color: AppColors.volt, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              t.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyBold(
                                color: isCurrent ? AppColors.volt : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isCurrent ? '${t.range} · YOU' : t.range,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTypography.telemetryCode(
                                color: isCurrent
                                    ? AppColors.volt
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesSheet(BuildContext context, ThresholdsConfig cfg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BATTLE & ANTI-CHEAT RULES',
                style: AppTypography.trackedLabel(
                  color: AppColors.volt,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _ruleLine(
                'Tug-of-War Instant KO',
                '+${cfg.knockoutLeadReps} verified rep lead wins immediately.',
              ),
              _ruleLine(
                '${cfg.battleTimerSeconds}s Timer Decision',
                'Highest valid rep count when the clock hits 0:00 wins.',
              ),
              _ruleLine(
                'Strict Kinematic Form',
                '<=${cfg.depthElbowAngleMax.toInt()}° bottom depth, >=${cfg.lockoutElbowAngleMin.toInt()}° top lockout, <=${cfg.bodyLineTolerance.toInt()}° hip line.',
              ),
              _ruleLine(
                'Zero Video Upload',
                'Live camera only. Video stays on your phone.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleLine(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyBold(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: AppTypography.body(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showWaitingChallengeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHALLENGE STATUS',
                style: AppTypography.trackedLabel(
                  color: AppColors.volt,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'vs. [MARCUS_FIT]',
                style: AppTypography.sectionTitle(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'You posted 38 verified reps. Waiting for opponent attempt before timer expiry.',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              PushGardButton(
                text: _marcusNudged ? 'RIVAL NUDGED' : 'NUDGE RIVAL',
                icon: _marcusNudged
                    ? Icons.check_circle_outline_rounded
                    : Icons.notifications_active_outlined,
                variant: _marcusNudged
                    ? ButtonVariant.secondary
                    : ButtonVariant.primary,
                height: 52,
                onPressed: _marcusNudged
                    ? null
                    : () {
                        setState(() => _marcusNudged = true);
                        Navigator.of(ctx).pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerSessionStore.instance;
    final cfg = ThresholdsConfig.instance;
    final koLead = cfg.knockoutLeadReps;

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
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showRulesSheet(context, cfg);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+$koLead LEAD = KO',
                                style: AppTypography.telemetryCode(
                                  color: AppColors.volt,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.volt,
                                size: 13,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Compact Account Strip (Guest / Social / Manual Sign In)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: store.isGuest
                              ? AppColors.volt.withValues(alpha: 0.45)
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            store.isGuest
                                ? Icons.warning_amber_rounded
                                : Icons.verified_user_outlined,
                            color: store.isGuest
                                ? AppColors.volt
                                : AppColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              store.isGuest
                                  ? '${store.handle} · GUEST (NO BACKUP)'
                                  : '${store.handle} · ${store.provider.toUpperCase()}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.telemetryCode(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ACCOUNT',
                            style: AppTypography.telemetryCode(
                              color: AppColors.volt,
                              fontSize: 11,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.volt,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Hero Ego Card (Page 3 of PDF — reactive & tappable for Rank Ladder)
                  EgoCounterCard(
                    egoScore: store.egoRating,
                    battlesWon: store.battlesWon,
                    totalBattles: store.totalBattles,
                    koWins: store.koWins,
                    lifetimeValidReps: store.lifetimeValidReps,
                    weeklyDelta: store.weeklyEgoDelta,
                    onTap: () =>
                        _showRankLadderSheet(context, store.egoRating),
                  ),

                  const SizedBox(height: 18),

                  // 3. Primary Volt Lime "START BATTLE" Button (Page 3 of PDF)
                  PushGardButton(
                    text: 'START BATTLE',
                    icon: Icons.bolt_rounded,
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

                  // Challenge 2: Waiting for opponent (tappable to nudge)
                  _buildChallengeCard(
                    context: context,
                    opponent: 'vs. [MARCUS_FIT]',
                    subtitle: _marcusNudged
                        ? 'Rival nudged · You lead 38 reps'
                        : 'Waiting for their attempt · You lead 38 reps',
                    isActionable: false,
                    onCardTap: () {
                      HapticFeedback.selectionClick();
                      _showWaitingChallengeSheet(context);
                    },
                  ),

                  const SizedBox(height: 22),

                  // 5. Secondary Solo Calibration & Sensor Check Row
                  Row(
                    children: [
                      Expanded(
                        child: PushGardButton(
                          text: 'SOLO WARMUP',
                          icon: Icons.fitness_center_rounded,
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
                      if (widget.onOpenSpike != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: PushGardButton(
                            text: 'SENSOR CHECK',
                            icon: Icons.sensors_rounded,
                            variant: ButtonVariant.outline,
                            height: 48,
                            onPressed: widget.onOpenSpike,
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
    VoidCallback? onCardTap,
  }) {
    final card = Container(
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
                HapticFeedback.lightImpact();
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
          ] else if (onCardTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ],
      ),
    );

    if (onCardTap == null) return card;
    return GestureDetector(onTap: onCardTap, child: card);
  }
}
