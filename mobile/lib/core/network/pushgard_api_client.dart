import 'dart:convert';
import 'package:http/http.dart' as http;

class LeaderboardEntry {
  final int rank;
  final int id;
  final String handle;
  final int egoRating;
  final String rankTier;
  final int completedMatches;
  final int wins;
  final int losses;
  final int koWins;
  final int lifetimeValidReps;

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.handle,
    required this.egoRating,
    required this.rankTier,
    required this.completedMatches,
    required this.wins,
    required this.losses,
    required this.koWins,
    required this.lifetimeValidReps,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      id: (json['id'] as num).toInt(),
      handle: json['handle'] as String? ?? 'PLAYER',
      egoRating: (json['ego_rating'] as num).toInt(),
      rankTier: json['rank_tier'] as String? ?? 'Spartan',
      completedMatches: (json['completed_matches'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      koWins: (json['ko_wins'] as num?)?.toInt() ?? 0,
      lifetimeValidReps: (json['lifetime_valid_reps'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardResponse {
  final String type;
  final int minMatchesRequired;
  final int? myRank;
  final List<LeaderboardEntry> entries;

  const LeaderboardResponse({
    required this.type,
    required this.minMatchesRequired,
    required this.myRank,
    required this.entries,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['leaderboard'] as List<dynamic>? ?? const [];
    return LeaderboardResponse(
      type: json['type'] as String? ?? 'ego',
      minMatchesRequired: (json['min_matches_required'] as num?)?.toInt() ?? 0,
      myRank: (json['my_rank'] as num?)?.toInt(),
      entries: rawList
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromJson)
          .toList(),
    );
  }
}

/// Client for the PushGard Laravel API (`server/routes/api.php`).
/// Uses `--dart-define=PUSHGARD_API_URL` when provided.
class PushgardApiClient {
  static final PushgardApiClient instance = PushgardApiClient();

  final String baseUrl;
  final http.Client _http;
  String? _token;

  PushgardApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'PUSHGARD_API_URL',
              defaultValue: 'http://127.0.0.1:8000/api',
            ),
        _http = httpClient ?? http.Client();

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> register({
    required String handle,
    required String email,
    required String password,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'handle': handle,
        'email': email,
        'password': password,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _token = body['token'] as String?;
      return body;
    }
    throw Exception(body['message'] ?? 'Registration failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _token = body['token'] as String?;
      return body;
    }
    throw Exception(body['message'] ?? 'Login failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> createMatch({int? opponentId}) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/matches'),
      headers: _headers(),
      body: jsonEncode({
        'opponent_id': ?opponentId,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw Exception(body['message'] ?? 'Create match failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> startMatch(int matchId) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/matches/$matchId/start'),
      headers: _headers(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw Exception(body['message'] ?? 'Start match failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> submitMatch({
    required int matchId,
    required String nonce,
    required List<List<num>> samples,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/matches/$matchId/submit'),
      headers: _headers(),
      body: jsonEncode({
        'nonce': nonce,
        'samples': samples,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw Exception(body['message'] ?? 'Submit match failed (${res.statusCode})');
  }

  Future<LeaderboardResponse> fetchLeaderboard({
    String type = 'ego',
    bool includeProvisional = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/leaderboards?type=$type&include_provisional=${includeProvisional ? '1' : '0'}',
    );
    final res = await _http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 4));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return LeaderboardResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Leaderboard fetch failed (${res.statusCode})');
  }
}
