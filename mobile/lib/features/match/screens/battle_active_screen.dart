import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/config/thresholds_config.dart';
import '../../../core/kinematics/attempt_record_builder.dart';
import '../../../core/kinematics/joint_angle_math.dart';
import '../../../core/network/pushgard_api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../spike/native_camera_controller.dart';
import 'attempt_summary_screen.dart';

/// Matches Page 5 of `Pushgard — Logo & App Icon.pdf` combined with the
/// Tug-of-War Dominance Bar (+15 rep lead KO or 60s timer) and live RepCycleDetector.
class BattleActiveScreen extends StatefulWidget {
  final bool isBattle;
  final BodySide initialBodySide;
  final PushgardApiClient? apiClient;

  const BattleActiveScreen({
    super.key,
    this.isBattle = true,
    this.initialBodySide = BodySide.right,
    this.apiClient,
  });

  @override
  State<BattleActiveScreen> createState() => BattleActiveScreenState();
}

class BattleActiveScreenState extends State<BattleActiveScreen> {
  final NativeCameraController _cameraController = NativeCameraController();
  late final AttemptRecordBuilder _recordBuilder;
  StreamSubscription? _subscription;
  bool _isCameraReady = false;
  int? _attemptStartMonoMs;

  int _countdownSeconds = 3;
  bool _isCountdownActive = true;
  Timer? _countdownTimer;

  late double _battleSecondsRemaining;
  Timer? _sessionTimer;

  int _validReps = 0;
  int _rivalReps = 0;
  int _comboStreak = 0;
  int _maxComboStreak = 0;

  int _shallowReps = 0;
  int _noLockoutReps = 0;
  int _bodyLineReps = 0;

  double _currentElbowAngle = 165.0;
  String _coachingText = 'Full lockout — drop to <=90°';
  bool _isCoachingWarning = false;
  bool _hasFinished = false;
  int? _serverMatchId;
  String? _serverNonce;

  PushgardApiClient get _api => widget.apiClient ?? PushgardApiClient.instance;

  @override
  void initState() {
    super.initState();
    _battleSecondsRemaining =
        ThresholdsConfig.instance.battleTimerSeconds.toDouble();
    _recordBuilder = AttemptRecordBuilder(
      attemptId: '01931ea4-82a1-7d12-9c94-1a80d418bc22',
      matchId: widget.isBattle ? '01931ea4-82a1-7d12-9c94-1a80d418bc23' : null,
      nonce: 'local-session-nonce',
      bodySideSelected: widget.initialBodySide,
    );
    _initBattleSession();
    _start321Countdown();
  }

  Future<void> _initBattleSession() async {
    if (_api.isAuthenticated && widget.isBattle) {
      try {
        final matchRes = await _api.createMatch();
        final matchId = (matchRes['match']?['id'] as num?)?.toInt();
        if (matchId != null) {
          final startRes = await _api.startMatch(matchId);
          _serverMatchId = matchId;
          _serverNonce = startRes['nonce'] as String?;
        }
      } catch (_) {
        // Offline or server unavailable; fall back to local evaluation cleanly.
      }
    }

    try {
      final textureId = await _cameraController.startCamera(
        targetResolution: '480p',
        lensFacing: 'back',
      );
      if (textureId != null && mounted) {
        _subscription = _cameraController.poseStream.listen(_onPoseFrame);
        setState(() => _isCameraReady = true);
      }
    } catch (_) {
      // Hardware camera unavailable; zero reps are awarded without live pose frames.
    }
  }

