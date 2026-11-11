import 'package:flutter/material.dart';
import '../../../core/state/player_session_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pushgard_button.dart';
import 'framing_screen.dart';

/// Matches Page 6 of `Pushgard — Logo & App Icon.pdf`:
/// "BATTLE RESULT / YOU WIN", side-by-side YOU (Volt border) vs [PLAYER B],
/// EGO RANKING card with Win/Loss Elo delta, REMATCH (Volt) & BACK HOME (Slate).
/// Commits match outcome into [PlayerSessionStore] once in `initState`.
class AttemptSummaryScreen extends StatefulWidget {
  final int validReps;
  final int opponentReps;
  final int shallowReps;
  final int noLockoutReps;
  final int bodyLineReps;
  final int maxComboStreak;
  final bool isBattle;
  final bool isKnockout;
  final bool isForfeit;

  const AttemptSummaryScreen({
    super.key,
    required this.validReps,
    this.opponentReps = 0,
    this.shallowReps = 0,
    this.noLockoutReps = 0,
    this.bodyLineReps = 0,
    this.maxComboStreak = 0,
    this.isBattle = true,
    this.isKnockout = false,
    this.isForfeit = false,
  });

  @override
  State<AttemptSummaryScreen> createState() => _AttemptSummaryScreenState();
}

class _AttemptSummaryScreenState extends State<AttemptSummaryScreen> {
  late final int _rivalFinalReps;
  late final int _eloDelta;
  late final int _newEgo;

  @override
  void initState() {
    super.initState();
    _rivalFinalReps = widget.isBattle
        ? (widget.opponentReps > 0
            ? widget.opponentReps
            : (widget.validReps > 3 ? widget.validReps - 3 : 12))
        : 0;

    final store = PlayerSessionStore.instance;
    _eloDelta = store.recordAttemptOutcome(
      isBattle: widget.isBattle,
      validReps: widget.validReps,
      opponentReps: _rivalFinalReps,
      isKnockout: widget.isKnockout,
      isForfeit: widget.isForfeit,
    );
    _newEgo = store.egoRating;
  }

  String _formatNumber(int value) {
    final s = value.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    double actualScore = 1.0;
    String headline = 'YOU WIN';
    bool didPlayerWin = true;

    if (widget.isBattle) {
      if (widget.isForfeit) {
        actualScore = 0.0;
        headline = 'FORFEIT';
        didPlayerWin = false;
      } else if (widget.validReps > _rivalFinalReps) {
        actualScore = 1.0;
        headline = widget.isKnockout ? 'KO WIN' : 'YOU WIN';
        didPlayerWin = true;
      } else if (widget.validReps == _rivalFinalReps) {
        actualScore = 0.5;
        headline = 'DRAW';
        didPlayerWin = false;
      } else {
        actualScore = 0.0;
        headline = 'YOU LOSE';
        didPlayerWin = false;
      }
    } else {
      headline = 'COMPLETE';
    }

    final String deltaSign = _eloDelta >= 0 ? '+$_eloDelta' : '$_eloDelta';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),
                  // 1. BATTLE RESULT + YOU WIN (Page 6 of PDF)
                  Text(
                    widget.isBattle ? 'BATTLE RESULT' : 'SOLO RESULT',
                    style: AppTypography.trackedLabel(
                      color: AppColors.volt,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: AppTypography.heroTitle(color: Colors.white).copyWith(
                      fontSize: 54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 2. Side-by-Side YOU vs [PLAYER B] Boxes (Page 6 of PDF)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: didPlayerWin
                                ? Border.all(color: AppColors.volt, width: 2.0)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'YOU',
                                style: AppTypography.body(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.validReps}',
                                style: AppTypography.heroTitle(
                                  color: Colors.white,
                                ).copyWith(fontSize: 54),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: (!didPlayerWin &&
                                    widget.isBattle &&
                                    actualScore == 0.0)
                                ? Border.all(
                                    color: AppColors.coralFix,
                                    width: 2.0,
                                  )
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.isBattle ? '[CYBER_KONG]' : 'FAULTS',
                                style: AppTypography.body(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.isBattle
                                    ? '$_rivalFinalReps'
                                    : '${widget.shallowReps + widget.noLockoutReps + widget.bodyLineReps}',
                                style: AppTypography.heroTitle(
                                  color: Colors.white,
                                ).copyWith(fontSize: 54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isKnockout
                        ? 'Tug-of-War +${widget.validReps - _rivalFinalReps} rep lead KO · verified by server'
                        : 'Valid reps, verified by the server',
                    style: AppTypography.body(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3. EGO RANKING Card (Page 6 of PDF)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'EGO RANKING',
                          style: AppTypography.trackedLabel(
                            color: AppColors.volt,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatNumber(_newEgo),
                          style: AppTypography.heroTitle(
                            color: Colors.white,
                          ).copyWith(fontSize: 58),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isBattle
                              ? '$deltaSign EGO rating (${actualScore == 1.0 ? "Win" : actualScore == 0.5 ? "Draw" : "Loss"}) · +${widget.validReps} valid reps added'
                              : '+${widget.validReps} valid reps added to lifetime total',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 4. REMATCH (Volt Lime) & BACK HOME (Dark Slate) Buttons (Page 6 of PDF)
              Column(
                children: [
                  PushGardButton(
                    text: 'REMATCH',
                    variant: ButtonVariant.primary,
                    height: 58,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              FramingScreen(isBattle: widget.isBattle),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  PushGardButton(
                    text: 'BACK HOME',
                    variant: ButtonVariant.secondary,
                    height: 58,
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
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
