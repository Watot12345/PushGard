import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/sound_cue_service.dart';
import 'package:mobile/core/state/player_session_store.dart';
import 'package:mobile/features/history/screens/history_screen.dart';
import 'package:mobile/features/match/screens/battle_active_screen.dart';
import 'package:mobile/features/match/screens/framing_screen.dart';
import 'package:mobile/spike/spike_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cameraChannel = MethodChannel('com.pushgard/camera_pose');
  const permissionChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    PlayerSessionStore.instance.resetForTesting();
    SoundCueService.instance.resetForTesting();
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
    '1. BattleActiveScreen plays audio cues for countdown, go, valid rep, fault, and respects mute',
    (WidgetTester tester) async {
      final playedCues = <String>[];
      SoundCueService.instance.onCueForTesting = playedCues.add;

      await tester.pumpWidget(
        const MaterialApp(home: BattleActiveScreen(isBattle: false)),
      );
      // Advance through 3-2-1 countdown
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(playedCues, contains('countdown'));
      expect(playedCues, contains('go'));

      final state = tester.state<BattleActiveScreenState>(
        find.byType(BattleActiveScreen),
      );
      state.recordCleanRepForTesting();
      await tester.pump();
      expect(playedCues.last, equals('rep'));

      state.recordShallowFaultForTesting();
      await tester.pump();
      expect(playedCues.last, equals('fault'));

      // Mute audio via HUD mute button -> further reps should not emit cues
      expect(find.byTooltip('Mute sound cues'), findsOneWidget);
      await tester.tap(find.byTooltip('Mute sound cues'));
      await tester.pump();

      final countBeforeMute = playedCues.length;
      state.recordCleanRepForTesting();
      await tester.pump();
      expect(playedCues.length, equals(countBeforeMute));
    },
  );

  testWidgets(
    '2. FramingScreen and SpikeScreen show friendly Android APK message instead of raw MissingPluginException',
    (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (MethodCall call) async {
        throw MissingPluginException(
          'No implementation found for method ${call.method}',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(home: FramingScreen(isBattle: true)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MissingPluginException'), findsNothing);
      expect(find.textContaining('Android APK'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SpikeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('MissingPluginException'), findsNothing);
      expect(find.textContaining('Android APK'), findsOneWidget);
    },
  );

  testWidgets(
    '3. HistoryScreen displays active player handle instead of hardcoded VANGUARD_01',
    (WidgetTester tester) async {
      PlayerSessionStore.instance.applyAuthenticatedPlayer({
        'handle': 'GYM_BRO_77',
        'provider': 'guest',
        'is_guest': true,
        'ego_rating': 1650,
        'wins': 12,
        'completed_matches': 15,
        'ko_wins': 4,
        'lifetime_valid_reps': 420,
      });

      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('YOU (GYM_BRO_77)'), findsOneWidget);
      expect(find.text('YOU (VANGUARD_01)'), findsNothing);
    },
  );

  test(
    '4. PlayerSessionStore exports and restores full session state from JSON',
    () {
      final store = PlayerSessionStore.instance;
      store.applyAuthenticatedPlayer({
        'handle': 'IRON_MIND',
        'provider': 'manual',
        'is_guest': false,
        'ego_rating': 1510,
        'wins': 9,
        'completed_matches': 12,
        'ko_wins': 3,
        'lifetime_valid_reps': 640,
      });
      store.recordAttemptOutcome(
        isBattle: true,
        validReps: 35,
        opponentReps: 20,
        isKnockout: true,
        isForfeit: false,
        opponentName: 'GYM_RIVAL',
        opponentEgo: 1500,
      );

      final exported = store.toJson();
      final savedEgo = store.egoRating;
      final savedHistoryCount = store.battleHistory.length;

      // Reset to defaults, then restore from JSON
      store.resetForTesting();
      expect(store.handle, equals('ATHLETE'));
      expect(store.egoRating, equals(1000));
      expect(store.totalBattles, equals(0));
      expect(store.lifetimeValidReps, equals(0));
      expect(store.battleHistory, isEmpty);

      store.loadFromJson(exported);
      expect(store.handle, equals('IRON_MIND'));
      expect(store.provider, equals('manual'));
      expect(store.egoRating, equals(savedEgo));
      expect(store.koWins, equals(4));
      expect(store.battleHistory.length, equals(savedHistoryCount));
      expect(store.battleHistory.first.opponent, equals('GYM_RIVAL'));
    },
  );
}
