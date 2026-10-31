import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/navigation_policy.dart';
import 'diagnostics.dart';
import 'models.dart';

class FantaStore extends ChangeNotifier {
  final diagnostics = Diagnostics();
  InAppWebViewController? controller;
  VoidCallback? onWebCommand;
  String session = 'unknown', contextLabel = '', scope = '';
  String? chosenTeam, shirt, rosterTeam;
  List<TeamData> ranking = [], teams = [];
  List<MatchData> matches = [];
  List<PlayerData> players = [];
  Set<String> available = {};
  Map<String, int> capabilities = {};
  DateTime? updatedAt;
  bool extracting = false, loading = false;
  String? issue;
  String? _script;
  String _lastPayload = '';
  Timer? _timeout;

  FantaStore() {
    diagnostics.record('startup');
  }
  List<TeamData> get allTeams {
    final map = {for (final t in teams) t.name: t};
    for (final t in ranking) {
      map[t.name] = t;
    }
    return map.values.toList();
  }

  TeamData? get myTeam {
    for (final t in allTeams) {
      if (t.name == chosenTeam) return t;
    }
    return null;
  }

  List<MatchData> get myMatches => chosenTeam == null
      ? []
      : matches.where((m) => m.involves(chosenTeam!)).toList();
  MatchData? get previous {
    final list = myMatches.where((m) => m.completed).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => (a.round ?? 0).compareTo(b.round ?? 0));
    return list.last;
  }

  MatchData? get next {
    final list = myMatches.where((m) => !m.completed).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => (a.round ?? 999).compareTo(b.round ?? 999));
    return list.first;
  }

  Map<String, int> get counts => {
    'ranking': ranking.length,
    'teams': teams.length,
    'matches': matches.length,
    'players': players.length,
    ...capabilities,
  };
  void attach(InAppWebViewController c) {
    controller = c;
  }

  void selectTeam(String name) {
    if (allTeams.any((t) => t.name == name)) {
      chosenTeam = name;
      notifyListeners();
    }
  }

  void pageStarted() {
    loading = true;
    _lastPayload = '';
    diagnostics.record('page_start', section: 'web');
    notifyListeners();
  }

  void pageFinished() {
    loading = false;
    diagnostics.record('page_loaded', section: 'web');
    notifyListeners();
    unawaited(capture());
  }

  void networkError({int? status}) {
    loading = false;
    issue = status == null
        ? 'Connessione al sito non disponibile.'
        : 'Il sito ha risposto con errore $status.';
    diagnostics.record(
      status == null ? 'network_error' : 'http_error',
      section: 'web',
      status: status,
    );
    notifyListeners();
  }

  void clear({bool recordEvent = true}) {
    ranking = [];
    teams = [];
    matches = [];
    players = [];
    scope = '';
    contextLabel = '';
    chosenTeam = null;
    shirt = null;
    rosterTeam = null;
    session = 'unknown';
    updatedAt = null;
    _lastPayload = '';
    available = {};
    if (recordEvent) diagnostics.record('session_cleared');
    notifyListeners();
  }

  void accept(PageSnapshot page) {
    if (page.session == 'login_form') {
      clear(recordEvent: false);
      diagnostics.record('login_form_observed');
      session = 'login_form';
      notifyListeners();
      return;
    }
    if (scope != page.scope) {
      ranking = [];
      teams = [];
      matches = [];
      players = [];
      chosenTeam = null;
      shirt = null;
      rosterTeam = null;
    }
    scope = page.scope;
    contextLabel = page.contextLabel;
    session = page.session;
    if (page.ranking.isNotEmpty) ranking = page.ranking;
    if (page.teams.isNotEmpty) teams = page.teams;
    if (page.matches.isNotEmpty) matches = page.matches;
    if (page.players.isNotEmpty) {
      players = page.players;
      rosterTeam = page.rosterTeam;
    }
    if (page.ownTeam?.isNotEmpty == true) chosenTeam = page.ownTeam;
    shirt = page.shirt ?? shirt;
    capabilities = {
      for (final k in ['tables', 'matchCards', 'teamCards'])
        k: (realNumber(page.capabilities[k])?.toInt() ?? 0).clamp(0, 10000),
    };
    updatedAt = page.capturedAt;
    issue = null;
    notifyListeners();
  }

  Future<void> capture() async {
    final c = controller;
    if (c == null || extracting || loading) return;
    extracting = true;
    try {
      if (!trustedPage((await c.getUrl())?.toString())) {
        diagnostics.record('origin_rejected');
        return;
      }
      if (loading) return;
      _script ??= await rootBundle.loadString('assets/data_bridge.js');
      final raw = await c.evaluateJavascript(source: _script!);
      if (loading || raw == null) return;
      if (raw is! String || raw.length > 256000) {
        throw const FormatException('invalid_payload');
      }
      if (raw == _lastPayload) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('invalid_payload');
      }
      final page = PageSnapshot.fromJson(data);
      accept(page);
      _lastPayload = raw;
      diagnostics.record(
        'extract_ok',
        count: ranking.length + teams.length + matches.length + players.length,
      );
    } catch (_) {
      if (loading) return;
      issue =
          'Struttura dei dati non riconosciuta. Apri la sezione sul sito e torna nell’app, oppure esporta la diagnostica.';
      diagnostics.record('extract_error');
      notifyListeners();
    } finally {
      extracting = false;
    }
  }

  Future<bool> navigate(String section) async {
    final c = controller;
    diagnostics.record('navigation_requested', section: section);
    if (c == null || !trustedPage((await c.getUrl())?.toString())) return false;
    try {
      final js = await rootBundle.loadString('assets/navigation.js');
      await c.evaluateJavascript(source: js);
      onWebCommand?.call();
      final clicked = await c.evaluateJavascript(
        source:
            'window.__phNavigation?.click(${jsonEncode(sectionLabels[section] ?? [])}) === true',
      );
      if (clicked != true) {
        diagnostics.record('navigation_missing', section: section);
        return false;
      }
      loading = true;
      notifyListeners();
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 12), () {
        loading = false;
        notifyListeners();
        unawaited(capture());
      });
      unawaited(Future<void>.delayed(const Duration(seconds: 2), capture));
      return true;
    } catch (_) {
      diagnostics.record('navigation_missing', section: section);
      return false;
    }
  }

  String diagnosticJson() =>
      diagnostics.export(session: session, counts: counts);
  @override
  void dispose() {
    _timeout?.cancel();
    diagnostics.dispose();
    super.dispose();
  }
}
