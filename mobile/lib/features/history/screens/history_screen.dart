import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/pushgard_api_client.dart';
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
  int _activeTab = 0; // 0: Ranks / Leaderboard, 1: Battle Log
  String _leaderboardType = 'ego'; // 'ego' | 'ko' | 'reps'
  LeaderboardResponse? _liveLeaderboard;
  bool _loadingBoard = false;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (_loadingBoard) return;
    setState(() => _loadingBoard = true);
    try {
      final res = await PushgardApiClient.instance.fetchLeaderboard(
        type: _leaderboardType,
      );
      if (mounted) {
        setState(() {
          _liveLeaderboard = res;
          _loadingBoard = false;
        });
      }
    } catch (_) {
      // Server offline or unauthenticated -> graceful fallback to local bracket
      if (mounted) {
        setState(() {
          _liveLeaderboard = null;
          _loadingBoard = false;
        });
      }
    }
  }

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
          {'name': 'APEX_REAPER', 'record': '56W - 4L', 'kos': 29, 'ego': 1945, 'reps': 16200, 'isMe': false},
          {'name': 'IRON_VALKYRIE', 'record': '51W - 7L', 'kos': 24, 'ego': 1860, 'reps': 14800, 'isMe': false},
          {'name': 'SPARTAN_99', 'record': '49W - 8L', 'kos': 21, 'ego': 1815, 'reps': 13900, 'isMe': false},
          {
            'name': 'YOU (VANGUARD_01)',
            'record': '${store.battlesWon}W - ${losses}L',
            'kos': store.koWins,
            'ego': store.egoRating,
            'reps': store.lifetimeValidReps,
            'isMe': true,
          },
          {'name': 'CYBER_KONG', 'record': '44W - 11L', 'kos': 16, 'ego': 1755, 'reps': 11400, 'isMe': false},
          {'name': 'MARCUS_FIT', 'record': '39W - 14L', 'kos': 12, 'ego': 1690, 'reps': 9850, 'isMe': false},
          {'name': 'NIGHT_HAWK', 'record': '35W - 18L', 'kos': 9, 'ego': 1640, 'reps': 8400, 'isMe': false},
        ]..sort((a, b) {
            final key = _leaderboardType == 'ko'
                ? 'kos'
                : (_leaderboardType == 'reps' ? 'reps' : 'ego');
            return (b[key] as int).compareTo(a[key] as int);
          });

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

  Widget _buildFilterChip(String label, String type) {
    final active = _leaderboardType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _leaderboardType = type);
          _loadLeaderboard();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.volt.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.volt : Colors.white10,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.telemetryCode(
              color: active ? AppColors.volt : AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueBracketView(List<Map<String, dynamic>> standings) {
    final live = _liveLeaderboard;
    final rows = live != null
        ? live.entries
            .map((e) => {
                  'name': e.handle,
                  'record': '${e.wins}W - ${e.losses}L',
                  'kos': e.koWins,
                  'ego': e.egoRating,
                  'reps': e.lifetimeValidReps,
                  'isMe': false,
                })
            .toList()
        : standings;

    return Column(
      key: const ValueKey('league_bracket'),
      children: [
        Row(
          children: [
            _buildFilterChip('EGO', 'ego'),
            const SizedBox(width: 8),
            _buildFilterChip('KO WINS', 'ko'),
            const SizedBox(width: 8),
            _buildFilterChip('REPS', 'reps'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: live != null ? AppColors.volt : Colors.white10,
                ),
              ),
              child: Text(
                live != null ? 'LIVE' : 'LOCAL',
                style: AppTypography.telemetryCode(
                  color: live != null ? AppColors.volt : AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              final int rank = index + 1;
              final bool isMe = row['isMe'] as bool;
              final bool inPromotion = rank <= 5;
              final int primaryValue = _leaderboardType == 'ko'
                  ? (row['kos'] as int)
                  : (_leaderboardType == 'reps'
                      ? (row['reps'] as int)
                      : (row['ego'] as int));

              return GestureDetector(
                onTap: isMe
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _showRivalSheet(context, row);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: isMe
                        ? Border.all(color: AppColors.volt, width: 2.0)
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#$rank',
                          style: AppTypography.telemetryCode(
                            color: inPromotion
                                ? AppColors.volt
                                : AppColors.textMuted,
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
                        '$primaryValue',
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
          ),
        ),
      ],
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
