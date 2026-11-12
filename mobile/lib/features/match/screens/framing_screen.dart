import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pushgard_button.dart';
import '../../../spike/native_camera_controller.dart';
import '../../../spike/skeleton_overlay_painter.dart';
import 'battle_active_screen.dart';

/// Matches Page 4 of `Pushgard — Logo & App Icon.pdf`:
/// "GET READY / Prop your phone side-on" with dashed Volt guide,
/// Whole body visible / Side-on view / Lighting status pills, and privacy notice.
class FramingScreen extends StatefulWidget {
  final bool isBattle;

  const FramingScreen({super.key, this.isBattle = true});

  @override
  State<FramingScreen> createState() => FramingScreenState();
}

class FramingScreenState extends State<FramingScreen> {
  final NativeCameraController _cameraController = NativeCameraController();
  bool _isCameraReady = false;
  PoseFrame? _lastFrame;
  StreamSubscription? _subscription;

  bool _bodyInFrame = true;
  bool _sideOnOrientation = true;
  bool _lightingPassed = true;

  @override
  void initState() {
    super.initState();
    _startCalibration();
  }

  Future<void> _startCalibration() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;

      final textureId = await _cameraController.startCamera(
        targetResolution: '480p',
        lensFacing: 'back',
      );

      if (textureId != null && mounted) {
        _subscription = _cameraController.poseStream.listen(_evaluateFraming);
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (_) {
      // Hardware camera unavailable in current environment
    }
  }

  void _evaluateFraming(PoseFrame frame) {
    if (!mounted) return;

    final landmarks = frame.landmarks;
    final keys = ['SHOULDER', 'ELBOW', 'WRIST', 'HIP', 'KNEE', 'ANKLE'];

    double getConf(String prefix, String joint) {
      final pt = landmarks['${prefix}_$joint'];
      return (pt != null && pt.length >= 4) ? pt[3] : 0.0;
    }

    final minLeft =
        keys.map((k) => getConf('LEFT', k)).reduce((a, b) => a < b ? a : b);
    final minRight =
        keys.map((k) => getConf('RIGHT', k)).reduce((a, b) => a < b ? a : b);
    final isRight = minRight >= minLeft;
    final activePrefix = isRight ? 'RIGHT' : 'LEFT';
    final activeMinConf = isRight ? minRight : minLeft;

    final shoulder = landmarks['${activePrefix}_SHOULDER'];
    final wrist = landmarks['${activePrefix}_WRIST'];
    final ankle = landmarks['${activePrefix}_ANKLE'];

    bool inBounds(List<double>? pt) {
      if (pt == null || pt.isEmpty) return false;
      final x = pt[0] / frame.imageWidth;
      final y = pt[1] / frame.imageHeight;
      return x >= 0.05 && x <= 0.95 && y >= 0.05 && y <= 0.95;
    }

    final allInBounds =
        inBounds(shoulder) && inBounds(wrist) && inBounds(ankle);
    final isProne = (shoulder != null && ankle != null)
        ? (shoulder[0] - ankle[0]).abs() >
            (shoulder[1] - ankle[1]).abs() * 0.8
        : false;

    setState(() {
      _lastFrame = frame;
      _bodyInFrame = allInBounds;
      _sideOnOrientation = isProne;
      _lightingPassed = activeMinConf >= 0.60;
    });
  }

  @visibleForTesting
  void evaluateFramingForTesting(PoseFrame frame) => _evaluateFraming(frame);

  @visibleForTesting
  void setFramingChecksForTesting({
    bool? bodyInFrame,
    bool? sideOnOrientation,
    bool? lightingPassed,
  }) {
    setState(() {
      if (bodyInFrame != null) _bodyInFrame = bodyInFrame;
      if (sideOnOrientation != null) _sideOnOrientation = sideOnOrientation;
      if (lightingPassed != null) _lightingPassed = lightingPassed;
    });
  }

  bool get _isReady =>
      _bodyInFrame && _sideOnOrientation && _lightingPassed;

  @override
  void dispose() {
    _subscription?.cancel();
    _cameraController.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Back & GET READY label (Page 4 of PDF)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GET READY',
                    style: AppTypography.trackedLabel(
                      color: AppColors.volt,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCEL',
                      style: AppTypography.telemetryCode(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Prop your phone side-\non',
                style: AppTypography.heroTitle(color: Colors.white).copyWith(
                  fontSize: 36,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 20),

              // Dashed Volt Lime Camera Preview Box (Page 4 of PDF)
              Expanded(
                child: CustomPaint(
                  foregroundPainter: _DashedVoltBorderPainter(
                    color: AppColors.volt,
                    radius: 22,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.surface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_isCameraReady &&
                              _cameraController.textureId != null)
                            Texture(textureId: _cameraController.textureId!),
                          if (_lastFrame != null)
                            CustomPaint(
                              painter: SkeletonOverlayPainter(
                                landmarks: _lastFrame!.landmarks,
                                imageWidth: _lastFrame!.imageWidth,
                                imageHeight: _lastFrame!.imageHeight,
                              ),
                            ),
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Camera preview: whole body inside the\nguide, seen from the side',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 3 Framing Check Rows (Page 4 of PDF: Whole body visible, Side-on view, Lighting)
              _buildFramingStatusPill(
                label: 'Whole body visible',
                passed: _bodyInFrame,
                fixText: 'FIX: step back',
              ),
              const SizedBox(height: 10),
              _buildFramingStatusPill(
                label: 'Side-on view',
                passed: _sideOnOrientation,
                fixText: 'FIX: rotate 90°',
              ),
              const SizedBox(height: 10),
              _buildFramingStatusPill(
                label: 'Lighting',
                passed: _lightingPassed,
                fixText: 'FIX: brighter light',
              ),

              const SizedBox(height: 22),

              // START COUNTDOWN Button (Page 4 of PDF)
              PushGardButton(
                text: 'START COUNTDOWN',
                variant: _isReady
                    ? ButtonVariant.primary
                    : ButtonVariant.secondary,
                height: 58,
                onPressed: _isReady
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => BattleActiveScreen(
                              isBattle: widget.isBattle,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Video stays on your phone. Only joint data is sent.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFramingStatusPill({
    required String label,
    required bool passed,
    required String fixText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              passed ? 'PASS' : fixText,
              textAlign: TextAlign.right,
              style: AppTypography.bodyBold(
                color: passed ? AppColors.volt : AppColors.coralFix,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedVoltBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedVoltBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 7.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedVoltBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
