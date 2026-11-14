import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/pushgard_api_client.dart';
import 'package:mobile/core/state/player_session_store.dart';
import 'package:mobile/features/auth/screens/auth_screen.dart';
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

    test('executes createMatch -> startMatch -> submitMatch with raw samples', () async {
      final calledPaths = <String>[];
      final mockHttp = MockClient((request) async {
        calledPaths.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/matches') {
          return http.Response(jsonEncode({'match': {'id': 77}}), 201);
        }
        if (request.url.path == '/api/matches/77/start') {
          return http.Response(jsonEncode({'nonce': 'nonce-xyz-99'}), 201);
        }
        if (request.url.path == '/api/matches/77/submit') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['nonce'], 'nonce-xyz-99');
          expect((body['samples'] as List).length, 2);
          return http.Response(
            jsonEncode({'attempt_valid': true, 'server_valid_reps': 12}),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final client = PushgardApiClient(
        baseUrl: 'https://api.pushgard.test/api',
        httpClient: mockHttp,
      )..setToken('player-jwt');

      final matchRes = await client.createMatch();
      final matchId = (matchRes['match']['id'] as num).toInt();
      final startRes = await client.startMatch(matchId);
      final submitRes = await client.submitMatch(
        matchId: matchId,
        nonce: startRes['nonce'] as String,
        samples: [
          [0, 165.0, 5.0, 0.92],
          [40, 80.0, 6.0, 0.90],
        ],
      );

      expect(calledPaths, [
        'POST /api/matches',
        'POST /api/matches/77/start',
        'POST /api/matches/77/submit',
      ]);
      expect(submitRes['server_valid_reps'], 12);
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

  group('AuthScreen (Manual, Social OAuth, Guest Mode)', () {
    testWidgets('shows all auth choices and creates unique guest DB user with warning', (
      tester,
    ) async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/auth/guest');
        return http.Response(
          jsonEncode({
            'token': 'guest-token-123',
            'warning': 'Guest account has no backup recovery.',
            'player': {
              'id': 42,
              'handle': 'GUEST_7F3A12',
              'provider': 'guest',
              'is_guest': true,
              'ego_rating': 1000,
              'wins': 0,
              'completed_matches': 0,
              'ko_wins': 0,
              'lifetime_valid_reps': 0,
            },
          }),
          201,
        );
      });

      final client = PushgardApiClient(
        baseUrl: 'https://api.pushgard.test/api',
        httpClient: mockHttp,
      );

      await tester.pumpWidget(MaterialApp(home: AuthScreen(apiClient: client)));
      await tester.pumpAndSettle();

      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('CONTINUE WITH GMAIL / GOOGLE'), findsOneWidget);
      expect(find.text('CONTINUE WITH FACEBOOK'), findsOneWidget);
      expect(find.text('PLAY AS GUEST (NO BACKUP RECOVERY)'), findsOneWidget);

      await tester.ensureVisible(find.text('PLAY AS GUEST (NO BACKUP RECOVERY)'));
      await tester.tap(find.text('PLAY AS GUEST (NO BACKUP RECOVERY)'));
      await tester.pumpAndSettle();

      // Explicit no-recovery warning dialog appears
      expect(find.text('GUEST MODE WARNING'), findsOneWidget);
      await tester.tap(find.text('CREATE GUEST'));
      await tester.pumpAndSettle();

      expect(PlayerSessionStore.instance.handle, 'GUEST_7F3A12');
      expect(PlayerSessionStore.instance.isGuest, isTrue);
      expect(PlayerSessionStore.instance.egoRating, 1000);
      expect(client.isAuthenticated, isTrue);
      PlayerSessionStore.instance.resetForTesting();
    });
  });
}
