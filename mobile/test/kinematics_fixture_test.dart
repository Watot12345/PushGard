import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/thresholds_config.dart';
import 'package:mobile/core/kinematics/attempt_record_builder.dart';
import 'package:mobile/core/kinematics/joint_angle_math.dart';
import 'package:mobile/core/kinematics/rep_cycle_detector.dart';

void main() {
  group('Shared Hand-Derived Fixtures (/fixtures/*.json)', () {
    final fixturesDir = Directory('../fixtures');
    final fixtureFiles = [
      '01_clean_multi_rep.json',
      '02_shallow_and_no_lockout.json',
      '03_bad_body_line_and_speed.json',
      '04_tracking_gap_and_low_conf.json',
      '05_jitter_and_out_of_window.json',
      '06_low_fps_attempt.json',
    ];

    for (final fileName in fixtureFiles) {
      test('validates shared fixture $fileName', () {
        final file = File('${fixturesDir.path}/$fileName');
        expect(file.existsSync(), isTrue, reason: 'Missing fixture $fileName');

        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final expected = data['expected'] as Map<String, dynamic>;
        final rawSamples = (data['samples'] as List<dynamic>)
            .map((row) => (row as List<dynamic>).cast<num>())
            .toList();

        final detector = RepCycleDetector(config: const ThresholdsConfig());
        final result = detector.evaluateAttemptSamples(rawSamples);

        expect(
          result.attemptValid,
          expected['attempt_valid'],
          reason: 'attemptValid mismatch in $fileName',
        );
        expect(
          result.attemptRejectReason,
          expected['attempt_reject_reason'],
          reason: 'attemptRejectReason mismatch in $fileName',
        );
        expect(
          result.validRepCount,
          expected['valid_rep_count'],
          reason: 'validRepCount mismatch in $fileName',
        );
        expect(
          result.rejectedRepCount,
          expected['rejected_rep_count'],
          reason: 'rejectedRepCount mismatch in $fileName',
        );

        final expectedReps = expected['reps'] as List<dynamic>;
        expect(
          result.reps.length,
          expectedReps.length,
          reason: 'Total detected cycles mismatch in $fileName',
        );

        for (int i = 0; i < expectedReps.length; i++) {
          final expRep = expectedReps[i] as Map<String, dynamic>;
          final actRep = result.reps[i];
          expect(actRep.repIndex, expRep['rep_index']);
          expect(
            actRep.valid,
            expRep['valid'],
            reason: 'Rep #${i + 1} validity mismatch in $fileName',
          );
          expect(
            actRep.rejectReason,
            expRep['reject_reason'],
            reason: 'Rep #${i + 1} rejectReason mismatch in $fileName',
          );
        }
      });
    }
  });

  group('JointAngleMath & AttemptRecordBuilder v1.1', () {
    test('computes 90 degree right-angle elbow and 0 degree straight body line', () {
      final elbowDeg = JointAngleMath.computeElbowAngle(
        shoulder: [0.0, 1.0, 0.0, 0.95],
        elbow: [0.0, 0.0, 0.0, 0.95],
        wrist: [1.0, 0.0, 0.0, 0.95],
      );
      expect(elbowDeg, closeTo(90.0, 1e-4));

      final bodyDev = JointAngleMath.computeBodyLineDeviation(
        shoulder: [0.0, 0.0, 0.0, 0.95],
        hip: [1.0, 0.0, 0.0, 0.95],
        ankle: [2.0, 0.0, 0.0, 0.95],
      );
      expect(bodyDev, closeTo(0.0, 1e-4));
    });

    test('AttemptRecordBuilder outputs canonical v1.1 schema without player_id', () {
      final builder = AttemptRecordBuilder(
        attemptId: '01931ea4-82a1-7d12-9c94-1a80d418bc22',
        matchId: '01931ea4-82a1-7d12-9c94-1a80d418bc23',
        nonce: 'nonce-12345',
        bodySideSelected: BodySide.right,
      );

      final file = File('../fixtures/01_clean_multi_rep.json');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final rawSamples = (data['samples'] as List<dynamic>)
          .map((row) => (row as List<dynamic>).cast<num>())
          .toList();

      for (final s in rawSamples) {
        builder.addRawSample(
          tMs: s[0].toInt(),
          rawElbow: s[1].toDouble(),
          rawBody: s[2].toDouble(),
          conf: s[3].toDouble(),
        );
      }

      final payload = builder.buildPayload();
      expect(payload['version'], '1.1');
      expect(payload.containsKey('player_id'), isFalse);
      expect(payload['attempt_id'], '01931ea4-82a1-7d12-9c94-1a80d418bc22');
      expect(payload['metrics']['body_side_selected'], 'right');
      expect((payload['client_claimed_reps'] as List).length, 3);
    });
  });
}
