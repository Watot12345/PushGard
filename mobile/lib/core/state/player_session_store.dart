import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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

  Map<String, dynamic> toJson() => {
        'opponent': opponent,
        'date': date,
        'valid_reps': validReps,
        'opponent_reps': opponentReps,
        'outcome': outcome,
        'method': method,
        'ego_delta': egoDelta,
        'is_positive': isPositive,
      };

  factory BattleLogEntry.fromJson(Map<String, dynamic> json) => BattleLogEntry(
        opponent: json['opponent'] as String? ?? 'RIVAL',
        date: json['date'] as String? ?? 'Recent',
        validReps: (json['valid_reps'] as num?)?.toInt() ?? 0,
        opponentReps: (json['opponent_reps'] as num?)?.toInt() ?? 0,
        outcome: json['outcome'] as String? ?? 'COMPLETE',
        method: json['method'] as String? ?? '60s verified count',
        egoDelta: json['ego_delta'] as String? ?? '+0 EGO',
        isPositive: json['is_positive'] as bool? ?? true,
      );
}

/// Reactive session state store so completing a battle or solo session updates
/// Ego Rating (Win/Loss Elo), W-L record, Tug-of-War KOs, lifetime valid reps,
/// and the Ranks / Battle Log screens immediately.
class PlayerSessionStore extends ChangeNotifier {
  static final PlayerSessionStore instance = PlayerSessionStore();
  static const MethodChannel _storageChannel =
      MethodChannel('com.pushgard/camera_pose');

  String _handle = 'ATHLETE';
  String _provider = 'local'; // local | guest | manual | google | facebook
  bool _isGuest = false;
  int _egoRating = 1000;
  int _battlesWon = 0;
  int _totalBattles = 0;
  int _koWins = 0;
  int _lifetimeValidReps = 0;
  int _weeklyEgoDelta = 0;

  final List<BattleLogEntry> _battleHistory = [];

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

  Map<String, dynamic> toJson() => {
        'handle': _handle,
        'provider': _provider,
        'is_guest': _isGuest,
        'ego_rating': _egoRating,
        'battles_won': _battlesWon,
        'total_battles': _totalBattles,
        'ko_wins': _koWins,
        'lifetime_valid_reps': _lifetimeValidReps,
        'weekly_ego_delta': _weeklyEgoDelta,
        'battle_history': _battleHistory.map((e) => e.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _handle = json['handle'] as String? ?? _handle;
    _provider = json['provider'] as String? ?? _provider;
    _isGuest = json['is_guest'] as bool? ?? _isGuest;
    _egoRating = (json['ego_rating'] as num?)?.toInt() ?? _egoRating;
    _battlesWon = (json['battles_won'] as num?)?.toInt() ?? _battlesWon;
    _totalBattles = (json['total_battles'] as num?)?.toInt() ?? _totalBattles;
    _koWins = (json['ko_wins'] as num?)?.toInt() ?? _koWins;
    _lifetimeValidReps =
        (json['lifetime_valid_reps'] as num?)?.toInt() ?? _lifetimeValidReps;
    _weeklyEgoDelta =
        (json['weekly_ego_delta'] as num?)?.toInt() ?? _weeklyEgoDelta;
    final rawHistory = json['battle_history'] as List<dynamic>?;
    if (rawHistory != null) {
      _battleHistory
        ..clear()
        ..addAll(
          rawHistory
              .whereType<Map<String, dynamic>>()
              .map(BattleLogEntry.fromJson),
        );
    }
    _notifySafely();
  }

  /// Loads persisted session state from native app-private storage when available.
  Future<void> loadFromDisk() async {
    if (kIsWeb) return;
    try {
      final raw = await _storageChannel
          .invokeMethod<String>('readSessionJson')
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        loadFromJson(decoded);
      }
    } catch (_) {
      // Headless tests or first launch without saved session
    }
  }

  void _persistToDisk() {
    if (kIsWeb) return;
    unawaited(
      _storageChannel
          .invokeMethod<void>('writeSessionJson', {'json': jsonEncode(toJson())})
          .catchError((_) {}),
    );
  }

  void applyAuthenticatedPlayer(Map<String, dynamic> player) {
    _handle = player['handle'] as String? ?? _handle;
    _provider = player['provider'] as String? ?? 'manual';
    _isGuest = player['is_guest'] as bool? ?? false;
    _egoRating = (player['ego_rating'] as num?)?.toInt() ?? _egoRating;
    _battlesWon = (player['wins'] as num?)?.toInt() ?? 0;
    _totalBattles = (player['completed_matches'] as num?)?.toInt() ?? 0;
    _koWins = (player['ko_wins'] as num?)?.toInt() ?? 0;
    _lifetimeValidReps = (player['lifetime_valid_reps'] as num?)?.toInt() ?? 0;
    _persistToDisk();
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
    _handle = 'ATHLETE';
    _provider = 'local';
    _isGuest = false;
    _egoRating = 1000;
    _battlesWon = 0;
    _totalBattles = 0;
    _koWins = 0;
    _lifetimeValidReps = 0;
    _weeklyEgoDelta = 0;
    _battleHistory.clear();
    _notifySafely();
  }

  /// Records a completed battle or solo attempt, returning the Elo delta applied.
  int recordAttemptOutcome({
    required bool isBattle,
    required int validReps,
    required int opponentReps,
    required bool isKnockout,
    required bool isForfeit,
    String opponentName = 'OPPONENT',
    int opponentEgo = 1000,
  }) {
    final cfg = ThresholdsConfig.instance;
    _lifetimeValidReps += validReps;

    if (!isBattle) {
      _persistToDisk();
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

    _persistToDisk();
    _notifySafely();
    return eloDelta;
  }
}
