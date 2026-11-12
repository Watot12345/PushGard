import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/thresholds_config.dart';
import 'package:mobile/core/kinematics/joint_angle_math.dart';
import 'package:mobile/core/kinematics/rep_cycle_detector.dart';
import 'package:mobile/core/state/player_session_store.dart';
import 'package:mobile/core/widgets/rank_badge.dart';
import 'package:mobile/features/match/screens/attempt_summary_screen.dart';
import 'package:mobile/features/match/screens/battle_active_screen.dart';
import 'package:mobile/features/match/screens/framing_screen.dart';
import 'package:mobile/main.dart';

void main() {
  setUpAll(() async {
    await ThresholdsConfig.loadFromAsset();
  });

  setUp(() {
    PlayerSessionStore.instance.resetForTesting();
  });

  group('1. Kinematic Engine Boundary & Anti-Cheat Stress Tests', () {
    test('JointAngleMath computes exact 90.0°, 180.0°, and 45.0° interior angles', () {
      final rightAngle = JointAngleMath.computeThreePointAngleDegrees(
        ax: 0.0,
        ay: 1.0,
        bx: 0.0,
        by: 0.0,
        cx: 1.0,
        cy: 0.0,
      );
      expect(rightAngle, closeTo(90.0, 1e-6));

      final straightAngle = JointAngleMath.computeThreePointAngleDegrees(
        ax: -1.0,
        ay: 0.0,
        bx: 0.0,
        by: 0.0,
        cx: 1.0,
        cy: 0.0,
      );
      expect(straightAngle, closeTo(180.0, 1e-6));

      final fortyFive = JointAngleMath.computeThreePointAngleDegrees(
        ax: 1.0,
        ay: 1.0,
        bx: 0.0,
        by: 0.0,
        cx: 1.0,
        cy: 0.0,
      );
      expect(fortyFive, closeTo(45.0, 1e-6));
    });

    test('Body side auto-selection picks higher minimum-confidence side (LEFT vs RIGHT)', () {
      final rightDominant = <String, List<double>>{
        'LEFT_SHOULDER': [0, 0, 0, 0.45],
        'LEFT_ELBOW': [0, 0, 0, 0.40],
        'LEFT_WRIST': [0, 0, 0, 0.42],
        'LEFT_HIP': [0, 0, 0, 0.50],
        'LEFT_KNEE': [0, 0, 0, 0.49],
        'LEFT_ANKLE': [0, 0, 0, 0.48],
        'RIGHT_SHOULDER': [0, 0, 0, 0.95],
        'RIGHT_ELBOW': [0, 0, 0, 0.92],
        'RIGHT_WRIST': [0, 0, 0, 0.94],
        'RIGHT_HIP': [0, 0, 0, 0.91],
        'RIGHT_KNEE': [0, 0, 0, 0.93],
        'RIGHT_ANKLE': [0, 0, 0, 0.93],
      };
      expect(JointAngleMath.selectBodySide(rightDominant), BodySide.right);

      final leftDominant = <String, List<double>>{
        'LEFT_SHOULDER': [0, 0, 0, 0.96],
        'LEFT_ELBOW': [0, 0, 0, 0.94],
        'LEFT_WRIST': [0, 0, 0, 0.95],
        'LEFT_HIP': [0, 0, 0, 0.92],
        'LEFT_KNEE': [0, 0, 0, 0.91],
        'LEFT_ANKLE': [0, 0, 0, 0.90],
        'RIGHT_SHOULDER': [0, 0, 0, 0.35],
        'RIGHT_ELBOW': [0, 0, 0, 0.30],
        'RIGHT_WRIST': [0, 0, 0, 0.32],
        'RIGHT_HIP': [0, 0, 0, 0.40],
        'RIGHT_KNEE': [0, 0, 0, 0.39],
        'RIGHT_ANKLE': [0, 0, 0, 0.38],
      };
      expect(JointAngleMath.selectBodySide(leftDominant), BodySide.left);
    });

    test('Exact depth threshold boundary: 90.0° is VALID, 90.5° is rejected as SHALLOW', () {
      final detectorValid = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      detectorValid.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      detectorValid.processSample(tMs: 200, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      detectorValid.processSample(tMs: 500, rawElbow: 90.0, rawBody: 2.0, conf: 0.95);
      detectorValid.processSample(tMs: 800, rawElbow: 130.0, rawBody: 2.0, conf: 0.95);
      final repValid = detectorValid.processSample(
        tMs: 1200,
        rawElbow: 162.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(repValid, isNotNull);
      expect(repValid!.valid, isTrue);
      expect(repValid.rejectReason, isNull);

      // 90.5° (0.5° too shallow) -> SHALLOW
      final detectorShallow = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      detectorShallow.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      detectorShallow.processSample(tMs: 200, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      detectorShallow.processSample(tMs: 500, rawElbow: 90.5, rawBody: 2.0, conf: 0.95);
      detectorShallow.processSample(tMs: 800, rawElbow: 130.0, rawBody: 2.0, conf: 0.95);
      final repShallow = detectorShallow.processSample(
        tMs: 1200,
        rawElbow: 162.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(repShallow, isNotNull);
      expect(repShallow!.valid, isFalse);
      expect(repShallow.rejectReason, 'SHALLOW');
    });

    test('Exact speed boundaries: <0.50s rejected as TOO_FAST, >8.00s rejected as TOO_SLOW', () {
      // 1. TOO_FAST: 400ms total cycle duration (< 500ms min)
      final fastDetector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      fastDetector.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      fastDetector.processSample(tMs: 100, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      fastDetector.processSample(tMs: 200, rawElbow: 85.0, rawBody: 2.0, conf: 0.95);
      final fastRep = fastDetector.processSample(
        tMs: 400,
        rawElbow: 165.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(fastRep, isNotNull);
      expect(fastRep!.valid, isFalse);
      expect(fastRep.rejectReason, 'TOO_FAST');

      // 2. TOO_SLOW: 8,400ms total cycle duration (> 8,000ms max) with 200ms intervals
      final slowDetector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      slowDetector.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      slowDetector.processSample(tMs: 200, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      for (int t = 400; t <= 8200; t += 200) {
        slowDetector.processSample(tMs: t, rawElbow: 85.0, rawBody: 2.0, conf: 0.95);
      }
      final slowRep = slowDetector.processSample(
        tMs: 8400,
        rawElbow: 165.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(slowRep, isNotNull);
      expect(slowRep!.valid, isFalse);
      expect(slowRep.rejectReason, 'TOO_SLOW');
    });

    test('Exact body-line (15.0°), confidence (0.60), and tracking-gap (500ms) boundaries', () {
      // 1. Hip sag deviation 15.5° (> 15.0° max) -> BODY_LINE
      final bodyDetector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      bodyDetector.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      bodyDetector.processSample(tMs: 200, rawElbow: 140.0, rawBody: 4.0, conf: 0.95);
      bodyDetector.processSample(tMs: 600, rawElbow: 84.0, rawBody: 15.5, conf: 0.95);
      final bodyRep = bodyDetector.processSample(
        tMs: 1000,
        rawElbow: 165.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(bodyRep, isNotNull);
      expect(bodyRep!.valid, isFalse);
      expect(bodyRep.rejectReason, 'BODY_LINE');

      // 2. Confidence drop to 0.59 (< 0.60 min) -> LOW_CONFIDENCE
      final confDetector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      confDetector.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      confDetector.processSample(tMs: 200, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      confDetector.processSample(tMs: 600, rawElbow: 84.0, rawBody: 2.0, conf: 0.59);
      final confRep = confDetector.processSample(
        tMs: 1000,
        rawElbow: 165.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(confRep, isNotNull);
      expect(confRep!.valid, isFalse);
      expect(confRep.rejectReason, 'LOW_CONFIDENCE');

      // 3. Tracking gap of 501ms (> 500ms max) -> TRACKING_GAP
      final gapDetector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      gapDetector.processSample(tMs: 0, rawElbow: 165.0, rawBody: 2.0, conf: 0.95);
      gapDetector.processSample(tMs: 200, rawElbow: 140.0, rawBody: 2.0, conf: 0.95);
      gapDetector.processSample(tMs: 701, rawElbow: 84.0, rawBody: 2.0, conf: 0.95);
      final gapRep = gapDetector.processSample(
        tMs: 1100,
        rawElbow: 165.0,
        rawBody: 2.0,
        conf: 0.95,
      );
      expect(gapRep, isNotNull);
      expect(gapRep!.valid, isFalse);
      expect(gapRep.rejectReason, 'TRACKING_GAP');
    });

    test('Suspicion flag MAX_REPS_PER_MINUTE_EXCEEDED triggers on superhuman >90 RPM cadence', () {
      // Generate 5 super-fast valid reps at 25Hz (40ms intervals, 560ms per rep -> ~107 RPM > 90 RPM)
      final rawSamples = <List<num>>[];
      int t = 0;
      rawSamples.add([t, 165.0, 2.0, 0.95]);
      for (int rep = 0; rep < 5; rep++) {
        final angles = [150.0, 130.0, 110.0, 95.0, 82.0, 80.0, 85.0, 98.0, 115.0, 132.0, 148.0, 156.0, 162.0, 165.0];
        for (final a in angles) {
          t += 40;
          rawSamples.add([t, a, 2.0, 0.95]);
        }
      }

      final detector = RepCycleDetector(
        config: const ThresholdsConfig(emaAlpha: 1.0),
      );
      final eval = detector.evaluateAttemptSamples(rawSamples);
      expect(eval.attemptValid, isTrue);
      expect(eval.validRepCount, 5);
      expect(eval.flags, contains('MAX_REPS_PER_MINUTE_EXCEEDED'));
    });
  });

  group('2. All 4 Battle Resolution Modes & Rank Tier Progression', () {
    testWidgets('60s Decision Win (without KO) increments wins but NOT koWins', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttemptSummaryScreen(
            validReps: 36,
            opponentReps: 31,
            isBattle: true,
            isKnockout: false,
            isForfeit: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BATTLE RESULT'), findsOneWidget);
      expect(find.text('YOU WIN'), findsOneWidget);
      expect(PlayerSessionStore.instance.battlesWon, 49);
      expect(PlayerSessionStore.instance.koWins, 19); // Unchanged (not a KO)
      expect(
        PlayerSessionStore.instance.battleHistory.first.method,
        '60s verified count',
      );
    });

    testWidgets('60s Tied Reps resolves as DRAW with 0.5 Elo score', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttemptSummaryScreen(
            validReps: 34,
            opponentReps: 34,
            isBattle: true,
            isKnockout: false,
            isForfeit: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BATTLE RESULT'), findsOneWidget);
      expect(find.text('DRAW'), findsOneWidget);
      expect(PlayerSessionStore.instance.battlesWon, 48); // Unchanged on draw
      expect(PlayerSessionStore.instance.totalBattles, 55);
      expect(
        PlayerSessionStore.instance.battleHistory.first.outcome,
        'DRAW',
      );
      expect(
        PlayerSessionStore.instance.battleHistory.first.method,
        '60s tied count',
      );
    });

    testWidgets('Opponent +15 KO Loss deducts EGO and logs KO LOSS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttemptSummaryScreen(
            validReps: 18,
            opponentReps: 33,
            isBattle: true,
            isKnockout: true,
            isForfeit: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BATTLE RESULT'), findsOneWidget);
      expect(find.text('YOU LOSE'), findsOneWidget);
      expect(PlayerSessionStore.instance.egoRating, 1769); // 1780 - 11
      expect(
        PlayerSessionStore.instance.battleHistory.first.outcome,
        'KO LOSS',
      );
    });

    testWidgets('RankBadge renders SPARTAN, VANGUARD, TITAN II, and GOD OF WAR at exact thresholds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RankBadge(egoScore: 1000),
                RankBadge(egoScore: 1299),
                RankBadge(egoScore: 1300),
                RankBadge(egoScore: 1599),
                RankBadge(egoScore: 1600),
                RankBadge(egoScore: 1899),
                RankBadge(egoScore: 1900),
              ],
            ),
          ),
        ),
      );

      expect(find.text('SPARTAN'), findsNWidgets(2));
      expect(find.text('VANGUARD'), findsNWidgets(2));
      expect(find.text('TITAN II'), findsNWidgets(2));
      expect(find.text('GOD OF WAR'), findsOneWidget);
    });
  });

  group('3. Framing Gate Combinatorial Checks, Anti-Cheat UI & Accessibility Stress Tests', () {
    testWidgets(
      'FramingScreen disables START COUNTDOWN if ANY of the 3 checks fail and prevents tap-to-bypass',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const PushGardApp());
        await tester.pump();

        await tester.tap(find.text('START BATTLE'));
        await tester.pumpAndSettle();

        final framingState =
            tester.state<FramingScreenState>(find.byType(FramingScreen));

        // Fail check 1: Whole body visible -> FIX: step back
        framingState.setFramingChecksForTesting(bodyInFrame: false);
        await tester.pump();
        expect(find.text('FIX: step back'), findsOneWidget);

        // Tapping the status pill in production UI must NOT toggle it to PASS
        await tester.tap(find.text('Whole body visible'));
        await tester.pump();
        expect(find.text('FIX: step back'), findsOneWidget);

        // Tapping START COUNTDOWN must NOT navigate while a check fails
        await tester.tap(find.text('START COUNTDOWN'));
        await tester.pump();
        expect(find.text('GET READY'), findsOneWidget);

        // Restore check 1, fail check 2: Side-on view -> FIX: rotate 90°
        framingState.setFramingChecksForTesting(
          bodyInFrame: true,
          sideOnOrientation: false,
        );
        await tester.pump();
        expect(find.text('FIX: rotate 90°'), findsOneWidget);
        await tester.tap(find.text('START COUNTDOWN'));
        await tester.pump();
        expect(find.text('GET READY'), findsOneWidget);

        // Restore check 2 -> all 3 PASS -> START COUNTDOWN navigates to GET SET
        framingState.setFramingChecksForTesting(sideOnOrientation: true);
        await tester.pump();
        await tester.tap(find.text('START COUNTDOWN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('GET SET'), findsOneWidget);
      },
    );

    testWidgets(
      'Production Anti-Cheat Guard: No beta simulation buttons exist and 0 reps are awarded without live camera pose frames',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: BattleActiveScreen(isBattle: true),
          ),
        );

        // Complete 3-2-1 countdown
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // 1. Assert all beta test / cheat buttons are completely absent from production UI
        expect(find.text('+1 REP'), findsNothing);
        expect(find.text('SHALLOW'), findsNothing);
        expect(find.text('+15 KO'), findsNothing);

        // 2. Advance battle timer by 10 full seconds without camera pose frames
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Verify 0 reps are awarded when no live camera pose frames are received
        expect(find.text('YOU (0)'), findsOneWidget);
      },
    );

    testWidgets(
      'Viewport & Accessibility Stress Test: Compact 320x568 (iPhone SE) & 1.30x Large Font Scaling have zero layout overflows',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.30),
            ),
            child: const PushGardApp(),
          ),
        );
        await tester.pump();

        // 1. Home Screen on 320x568 @ 1.30x text scale
        expect(find.text('PUSHGARD'), findsOneWidget);

        // 2. Ranks Screen on 320x568 @ 1.30x text scale
        await tester.tap(find.text('RANKS'));
        await tester.pump();
        expect(find.text('BATTLE LOG'), findsOneWidget);

        await tester.tap(find.text('BATTLE LOG'));
        await tester.pump();

        // 3. Profile Screen on 320x568 @ 1.30x text scale
        await tester.tap(find.text('PROFILE'));
        await tester.pump();
        expect(find.text('SENSOR CALIBRATION'), findsOneWidget);
      },
    );
  });
}
