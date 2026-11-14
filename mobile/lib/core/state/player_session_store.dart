import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../config/thresholds_config.dart';

class BattleLogEntry {
  final String opponent;
  final String date;
  final int validReps;
  final int opponentReps;
  final String outcome;
  final String method;
  final String egoDelta;
  final bool isPositive;

  const BattleLogEntry({
    required this.opponent,
    required this.date,
    required this.validReps,
    required this.opponentReps,
    required this.outcome,
    required this.method,
    required this.egoDelta,
    required this.isPositive,
  });
}

/// Reactive session state store so completing a battle or solo session updates
/// Ego Rating (Win/Loss Elo), W-L record, Tug-of-War KOs, lifetime valid reps,
/// and the Ranks / Battle Log screens immediately.
class PlayerSessionStore extends ChangeNotifier {
  static final PlayerSessionStore instance = PlayerSessionStore();

  String _handle = 'VANGUARD_01';
  String _provider = 'local'; // local | guest | manual | google | facebook
  bool _isGuest = false;
  int _egoRating = 1780;
  int _battlesWon = 48;
  int _totalBattles = 54;
  int _koWins = 19;
  int _lifetimeValidReps = 12480;
  int _weeklyEgoDelta = 310;

  final List<BattleLogEntry> _battleHistory = [
    const BattleLogEntry(
      opponent: 'CYBER_KONG',
      date: 'Today · 10:14 AM',
      validReps: 42,
      opponentReps: 27,
      outcome: 'KO WIN',
      method: '+15 rep lead Tug-of-War KO',
      egoDelta: '+24 EGO',
      isPositive: true,
    ),
    const BattleLogEntry(
      opponent: 'MARCUS_FIT',
      date: 'Yesterday · 19:40',
      validReps: 41,
      opponentReps: 38,
      outcome: 'YOU WIN',
      method: '60s verified count',
      egoDelta: '+19 EGO',
      isPositive: true,
    ),
    const BattleLogEntry(
      opponent: 'APEX_REAPER',
      date: '09 Nov · 18:15',
      validReps: 33,
      opponentReps: 39,
      outcome: 'YOU LOSE',
      method: '60s verified count',
      egoDelta: '-16 EGO',
      isPositive: false,
    ),
  ];

  String get handle => _handle;
  String get provider => _provider;
  bool get isGuest => _isGuest;
  int get egoRating => _egoRating;
  int get battlesWon => _battlesWon;
  int get totalBattles => _totalBattles;
  int get koWins => _koWins;
  int get lifetimeValidReps => _lifetimeValidReps;
  int get weeklyEgoDelta => _weeklyEgoDelta;
  List<BattleLogEntry> get battleHistory => List.unmodifiable(_battleHistory);

  void applyAuthenticatedPlayer(Map<String, dynamic> player) {
    _handle = player['handle'] as String? ?? _handle;
    _provider = player['provider'] as String? ?? 'manual';
    _isGuest = player['is_guest'] as bool? ?? false;
    _egoRating = (player['ego_rating'] as num?)?.toInt() ?? _egoRating;
    _battlesWon = (player['wins'] as num?)?.toInt() ?? 0;
    _totalBattles = (player['completed_matches'] as num?)?.toInt() ?? 0;
    _koWins = (player['ko_wins'] as num?)?.toInt() ?? 0;
    _lifetimeValidReps = (player['lifetime_valid_reps'] as num?)?.toInt() ?? 0;
    _notifySafely();
  }

  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void resetForTesting() {
    _handle = 'VANGUARD_01';
    _provider = 'local';
    _isGuest = false;
    _egoRating = 1780;
    _battlesWon = 48;
    _totalBattles = 54;
    _koWins = 19;
    _lifetimeValidReps = 12480;
    _weeklyEgoDelta = 310;
    _battleHistory
      ..clear()
      ..addAll(const [
        BattleLogEntry(
          opponent: 'CYBER_KONG',
          date: 'Today · 10:14 AM',
          validReps: 42,
          opponentReps: 27,
          outcome: 'KO WIN',
          method: '+15 rep lead Tug-of-War KO',
          egoDelta: '+24 EGO',
          isPositive: true,
        ),
        BattleLogEntry(
          opponent: 'MARCUS_FIT',
          date: 'Yesterday · 19:40',
          validReps: 41,
          opponentReps: 38,
          outcome: 'YOU WIN',
          method: '60s verified count',
          egoDelta: '+19 EGO',
          isPositive: true,
        ),
        BattleLogEntry(
          opponent: 'APEX_REAPER',
          date: '09 Nov · 18:15',
          validReps: 33,
          opponentReps: 39,
          outcome: 'YOU LOSE',
          method: '60s verified count',
          egoDelta: '-16 EGO',
          isPositive: false,
        ),
      ]);
    _notifySafely();
  }

  /// Records a completed battle or solo attempt, returning the Elo delta applied.
  int recordAttemptOutcome({
    required bool isBattle,
    required int validReps,
    required int opponentReps,
    required bool isKnockout,
    required bool isForfeit,
    String opponentName = 'CYBER_KONG',
    int opponentEgo = 1795,
  }) {
    final cfg = ThresholdsConfig.instance;
    _lifetimeValidReps += validReps;

    if (!isBattle) {
      _notifySafely();
      return 0;
    }

    final double actualScore;
    final String outcomeLabel;
    final String methodLabel;

    if (isForfeit) {
      actualScore = 0.0;
      outcomeLabel = 'FORFEIT';
      methodLabel = 'Forfeit loss';
    } else if (validReps > opponentReps) {
      actualScore = 1.0;
      outcomeLabel = isKnockout ? 'KO WIN' : 'YOU WIN';
      methodLabel = isKnockout
          ? '+${validReps - opponentReps} rep lead Tug-of-War KO'
          : '60s verified count';
    } else if (validReps == opponentReps) {
      actualScore = 0.5;
      outcomeLabel = 'DRAW';
      methodLabel = '60s tied count';
    } else {
      actualScore = 0.0;
      outcomeLabel = isKnockout ? 'KO LOSS' : 'YOU LOSE';
      methodLabel = '60s verified count';
    }

    final eloDelta = cfg.computeEloDelta(
      playerEgo: _egoRating,
      opponentEgo: opponentEgo,
      actualScore: actualScore,
      completedMatches: _totalBattles,
    );

    _totalBattles += 1;
    if (actualScore == 1.0) {
      _battlesWon += 1;
      if (isKnockout) {
        _koWins += 1;
      }
    }
    _egoRating += eloDelta;
    _weeklyEgoDelta += eloDelta;

    final deltaSign = eloDelta >= 0 ? '+$eloDelta EGO' : '$eloDelta EGO';
    _battleHistory.insert(
      0,
      BattleLogEntry(
        opponent: opponentName,
        date: 'Just now',
        validReps: validReps,
        opponentReps: opponentReps,
        outcome: outcomeLabel,
        method: methodLabel,
        egoDelta: deltaSign,
        isPositive: eloDelta >= 0,
      ),
    );

    _notifySafely();
    return eloDelta;
  }
}
