import 'dart:async';
import 'package:flutter/services.dart';

class PoseFrame {
  final int timestampMs;
  final int inferenceMs;
  final int rotation;
  final int imageWidth;
  final int imageHeight;
  final Map<String, List<double>> landmarks; // [x, y, z, inFrameLikelihood]

  PoseFrame({
    required this.timestampMs,
    required this.inferenceMs,
    required this.rotation,
    required this.imageWidth,
    required this.imageHeight,
    required this.landmarks,
  });

  factory PoseFrame.fromMap(Map<dynamic, dynamic> map) {
    final rawLandmarks = map['landmarks'] as Map<dynamic, dynamic>? ?? {};
    final parsedLandmarks = <String, List<double>>{};

    rawLandmarks.forEach((key, value) {
      if (value is List) {
        parsedLandmarks[key.toString()] = value.map((e) => (e as num).toDouble()).toList();
      }
    });

    return PoseFrame(
      timestampMs: (map['t_ms'] as num).toInt(),
      inferenceMs: (map['inference_ms'] as num).toInt(),
      rotation: (map['rotation'] as num?)?.toInt() ?? 0,
      imageWidth: (map['img_w'] as num?)?.toInt() ?? 640,
      imageHeight: (map['img_h'] as num?)?.toInt() ?? 480,
      landmarks: parsedLandmarks,
    );
  }
}

class NativeCameraController {
  static const MethodChannel _methodChannel = MethodChannel('com.pushgard/camera_pose');
  static const EventChannel _eventChannel = EventChannel('com.pushgard/pose_events');

  int? textureId;
  int previewWidth = 0;
  int previewHeight = 0;

  Stream<PoseFrame>? _poseStream;
  StreamSubscription? _subscription;

  Stream<PoseFrame> get poseStream {
    _poseStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => PoseFrame.fromMap(event as Map<dynamic, dynamic>));
    return _poseStream!;
  }

  Future<int?> startCamera({
    String targetResolution = '480p',
    String lensFacing = 'back',
  }) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'startCamera',
      {
        'targetResolution': targetResolution,
        'lensFacing': lensFacing,
      },
    );

    if (result != null) {
      textureId = result['textureId'] as int?;
      previewWidth = (result['width'] as num?)?.toInt() ?? 480;
      previewHeight = (result['height'] as num?)?.toInt() ?? 640;
    }
    return textureId;
  }

  Future<void> stopCamera() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _methodChannel.invokeMethod('stopCamera');
    } catch (_) {}
    textureId = null;
  }
}
