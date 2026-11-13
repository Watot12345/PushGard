import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pushgard_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../match/screens/framing_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _activeTab = 0; // 0: Ranks Bracket, 1: Battle Log

  void _showRivalSheet(BuildContext context, Map<String, dynamic> row) {
    final name = row['name'] as String;
    final ego = row['ego'] as int;
    final record = row['record'] as String;
    final kos = row['kos'] as int;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'RIVAL PROFILE',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.trackedLabel(
                        color: AppColors.volt,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RankBadge(egoScore: ego, compact: true),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: AppTypography.sectionTitle(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '$ego EGO · $record · $kos Tug-of-War KOs',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              PushGardButton(
                text: 'CHALLENGE RIVAL',
                icon: Icons.bolt_rounded,
                variant: ButtonVariant.primary,
                height: 54,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FramingScreen(isBattle: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMatchBreakdownSheet(BuildContext context, BattleLogEntry item) {
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
                'VERIFIED MATCH BREAKDOWN',
                style: AppTypography.trackedLabel(
                  color: AppColors.volt,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'vs. [${item.opponent}]',
                    style: AppTypography.sectionTitle(color: Colors.white),
                  ),
                  Text(
                    item.egoDelta,
                    style: AppTypography.bodyBold(
                      color: item.isPositive
                          ? AppColors.volt
                          : AppColors.coralFix,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metricBox('YOUR REPS', '${item.validReps}', true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _metricBox('RIVAL REPS', '${item.opponentReps}', false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Outcome: ${item.outcome} · ${item.method}',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.telemetryCode(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.sectionTitle(
              color: highlight ? AppColors.volt : Colors.white,
            ).copyWith(fontSize: 26),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerSessionStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final losses = (store.totalBattles - store.battlesWon).clamp(0, 99999);
        final standings = <Map<String, dynamic>>[
          {'name': 'APEX_REAPER', 'record': '56W - 4L', 'kos': 29, 'ego': 1945, 'isMe': false},
          {'name': 'IRON_VALKYRIE', 'record': '51W - 7L', 'kos': 24, 'ego': 1860, 'isMe': false},
          {'name': 'SPARTAN_99', 'record': '49W - 8L', 'kos': 21, 'ego': 1815, 'isMe': false},
          {
            'name': 'YOU (VANGUARD_01)',
            'record': '${store.battlesWon}W - ${losses}L',
            'kos': store.koWins,
            'ego': store.egoRating,
            'isMe': true,
          },
          {'name': 'CYBER_KONG', 'record': '44W - 11L', 'kos': 16, 'ego': 1755, 'isMe': false},
          {'name': 'MARCUS_FIT', 'record': '39W - 14L', 'kos': 12, 'ego': 1690, 'isMe': false},
          {'name': 'NIGHT_HAWK', 'record': '35W - 18L', 'kos': 9, 'ego': 1640, 'isMe': false},
        ]..sort((a, b) => (b['ego'] as int).compareTo(a['ego'] as int));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RankShieldCrest(size: 30),
                            const SizedBox(width: 10),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RankBadge(egoScore: store.egoRating, compact: true),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Mode Switcher Pills (Volt Lime vs Slate)
                  Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          'RANKS',
                          Icons.leaderboard_rounded,
                          0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTabButton(
                          'BATTLE LOG',
                          Icons.history_rounded,
                          1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _activeTab == 0
                          ? _buildLeagueBracketView(standings)
                          : _buildMatchLogView(store.battleHistory),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String title, IconData icon, int index) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.volt : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.background : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.cardHeadline(
                  color: active ? AppColors.background : AppColors.textSecondary,
                ).copyWith(fontSize: 14, letterSpacing: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueBracketView(List<Map<String, dynamic>> standings) {
    return ListView.separated(
      key: const ValueKey('league_bracket'),
      itemCount: standings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = standings[index];
        final int rank = index + 1;
        final bool isMe = row['isMe'] as bool;
        final bool inPromotion = rank <= 5;

        return GestureDetector(
          onTap: isMe
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  _showRivalSheet(context, row);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: isMe ? Border.all(color: AppColors.volt, width: 2.0) : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: AppTypography.telemetryCode(
                      color: inPromotion ? AppColors.volt : AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name'] as String,
                        style: AppTypography.bodyBold(
                          color: isMe ? AppColors.volt : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row['record']} · ${row['kos']} KOs',
                        style: AppTypography.body(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${row['ego']}',
                  style: AppTypography.sectionTitle(
                    color: inPromotion ? AppColors.volt : Colors.white,
                  ).copyWith(fontSize: 22),
                ),
                if (!isMe) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchLogView(List<BattleLogEntry> history) {
    return ListView.separated(
      key: const ValueKey('match_log'),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showMatchBreakdownSheet(context, item);
          },
          child: Container(
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
                        'vs. [${item.opponent}]',
                        style: AppTypography.sectionTitle(color: Colors.white)
                            .copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.validReps} – ${item.opponentReps} · ${item.method}',
                        style: AppTypography.body(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.egoDelta,
                      style: AppTypography.bodyBold(
                        color: item.isPositive
                            ? AppColors.volt
                            : AppColors.coralFix,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.outcome,
                      style: AppTypography.telemetryCode(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
