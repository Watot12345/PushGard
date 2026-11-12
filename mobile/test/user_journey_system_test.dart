import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/thresholds_config.dart';
import 'package:mobile/core/state/player_session_store.dart';
import 'package:mobile/features/match/screens/battle_active_screen.dart';
import 'package:mobile/features/match/screens/framing_screen.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() {
    PlayerSessionStore.instance.resetForTesting();
  });

  testWidgets(
    'Production E2E User Journey: Home -> Framing Check -> Live Battle -> +15 KO -> Result -> Home & Battle Log Persistence',
    (WidgetTester tester) async {
      // Set realistic mobile phone viewport (390x844 iPhone 14 / Pixel size)
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ThresholdsConfig.loadFromAsset();
      expect(ThresholdsConfig.instance.knockoutLeadReps, 15);
      expect(ThresholdsConfig.instance.battleTimerSeconds, 60);

      await tester.pumpWidget(const PushGardApp());
      await tester.pump();

      // 1. Verify initial Home Screen state (Page 3 of PDF)
      expect(find.text('PUSHGARD'), findsOneWidget);
      expect(find.text('1,780'), findsOneWidget);
      expect(
        find.text('Win/Loss Elo rating · 48W – 6L (19 Tug-of-War KOs)'),
        findsOneWidget,
      );

      // 2. Tap START BATTLE -> Navigate to GET READY (FramingScreen, Page 4 of PDF)
      await tester.tap(find.text('START BATTLE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GET READY'), findsOneWidget);
      expect(find.text('Whole body visible'), findsOneWidget);
      expect(find.text('Side-on view'), findsOneWidget);
      expect(find.text('Lighting'), findsOneWidget);

      // 3. Verify framing status pills cannot be tap-toggled by users in production,
      // and test sensor state transitions via @visibleForTesting hook
      final framingState =
          tester.state<FramingScreenState>(find.byType(FramingScreen));
      framingState.setFramingChecksForTesting(lightingPassed: false);
      await tester.pump();
      expect(find.text('FIX: brighter light'), findsOneWidget);

      // Tapping the pill in production UI must NOT bypass the failed check
      await tester.tap(find.text('Lighting'));
      await tester.pump();
      expect(find.text('FIX: brighter light'), findsOneWidget);

      // Sensor restores lighting -> PASS
      framingState.setFramingChecksForTesting(lightingPassed: true);
      await tester.pump();
      expect(find.text('FIX: brighter light'), findsNothing);

      // 4. Tap START COUNTDOWN -> Enter BattleActiveScreen (Page 5 of PDF)
      await tester.tap(find.text('START COUNTDOWN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GET SET'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Advance through 3-2-1 countdown
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      // Live Battle HUD is now active — verify beta cheat buttons are removed in production!
      expect(find.text('TIME LEFT'), findsOneWidget);
      expect(find.text('REPS (PREVIEW)'), findsOneWidget);
      expect(find.text('+1 REP'), findsNothing);
      expect(find.text('SHALLOW'), findsNothing);
      expect(find.text('+15 KO'), findsNothing);

      final battleState =
          tester.state<BattleActiveScreenState>(find.byType(BattleActiveScreen));

      // 5. Trigger a shallow rep fault via @visibleForTesting hook -> verify coaching callout
      battleState.recordShallowFaultForTesting();
      await tester.pump();
      expect(find.text('Go lower on the next rep'), findsOneWidget);

      // 6. Trigger a clean rep via @visibleForTesting hook -> verify coaching callout
      battleState.recordCleanRepForTesting();
      await tester.pump();
      expect(find.textContaining('Clean rep counted'), findsOneWidget);

      // 7. Trigger +15 rep lead Tug-of-War Instant KO!
      battleState.triggerKoForTesting();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 8. Verify Battle Result Screen (Page 6 of PDF)
      expect(find.text('BATTLE RESULT'), findsOneWidget);
      expect(find.text('KO WIN'), findsOneWidget);
      expect(find.text('1,793'), findsOneWidget); // 1780 + 13 EGO vs 1795 rival

      // 9. Tap BACK HOME and verify reactive state persistence on Home Screen
      await tester.ensureVisible(find.text('BACK HOME'));
      await tester.pump();
      await tester.tap(find.text('BACK HOME'));
      await tester.pumpAndSettle();

      expect(find.text('1,793'), findsOneWidget);
      expect(
        find.text('Win/Loss Elo rating · 49W – 6L (20 Tug-of-War KOs)'),
        findsOneWidget,
      );

      // 10. Switch to RANKS tab and verify updated EGO in League & Battle Log
      await tester.tap(find.text('RANKS'));
      await tester.pump();
      expect(find.text('49W - 6L · 20 KOs'), findsOneWidget);

      await tester.tap(find.text('BATTLE LOG'));
      await tester.pump();
      expect(find.text('+13 EGO'), findsOneWidget);
    },
  );

  testWidgets(
    'Production E2E Solo Warmup & Profile Calibration: Solo reps increment lifetime total without altering Win/Loss Elo rating',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ThresholdsConfig.loadFromAsset();
      await tester.pumpWidget(const PushGardApp());
      await tester.pump();

      // 1. Check PROFILE tab (Hardware Spike & Sensor Calibration)
      await tester.tap(find.text('PROFILE'));
      await tester.pump();
      expect(find.text('SENSOR CALIBRATION'), findsOneWidget);

      // 2. Return to HOME tab and launch SOLO WARMUP
      await tester.tap(find.text('HOME'));
      await tester.pump();
      await tester.ensureVisible(find.text('SOLO WARMUP'));
      await tester.pump();
      await tester.tap(find.text('SOLO WARMUP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GET READY'), findsOneWidget);

      // 3. Start countdown and enter Solo session
      await tester.tap(find.text('START COUNTDOWN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Verify no cheat buttons in Solo mode, only FINISH SET
      expect(find.text('+1 REP'), findsNothing);
      expect(find.text('FINISH SET'), findsOneWidget);

      final battleState =
          tester.state<BattleActiveScreenState>(find.byType(BattleActiveScreen));

      // 4. Perform 2 clean solo reps and tap FINISH SET
      battleState.recordCleanRepForTesting();
      await tester.pump();
      battleState.recordCleanRepForTesting();
      await tester.pump();
      await tester.tap(find.text('FINISH SET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. Verify Solo Session Complete summary (SOLO RESULT / COMPLETE, 1,780 EGO unchanged)
      expect(find.text('SOLO RESULT'), findsOneWidget);
      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.text('1,780'), findsOneWidget);

      // 6. Return Home and verify lifetime valid reps increased by +2 (12,480 -> 12,482)
      await tester.ensureVisible(find.text('BACK HOME'));
      await tester.pump();
      await tester.tap(find.text('BACK HOME'));
      await tester.pumpAndSettle();

      expect(find.text('1,780'), findsOneWidget);
      expect(find.text('12,482 valid reps'), findsOneWidget);
    },
  );

  testWidgets(
    'Beta Tester Edge Cases: Challenge GO -> Cancel -> Re-enter -> Mid-Battle Forfeit -> Rematch KO Recovery',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ThresholdsConfig.loadFromAsset();
      await tester.pumpWidget(const PushGardApp());
      await tester.pump();

      // 1. Tap "GO" on the vs. [CYBER_KONG] Challenge card
      await tester.ensureVisible(find.text('GO'));
      await tester.pump();
      await tester.tap(find.text('GO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GET READY'), findsOneWidget);

      // 2. Tap "CANCEL" on FramingScreen and verify return to Home
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('PUSHGARD'), findsOneWidget);

      // 3. Re-enter via "GO", pass 3-2-1 countdown, and tap "FORFEIT" mid-battle
      await tester.tap(find.text('GO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('START COUNTDOWN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('FORFEIT'), findsOneWidget);
      await tester.tap(find.text('FORFEIT'));
      await tester.pumpAndSettle();

      // 4. Verify FORFEIT result screen (1780 - 11 = 1769 EGO)
      expect(find.text('BATTLE RESULT'), findsOneWidget);
      expect(find.text('FORFEIT'), findsOneWidget);
      expect(find.text('1,769'), findsOneWidget);

      // 5. Tap "REMATCH" -> complete countdown -> trigger +15 KO win
      await tester.ensureVisible(find.text('REMATCH'));
      await tester.pump();
      await tester.tap(find.text('REMATCH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GET READY'), findsOneWidget);
      await tester.tap(find.text('START COUNTDOWN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final rematchState =
          tester.state<BattleActiveScreenState>(find.byType(BattleActiveScreen));
      rematchState.triggerKoForTesting();
      await tester.pumpAndSettle();

      // 6. Verify Rematch KO Win recovers EGO (1769 + 13 = 1782 EGO)
      expect(find.text('KO WIN'), findsOneWidget);
      expect(find.text('1,782'), findsOneWidget);
    },
  );
}
