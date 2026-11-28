import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands-free audio and haptic cues for 60-second push-up sets so athletes
/// do not need to stare at the phone screen from 2m away.
class SoundCueService {
  static final SoundCueService instance = SoundCueService();

  static const MethodChannel _channel = MethodChannel('com.pushgard/camera_pose');

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  @visibleForTesting
  void Function(String cue)? onCueForTesting;

  void setMuted(bool muted) {
    _isMuted = muted;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  @visibleForTesting
  void resetForTesting() {
    _isMuted = false;
    onCueForTesting = null;
  }

  void _emit(String cue, {bool heavyHaptic = false}) {
    if (_isMuted) return;
    onCueForTesting?.call(cue);

    try {
      if (heavyHaptic) {
        unawaited(HapticFeedback.heavyImpact());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    } catch (_) {}

    if (kIsWeb) return;
    unawaited(
      _channel
          .invokeMethod<void>('playTone', {'cue': cue})
          .catchError((_) async {
        try {
          await SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      }),
    );
  }

  void playCountdownTick() => _emit('countdown');
  void playGoCue() => _emit('go');
  void playValidRep() => _emit('rep');
  void playFaultCue() => _emit('fault', heavyHaptic: true);
  void playFinishCue() => _emit('finish', heavyHaptic: true);
}
