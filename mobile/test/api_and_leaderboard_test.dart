import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/pushgard_api_client.dart';
import 'package:mobile/features/history/screens/history_screen.dart';

void main() {
  group('PushgardApiClient', () {
    test('parses leaderboard entries and sends bearer token', () async {
      String? capturedAuth;
      String? capturedQuery;

      final mockHttp = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedQuery = request.url.query;
        return http.Response(
          jsonEncode({
            'type': 'ego',
            'min_matches_required': 10,
            'my_rank': 2,
            'leaderboard': [
              {
                'rank': 1,
                'id': 9,
                'handle': 'TITAN_PRO',
                'ego_rating': 1920,
                'rank_tier': 'God of War',
                'completed_matches': 25,
                'wins': 21,
                'losses': 4,
                'ko_wins': 12,
                'lifetime_valid_reps': 3100,
              },
            ],
          }),
          200,
        );
      });

      final client = PushgardApiClient(
        baseUrl: 'https://api.pushgard.test/api',
        httpClient: mockHttp,
      )..setToken('secret-token');

      final res = await client.fetchLeaderboard(type: 'ego');
      expect(capturedAuth, 'Bearer secret-token');
      expect(capturedQuery, 'type=ego&include_provisional=0');
      expect(res.myRank, 2);
      expect(res.entries.length, 1);
      expect(res.entries.first.handle, 'TITAN_PRO');
      expect(res.entries.first.egoRating, 1920);
    });
  });

  group('HistoryScreen Global Leaderboard UI', () {
    testWidgets('switches between EGO, KO WINS, and REPS leaderboard filters', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('EGO'), findsOneWidget);
      expect(find.text('KO WINS'), findsOneWidget);
      expect(find.text('REPS'), findsOneWidget);

      await tester.tap(find.text('KO WINS'));
      await tester.pumpAndSettle();
      expect(find.text('29'), findsOneWidget);

      await tester.tap(find.text('REPS'));
      await tester.pumpAndSettle();
      expect(find.text('16200'), findsOneWidget);
    });
  });
}
