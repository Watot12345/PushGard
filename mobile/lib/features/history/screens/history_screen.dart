import 'package:flutter/material.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/rank_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _activeTab = 0; // 0: Ranks Bracket, 1: Battle Log

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
                      Expanded(child: _buildTabButton('RANKS', 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTabButton('BATTLE LOG', 1)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Expanded(
                    child: _activeTab == 0
                        ? _buildLeagueBracketView(standings)
                        : _buildMatchLogView(store.battleHistory),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String title, int index) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: active ? AppColors.volt : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: AppTypography.cardHeadline(
            color: active ? AppColors.background : AppColors.textSecondary,
          ).copyWith(fontSize: 14, letterSpacing: 1.4),
        ),
      ),
    );
  }

  Widget _buildLeagueBracketView(List<Map<String, dynamic>> standings) {
    return ListView.separated(
      itemCount: standings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = standings[index];
        final int rank = index + 1;
        final bool isMe = row['isMe'] as bool;
        final bool inPromotion = rank <= 5;

        return Container(
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchLogView(List<BattleLogEntry> history) {
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];

        return Container(
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
        );
      },
    );
  }
}
