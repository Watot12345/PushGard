import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/thresholds_config.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('PushGard PDF theme & UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PushGardApp());
    expect(find.byType(PushGardApp), findsOneWidget);
    expect(find.text('PUSHGARD'), findsOneWidget);
    expect(find.text('START BATTLE'), findsOneWidget);
    expect(find.text('CHALLENGES'), findsOneWidget);
  });

  group('Tug-of-War Battle Bar & KO Rules', () {
    const cfg = ThresholdsConfig();

    test('starts at 50/50 (0.5) when reps are equal', () {
      expect(
        cfg.computeTugOfWarRatio(playerValidReps: 20, opponentValidReps: 20),
        closeTo(0.5, 1e-6),
      );
      expect(
        cfg.isKnockoutReached(playerValidReps: 20, opponentValidReps: 20),
        isFalse,
      );
    });

    test('reaches 1.0 (100% KO win) at +15 rep lead', () {
      expect(
        cfg.computeTugOfWarRatio(playerValidReps: 30, opponentValidReps: 15),
        closeTo(1.0, 1e-6),
      );
      expect(
        cfg.isKnockoutReached(playerValidReps: 30, opponentValidReps: 15),
        isTrue,
      );
    });

    test('reaches 0.0 (KO loss) at -15 rep deficit', () {
      expect(
        cfg.computeTugOfWarRatio(playerValidReps: 10, opponentValidReps: 25),
        closeTo(0.0, 1e-6),
      );
      expect(
        cfg.isKnockoutReached(playerValidReps: 10, opponentValidReps: 25),
        isTrue,
      );
    });
  });

  group('Win/Loss Elo Ego Rating Math', () {
    const cfg = ThresholdsConfig();

    test('win vs equal rating gains +12 standard and +20 provisional EGO', () {
      final standardWin = cfg.computeEloDelta(
        playerEgo: 1500,
        opponentEgo: 1500,
        actualScore: 1.0,
        completedMatches: 25,
      );
      final provisionalWin = cfg.computeEloDelta(
        playerEgo: 1000,
        opponentEgo: 1000,
        actualScore: 1.0,
        completedMatches: 3,
      );
      expect(standardWin, 12);
      expect(provisionalWin, 20);
    });

    test('beating a higher-rated rival yields more EGO than beating an underdog', () {
      final upsetWin = cfg.computeEloDelta(
        playerEgo: 1400,
        opponentEgo: 1800,
        actualScore: 1.0,
        completedMatches: 20,
      );
      final favoredWin = cfg.computeEloDelta(
        playerEgo: 1800,
        opponentEgo: 1400,
        actualScore: 1.0,
        completedMatches: 20,
      );
      expect(upsetWin, greaterThan(favoredWin));
      expect(upsetWin, 22);
      expect(favoredWin, 2);
    });

    test('losing drops EGO and respects rating floor (100)', () {
      final lossDelta = cfg.computeEloDelta(
        playerEgo: 1500,
        opponentEgo: 1500,
        actualScore: 0.0,
        completedMatches: 20,
      );
      expect(lossDelta, -12);

      final floorClampedLoss = cfg.computeEloDelta(
        playerEgo: 105,
        opponentEgo: 1500,
        actualScore: 0.0,
        completedMatches: 2,
      );
      expect(105 + floorClampedLoss, greaterThanOrEqualTo(cfg.eloRatingFloor));
    });
  });
}