  void _onPoseFrame(PoseFrame frame) {
    if (_isCountdownActive || _hasFinished || !mounted) return;
    _attemptStartMonoMs ??= frame.timestampMs;
    final relativeMs = frame.timestampMs - _attemptStartMonoMs!;
    final completedRep = _recordBuilder.addLandmarkFrame(
      tMs: relativeMs,
      landmarks: frame.landmarks,
    );
    final smoothedElbow = _recordBuilder.detector.currentSmoothedElbow;
    setState(() {
      if (smoothedElbow != null) {
        _currentElbowAngle = smoothedElbow;
      }
      if (completedRep != null) {
        if (completedRep.valid) {
          _recordCleanRep();
        } else {
          _comboStreak = 0;
          _isCoachingWarning = true;
          if (completedRep.rejectReason == 'SHALLOW') {
            _shallowReps++;
            _coachingText = 'Go lower on the next rep';
          } else if (completedRep.rejectReason == 'NO_LOCKOUT') {
            _noLockoutReps++;
            _coachingText = 'Lock out arms fully at top';
          } else if (completedRep.rejectReason == 'BODY_LINE') {
            _bodyLineReps++;
            _coachingText = 'Keep hips straight in line';
          } else {
            _coachingText = 'Rep rejected (${completedRep.rejectReason})';
          }
        }
      }
    });
  }

  @visibleForTesting
  void injectPoseFrameForTesting(PoseFrame frame) => _onPoseFrame(frame);

  @visibleForTesting
  void recordCleanRepForTesting() => setState(_recordCleanRep);

  @visibleForTesting
  void recordShallowFaultForTesting() => _recordShallowFault();

  @visibleForTesting
  void triggerKoForTesting() {
    final cfg = ThresholdsConfig.instance;
    setState(() {
      _validReps = _rivalReps + cfg.knockoutLeadReps;
      _checkKnockoutCondition();
    });
  }

