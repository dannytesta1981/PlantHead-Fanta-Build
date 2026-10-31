import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/data/diagnostics.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/data/models.dart';

PageSnapshot page(
  String scope, {
  String session = 'league_page',
  List<Map<String, dynamic>> ranking = const [],
}) => PageSnapshot.fromJson({
  'schema': 'ph-dom/1',
  'scope': scope,
  'contextLabel': scope,
  'session': session,
  'ranking': ranking,
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'navigation racing with DOM capture does not show a false data error',
    () async {
      final store = FantaStore();
      store.attach(LoadingRaceController(store));
      await store.capture();
      expect(store.issue, isNull);
      expect(store.loading, isTrue);
      store.dispose();
    },
  );
  test('changing league clears standings and selected team', () {
    final s = FantaStore();
    s.accept(
      page(
        'A',
        ranking: [
          {'name': 'A team', 'rank': 2, 'points': 12},
        ],
      ),
    );
    s.selectTeam('A team');
    expect(s.myTeam?.points, 12);
    s.accept(page('B'));
    expect(s.ranking, isEmpty);
    expect(s.chosenTeam, isNull);
    s.dispose();
  });
  test('expired login clears private league data', () {
    final s = FantaStore();
    s.accept(
      page(
        'A',
        ranking: [
          {'name': 'A team', 'points': 12},
        ],
      ),
    );
    s.accept(page('login', session: 'login_form'));
    expect(s.ranking, isEmpty);
    expect(s.session, 'login_form');
    s.dispose();
  });
  test('real zero score differs from absent score', () {
    expect(
      MatchData.fromJson({
        'home': 'A',
        'away': 'B',
        'homeScore': 0,
        'awayScore': 0,
      }).completed,
      isTrue,
    );
    expect(MatchData.fromJson({'home': 'A', 'away': 'B'}).completed, isFalse);
  });
  test('invalid schema, numbers and signed images are rejected', () {
    expect(
      () => PageSnapshot.fromJson({'schema': 'unknown'}),
      throwsFormatException,
    );
    expect(realNumber(double.infinity), isNull);
    expect(realNumber('12'), isNull);
    expect(realNumber(0), 0);
    expect(safeImage('https://cdn.fantacalcio.it/a?token=private'), isNull);
  });
  test('diagnostic allowlist never exports arbitrary sensitive strings', () {
    final d = Diagnostics();
    d.record('password=secret', section: 'https://example.test/?token=private');
    d.record('extract_ok', section: 'token=private', count: 2);
    final text = d.export(
      session: 'password=secret',
      counts: {'ranking': 2, 'cookie=secret': 123},
    );
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('private')));
    expect(text, isNot(contains('https://')));
    expect(jsonDecode(text)['counts']['ranking'], 2);
    d.dispose();
  });
}

class LoadingRaceController implements InAppWebViewController {
  LoadingRaceController(this.store);
  final FantaStore store;
  @override
  Future<WebUri?> getUrl() async => WebUri('https://leghe.fantacalcio.it/');
  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    store.pageStarted();
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
