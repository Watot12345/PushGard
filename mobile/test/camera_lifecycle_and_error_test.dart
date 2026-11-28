import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/state/player_session_store.dart';
import 'package:mobile/features/match/screens/battle_active_screen.dart';
import 'package:mobile/features/match/screens/framing_screen.dart';
import 'package:mobile/spike/native_camera_controller.dart';
import 'package:mobile/spike/skeleton_overlay_painter.dart';
import 'package:mobile/spike/spike_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cameraChannel = MethodChannel('com.pushgard/camera_pose');
  const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    PlayerSessionStore.instance.resetForTesting();
    // Default permission_handler mock: camera granted (PermissionStatus.granted == 1)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      if (call.method == 'requestPermissions') {
        final perms = (call.arguments as List?) ?? const [];
        return {for (final p in perms) p: 1};
      }
      if (call.method == 'checkPermissionStatus') {
        return 1;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets(
    '1. FramingScreen stops camera BEFORE BattleActiveScreen starts it (no dispose race)',
    (WidgetTester tester) async {
      final callLog = <String>[];
      int nextTextureId = 10;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        callLog.add(call.method);
        if (call.method == 'startCamera') {
          return {'textureId': nextTextureId++, 'width': 480, 'height': 640};
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(home: FramingScreen(isBattle: true)),
      );
      await tester.pumpAndSettle();

      expect(callLog, equals(['startCamera']));

      // Navigate from FramingScreen -> BattleActiveScreen
      await tester.tap(find.text('START COUNTDOWN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // CRITICAL: stopCamera from FramingScreen must happen BEFORE BattleActiveScreen's
      // startCamera, and MUST NOT fire again after BattleActiveScreen's startCamera!
      final lastStartIdx = callLog.lastIndexOf('startCamera');
      final lastStopIdx = callLog.lastIndexOf('stopCamera');
      expect(
        lastStartIdx,
        greaterThan(0),
        reason: 'BattleActiveScreen should have called startCamera',
      );
      expect(
        lastStopIdx,
        lessThan(lastStartIdx),
        reason:
            'FramingScreen.dispose() must not call stopCamera AFTER BattleActiveScreen started the camera. Log: $callLog',
      );
    },
  );

  testWidgets(
    '2. FramingScreen displays camera error and RETRY button on failure, and recovers on retry',
    (WidgetTester tester) async {
      int attempts = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        if (call.method == 'startCamera') {
          attempts++;
          if (attempts == 1) {
            throw PlatformException(
              code: 'CAMERA_ERROR',
              message: 'Camera hardware busy',
            );
          }
          return {'textureId': 42, 'width': 480, 'height': 640};
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(home: FramingScreen(isBattle: true)),
      );
      await tester.pumpAndSettle();

      // Must surface the actual failure instead of silently ignoring it
      expect(find.textContaining('Camera hardware busy'), findsOneWidget);
      expect(find.text('RETRY CAMERA'), findsOneWidget);

      // Tap RETRY CAMERA -> second attempt succeeds
      await tester.tap(find.text('RETRY CAMERA'));
      await tester.pumpAndSettle();

      expect(find.byType(Texture), findsOneWidget);
      expect(find.text('RETRY CAMERA'), findsNothing);
      // Placeholder text should disappear when live camera texture is active
      expect(
        find.text('Camera preview: whole body inside the\nguide, seen from the side'),
        findsNothing,
      );
    },
  );

  testWidgets(
    '3. FramingScreen supports flipping between back and front camera',
    (WidgetTester tester) async {
      final requestedLenses = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        if (call.method == 'startCamera') {
          final args = call.arguments as Map?;
          requestedLenses.add((args?['lensFacing'] as String?) ?? 'back');
          return {'textureId': 7, 'width': 480, 'height': 640};
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(home: FramingScreen(isBattle: true)),
      );
      await tester.pumpAndSettle();

      expect(requestedLenses, equals(['back']));
      expect(find.byTooltip('Flip camera'), findsOneWidget);

      await tester.tap(find.byTooltip('Flip camera'));
      await tester.pumpAndSettle();

      expect(requestedLenses, equals(['back', 'front']));
    },
  );

  testWidgets(
    '4. BattleActiveScreen renders SkeletonOverlayPainter on pose frames and shows camera error on failure',
    (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        if (call.method == 'startCamera') {
          throw PlatformException(
            code: 'CAMERA_ERROR',
            message: 'No camera lifecycle',
          );
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(home: BattleActiveScreen(isBattle: false)),
      );
      // Wait for 3-2-1 countdown to finish
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.textContaining('No camera lifecycle'), findsOneWidget);

      // Inject a pose frame and verify SkeletonOverlayPainter is mounted
      final state = tester.state<BattleActiveScreenState>(
        find.byType(BattleActiveScreen),
      );
      state.injectPoseFrameForTesting(
        PoseFrame(
          timestampMs: 1000,
          inferenceMs: 12,
          rotation: 0,
          imageWidth: 480,
          imageHeight: 640,
          landmarks: {
            'RIGHT_SHOULDER': [200, 150, 0, 0.95],
            'RIGHT_ELBOW': [200, 250, 0, 0.95],
            'RIGHT_WRIST': [200, 350, 0, 0.95],
            'RIGHT_HIP': [120, 200, 0, 0.95],
            'RIGHT_KNEE': [80, 250, 0, 0.95],
            'RIGHT_ANKLE': [40, 300, 0, 0.95],
          },
        ),
      );
      await tester.pump();

      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      expect(
        customPaints.any((cp) => cp.painter is SkeletonOverlayPainter),
        isTrue,
        reason: 'BattleActiveScreen should render SkeletonOverlayPainter over live pose frames',
      );
    },
  );

  testWidgets(
    '5. SpikeScreen surfaces camera error (never lies Ready) and displays active player handle',
    (WidgetTester tester) async {
      PlayerSessionStore.instance.applyAuthenticatedPlayer({
        'handle': 'GYM_ALPHA_99',
        'provider': 'guest',
        'is_guest': true,
        'ego_rating': 1420,
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        if (call.method == 'startCamera') {
          throw PlatformException(
            code: 'CAMERA_ERROR',
            message: 'Sensor init failed',
          );
        }
        return null;
      });

      await tester.pumpWidget(const MaterialApp(home: SpikeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('GYM_ALPHA_99'), findsOneWidget);
      expect(find.text('VANGUARD_01'), findsNothing);
      expect(find.textContaining('Sensor init failed'), findsOneWidget);
      expect(find.text('Standby · Live Camera Sensor Ready'), findsNothing);
    },
  );
}
