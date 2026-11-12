import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/state/player_session_store.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/pushgard_button.dart';
import '../core/widgets/rank_badge.dart';
import 'native_camera_controller.dart';
import 'skeleton_overlay_painter.dart';
import 'spike_benchmark_recorder.dart';

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final NativeCameraController _cameraController = NativeCameraController();
  final SpikeBenchmarkRecorder _recorder = SpikeBenchmarkRecorder();

  bool _isCameraReady = false;
  String _statusText = 'Standby · Live Camera Sensor Ready';
  PoseFrame? _lastFrame;
  StreamSubscription? _subscription;

  int _benchmarkSecondsRemaining = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    bool isGranted = false;
    try {
      final status = await Permission.camera.request();
      isGranted = status.isGranted;
    } catch (_) {
      isGranted = false;
    }

    if (!mounted) return;

    if (!isGranted) {
      setState(() {
        _statusText = 'Camera permission required for live pose tracking';
      });
      return;
    }

    try {
      final textureId = await _cameraController.startCamera(
        targetResolution: '480p',
        lensFacing: 'back',
      );

      if (!mounted) return;

      if (textureId != null) {
        _subscription = _cameraController.poseStream.listen((frame) {
          if (mounted) {
            setState(() {
              _lastFrame = frame;
            });
            if (_recorder.isRecording) {
              _recorder.recordFrame(frame);
            }
          }
        });

        setState(() {
          _isCameraReady = true;
          _statusText = 'CameraX + ML Kit Pose Active';
        });
      } else {
        setState(() {
          _statusText = 'Standby · Live Camera Sensor Ready';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Standby · Live Camera Sensor Ready';
      });
    }
  }

  void _startBenchmark() {
    setState(() {
      _benchmarkSecondsRemaining = 60;
    });
    _recorder.start();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _benchmarkSecondsRemaining--;
      });

      if (_benchmarkSecondsRemaining <= 0) {
        timer.cancel();
        _stopBenchmark();
      }
    });
  }

  void _stopBenchmark() {
    _countdownTimer?.cancel();
    _recorder.stop();
    final report = _recorder.computeReport(
      deviceModel: 'Android Device (Target)',
    );
    _showReportDialog(report);
  }

  void _showReportDialog(Map<String, dynamic> report) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(report);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'SENSOR CALIBRATION REPORT',
          style: AppTypography.cardHeadline(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Effective FPS: ${report['effective_fps']} (Target: >=25.0)',
                style: AppTypography.bodyBold(
                  color: (report['pass_criteria']?['fps_pass'] == true)
                      ? AppColors.volt
                      : AppColors.coralFix,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prone Dropout Rate: ${report['dropout_rate_pct']}% (Target: <5.0%)',
                style: AppTypography.bodyBold(
                  color: (report['pass_criteria']?['dropout_pass'] == true)
                      ? AppColors.volt
                      : AppColors.coralFix,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Raw JSON Report:',
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                prettyJson,
                style: AppTypography.telemetryCode(
                  color: AppColors.volt,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied to clipboard!')),
              );
            },
            child: const Text('Copy JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _subscription?.cancel();
    _cameraController.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerSessionStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final losses = (store.totalBattles - store.battlesWon).clamp(0, 99999);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
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
                            const RankShieldCrest(size: 32),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'PROFILE & SENSOR',
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
                  const SizedBox(height: 20),

                  // Fighter Career Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VANGUARD_01',
                          style: AppTypography.sectionTitle(color: Colors.white)
                              .copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${store.egoRating} EGO · ${store.battlesWon}W – ${losses}L (${store.koWins} Tug-of-War KOs)',
                          style: AppTypography.body(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lifetime Verified Reps: ${store.lifetimeValidReps}',
                          style: AppTypography.telemetryCode(
                            color: AppColors.volt,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Hardware Sensor Calibration / Step 0 Spike Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SENSOR CALIBRATION',
                          style: AppTypography.trackedLabel(
                            color: AppColors.volt,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusText,
                          style: AppTypography.bodyBold(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Native Inference: ${_lastFrame?.inferenceMs ?? 0} ms · Target >= 25.0 FPS · Zero video upload',
                          style: AppTypography.body(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (_isCameraReady &&
                            _cameraController.textureId != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Texture(
                                    textureId: _cameraController.textureId!,
                                  ),
                                  if (_lastFrame != null)
                                    CustomPaint(
                                      painter: SkeletonOverlayPainter(
                                        landmarks: _lastFrame!.landmarks,
                                        imageWidth: _lastFrame!.imageWidth,
                                        imageHeight: _lastFrame!.imageHeight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        PushGardButton(
                          text: _recorder.isRecording
                              ? 'STOP BENCHMARK (${_benchmarkSecondsRemaining}s)'
                              : 'START 60s SENSOR BENCHMARK',
                          variant: _recorder.isRecording
                              ? ButtonVariant.secondary
                              : ButtonVariant.primary,
                          height: 54,
                          onPressed: () {
                            if (_recorder.isRecording) {
                              _stopBenchmark();
                            } else {
                              _startBenchmark();
                            }
                          },
                        ),
                      ],
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
}