  void _start321Countdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        setState(() => _isCountdownActive = false);
        _startBattleTimer();
      }
    });
  }

  void _startBattleTimer() {
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || _hasFinished) {
        timer.cancel();
        return;
      }
      if (_battleSecondsRemaining > 0.2) {
        setState(() {
          _battleSecondsRemaining -= 0.2;

          final tick = (_battleSecondsRemaining * 5).toInt();
          if (widget.isBattle && _isCameraReady && tick % 16 == 0) {
            _rivalReps++;
            _checkKnockoutCondition();
          }
        });
      } else {
        timer.cancel();
        _finishBattle(isKnockout: false, isForfeit: false);
      }
    });
  }

  void _recordCleanRep() {
    _validReps++;
    _comboStreak++;
    if (_comboStreak > _maxComboStreak) {
      _maxComboStreak = _comboStreak;
    }
    _currentElbowAngle = 165.0;
    _coachingText = 'Clean rep counted (${_comboStreak}x streak)';
    _isCoachingWarning = false;
    _checkKnockoutCondition();
  }

  void _recordShallowFault() {
    setState(() {
      _shallowReps++;
      _comboStreak = 0;
      _currentElbowAngle = 108.0;
      _coachingText = 'Go lower on the next rep';
      _isCoachingWarning = true;
    });
  }

  void _checkKnockoutCondition() {
    if (!widget.isBattle || _hasFinished) return;
    final cfg = ThresholdsConfig.instance;
    if (cfg.isKnockoutReached(
      playerValidReps: _validReps,
      opponentValidReps: _rivalReps,
    )) {
      _finishBattle(isKnockout: true, isForfeit: false);
    }
  }

  Future<void> _finishBattle({
    required bool isKnockout,
    required bool isForfeit,
  }) async {
    if (_hasFinished) return;
    _hasFinished = true;
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _subscription?.cancel();
    _cameraController.stopCamera();

    int verifiedValidReps = _validReps;
    if (_serverMatchId != null &&
        _serverNonce != null &&
        _recordBuilder.rawSamples.length >= 2) {
      try {
        final submitRes = await _api.submitMatch(
          matchId: _serverMatchId!,
          nonce: _serverNonce!,
          samples: _recordBuilder.rawSamples,
        );
        verifiedValidReps =
            (submitRes['server_valid_reps'] as num?)?.toInt() ?? _validReps;
      } catch (_) {
        // Network drop: preserve local count in UI while server keeps attempt open for retry.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AttemptSummaryScreen(
          validReps: verifiedValidReps,
          opponentReps: widget.isBattle ? _rivalReps : 0,
          shallowReps: _shallowReps,
          noLockoutReps: _noLockoutReps,
          bodyLineReps: _bodyLineReps,
          maxComboStreak: _maxComboStreak,
          isBattle: widget.isBattle,
          isKnockout: isKnockout,
          isForfeit: isForfeit,
        ),
      ),
    );
  }

  String _formatClock(double seconds) {
    final total = seconds.ceil().clamp(0, 3600);
    final mins = total ~/ 60;
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _subscription?.cancel();
    _cameraController.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ThresholdsConfig.instance;
    final tugRatio = widget.isBattle
        ? cfg.computeTugOfWarRatio(
            playerValidReps: _validReps,
            opponentValidReps: _rivalReps,
          )
        : (_validReps / 40.0).clamp(0.0, 1.0);
    final lead = _validReps - _rivalReps;
    final leadStr = lead >= 0 ? '+$lead' : '$lead';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isCountdownActive
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GET SET',
                      style: AppTypography.trackedLabel(
                        color: AppColors.volt,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_countdownSeconds',
                      style: AppTypography.hudGiganticNumber(
                        color: AppColors.volt,
                      ).copyWith(fontSize: 140),
                    ),
                  ],
                ),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Column(
                  children: [
                    // 1. TIME LEFT + 0:42 Clock (Page 5 of PDF) + FORFEIT/EXIT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 56),
                        Flexible(
                          child: Text(
                            'TIME LEFT',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.trackedLabel(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _finishBattle(
                                isKnockout: false,
                                isForfeit: widget.isBattle,
                              ),
                              child: Text(
                                widget.isBattle ? 'FORFEIT' : 'EXIT',
                                style: AppTypography.telemetryCode(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatClock(_battleSecondsRemaining),
                      style: AppTypography.hudTimer(color: Colors.white)
                          .copyWith(fontSize: 64),
                    ),
                    const SizedBox(height: 12),

                    // 2. Tug-of-War Dominance Bar (Volt Lime vs Slate/Coral)
                    if (widget.isBattle) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOU ($_validReps)',
                            style: AppTypography.telemetryCode(
                              color: AppColors.volt,
                              fontSize: 11,
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$leadStr LEAD · KO AT +${cfg.knockoutLeadReps}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.telemetryCode(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'RIVAL ($_rivalReps)',
                            style: AppTypography.telemetryCode(
                              color: AppColors.coralFix,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: tugRatio,
                                  child: Container(color: AppColors.volt),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 3. Live Camera + Skeleton Rounded Box (Page 5 of PDF)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_isCameraReady &&
                                _cameraController.textureId != null)
                              Texture(textureId: _cameraController.textureId!),
                            Center(
                              child: Text(
                                'Live camera + skeleton\n(Elbow: ${_currentElbowAngle.toInt()}°)',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. Giant Volt Lime Rep Count + REPS (PREVIEW) (Page 5 of PDF)
                    Text(
                      '$_validReps',
                      style: AppTypography.hudGiganticNumber(
                        color: AppColors.volt,
                      ).copyWith(fontSize: 96),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'REPS (PREVIEW)',
                      style: AppTypography.trackedLabel(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Coaching Pill ("Go lower on the next rep" — Page 5 of PDF)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _coachingText,
                        style: AppTypography.bodyBold(
                          color: _isCoachingWarning
                              ? AppColors.coralFix
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!widget.isBattle) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _finishBattle(
                          isKnockout: false,
                          isForfeit: false,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'FINISH SET',
                            style: AppTypography.telemetryCode(
                              color: AppColors.volt,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    Text(
                      'The server confirms your final count after the timer ends.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
