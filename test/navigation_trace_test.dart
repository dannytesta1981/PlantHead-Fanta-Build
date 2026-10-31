import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/data/diagnostics.dart';
import 'package:planthead_fanta/data/navigation_trace.dart';

void main() {
  test(
    'route categories distinguish known paths without exporting private paths',
    () {
      expect(
        routeCategory(Uri.parse('https://leghe.fantacalcio.it/')),
        'official_home',
      );
      expect(
        routeCategory(
          Uri.parse('https://leghe.fantacalcio.it/login?token=TOP_SECRET'),
        ),
        'official_login',
      );
      expect(
        routeCategory(
          Uri.parse(
            'https://leghe.fantacalcio.it/private-league/owner-secret#auth-secret',
          ),
        ),
        'official_other',
      );
      expect(
        routeCategory(
          Uri.parse('https://leghe.fantacalcio.it.evil.test/login'),
        ),
        'external',
      );
      expect(
        routeCategory(
          Uri.parse('https://accounts.google.com/path?code=TOP_SECRET'),
        ),
        'identity',
      );
    },
  );
  test(
    'device-like home then link 404 distinguishes site link from app command',
    () {
      final d = Diagnostics();
      final t = NavigationTrace(d);
      t.command(
        'app_initial_home',
        destination: Uri.parse('https://leghe.fantacalcio.it/'),
      );
      t.action(Uri.parse('https://leghe.fantacalcio.it/'), mainFrame: true);
      t.started(Uri.parse('https://leghe.fantacalcio.it/'));
      t.event(
        'web_load_stop',
        uri: Uri.parse('https://leghe.fantacalcio.it/'),
        mainFrame: true,
      );
      t.action(
        Uri.parse('https://leghe.fantacalcio.it/login?token=TOP_SECRET'),
        mainFrame: true,
        cause: 'web_link',
      );
      t.started(
        Uri.parse('https://leghe.fantacalcio.it/login?token=TOP_SECRET'),
      );
      t.event(
        'web_main_404',
        uri: Uri.parse('https://leghe.fantacalcio.it/login?token=TOP_SECRET'),
        mainFrame: true,
        status: 404,
      );
      final e = d.entries.last;
      expect(e['route'], 'official_login');
      expect(e['from'], 'official_home');
      expect(e['cause'], 'web_link');
      expect(e['httpStatus'], 404);
      final text = d.export(session: 'unknown', counts: {});
      expect(text, isNot(contains('TOP_SECRET')));
      expect(text, isNot(contains('https://')));
    },
  );
  test(
    'native redirect and subframe errors have separate evidence and windows',
    () {
      final d = Diagnostics();
      final t = NavigationTrace(d, window: 'popup');
      t.action(Uri.parse('https://leghe.fantacalcio.it/'), mainFrame: true);
      t.started(Uri.parse('https://leghe.fantacalcio.it/'));
      t.redirect();
      t.event(
        'web_main_404',
        uri: Uri.parse('https://leghe.fantacalcio.it/secret-path'),
        mainFrame: true,
        status: 404,
      );
      expect(d.entries.last['cause'], 'server_redirect');
      expect(d.entries.last['window'], 'popup');
      t.event(
        'web_http_error',
        uri: Uri.parse('https://cdn.example.test/ad?token=secret'),
        mainFrame: false,
        status: 404,
      );
      expect(d.entries.last['category'], 'subframe');
      expect(d.entries.last['event'], 'web_http_error');
      t.event(
        'web_commit',
        uri: Uri.parse('https://leghe.fantacalcio.it/login'),
        mainFrame: true,
      );
      t.action(
        Uri.parse('https://leghe.fantacalcio.it/'),
        mainFrame: true,
        cause: 'web_link',
      );
      expect(d.entries.last['cause'], 'web_link');
      d.record(
        'web_request',
        route: 'https://secret',
        from: 'secret',
        cause: 'secret',
        window: 'secret',
        method: 'secret',
      );
      expect(jsonEncode(d.entries.last), isNot(contains('secret')));
    },
  );
}
