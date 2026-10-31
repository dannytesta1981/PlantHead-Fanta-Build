import '../core/navigation_policy.dart';

String cleanText(dynamic value) => value is String
    ? value
          .replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
          .trim()
          .substring(
            0,
            value
                .replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
                .trim()
                .length
                .clamp(0, 160),
          )
    : '';
num? realNumber(dynamic value) =>
    value is num && value.isFinite && value.abs() < 1000000000 ? value : null;
String? safeImage(dynamic value) {
  if (value is! String || value.length > 2048) return null;
  final u = Uri.tryParse(value);
  if (u == null ||
      u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty) {
    return null;
  }
  if (!u.host.endsWith('.fantacalcio.it') &&
      u.host != 'fantacalcio.it' &&
      !u.host.endsWith('.cloudfront.net')) {
    return null;
  }
  if (u.queryParameters.keys.any(
    (k) =>
        RegExp('token|auth|secret|signature', caseSensitive: false).hasMatch(k),
  )) {
    return null;
  }
  return u.toString();
}

List<Map<String, dynamic>> objects(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .take(1000)
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
    : [];

class TeamData {
  const TeamData({
    required this.name,
    this.owner = '',
    this.logo,
    this.shirt,
    this.rank,
    this.points,
    this.played,
    this.credits,
    this.total,
  });
  factory TeamData.fromJson(Map<String, dynamic> j) => TeamData(
    name: cleanText(j['name']),
    owner: cleanText(j['owner']),
    logo: safeImage(j['logo']),
    shirt: safeImage(j['shirt']),
    rank: realNumber(j['rank'])?.toInt(),
    points: realNumber(j['points']),
    played: realNumber(j['played'])?.toInt(),
    credits: realNumber(j['credits']),
    total: realNumber(j['total']),
  );
  final String name, owner;
  final String? logo, shirt;
  final int? rank, played;
  final num? points, credits, total;
}

class MatchData {
  const MatchData({
    required this.home,
    required this.away,
    this.homeLogo,
    this.awayLogo,
    this.homeScore,
    this.awayScore,
    this.round,
  });
  factory MatchData.fromJson(Map<String, dynamic> j) => MatchData(
    home: cleanText(j['home']),
    away: cleanText(j['away']),
    homeLogo: safeImage(j['homeLogo']),
    awayLogo: safeImage(j['awayLogo']),
    homeScore: realNumber(j['homeScore'])?.toInt(),
    awayScore: realNumber(j['awayScore'])?.toInt(),
    round: realNumber(j['round'])?.toInt(),
  );
  final String home, away;
  final String? homeLogo, awayLogo;
  final int? homeScore, awayScore, round;
  bool get completed => homeScore != null && awayScore != null;
  bool involves(String name) => home == name || away == name;
}

class PlayerData {
  const PlayerData({
    required this.name,
    required this.role,
    this.club = '',
    this.cost,
    this.value,
    this.photo,
  });
  factory PlayerData.fromJson(Map<String, dynamic> j) => PlayerData(
    name: cleanText(j['name']),
    role: cleanText(j['role']),
    club: cleanText(j['club']),
    cost: realNumber(j['cost']),
    value: realNumber(j['value']),
    photo: safeImage(j['photo']),
  );
  final String name, role, club;
  final num? cost, value;
  final String? photo;
}

class PageSnapshot {
  PageSnapshot({
    required this.scope,
    required this.contextLabel,
    required this.session,
    required this.ranking,
    required this.teams,
    required this.matches,
    required this.players,
    this.ownTeam,
    this.shirt,
    this.rosterTeam,
    required this.capabilities,
  }) : capturedAt = DateTime.now();
  factory PageSnapshot.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 'ph-dom/1') {
      throw const FormatException('unsupported_schema');
    }
    return PageSnapshot(
      scope: cleanText(j['scope']),
      contextLabel: cleanText(j['contextLabel']),
      session:
          const {'league_page', 'login_form', 'unknown'}.contains(j['session'])
          ? j['session']
          : 'unknown',
      ranking: objects(j['ranking'])
          .map(TeamData.fromJson)
          .where((e) => e.name.isNotEmpty && e.points != null)
          .toList(),
      teams: objects(
        j['teams'],
      ).map(TeamData.fromJson).where((e) => e.name.isNotEmpty).toList(),
      matches: objects(j['matches'])
          .map(MatchData.fromJson)
          .where((e) => e.home.isNotEmpty && e.away.isNotEmpty)
          .toList(),
      players: objects(j['players'])
          .map(PlayerData.fromJson)
          .where((e) => e.name.isNotEmpty && e.role.isNotEmpty)
          .toList(),
      ownTeam: cleanText(j['ownTeam']),
      shirt: safeImage(j['shirt']),
      rosterTeam: cleanText(j['rosterTeam']),
      capabilities: j['capabilities'] is Map
          ? Map<String, dynamic>.from(j['capabilities'])
          : {},
    );
  }
  final String scope, contextLabel, session;
  final String? ownTeam, shirt, rosterTeam;
  final List<TeamData> ranking, teams;
  final List<MatchData> matches;
  final List<PlayerData> players;
  final Map<String, dynamic> capabilities;
  final DateTime capturedAt;
}

bool trustedPage(String? url) =>
    NavigationPolicy.isOfficial(Uri.tryParse(url ?? ''));
