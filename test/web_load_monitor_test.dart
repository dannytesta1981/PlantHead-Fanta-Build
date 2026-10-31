import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/core/web_load_monitor.dart';
import 'package:planthead_fanta/data/diagnostics.dart';

void main() {
  testWidgets('missing creation callback times out and retry recovers', (
    t,
  ) async {
    final m = WebLoadMonitor(timeout: const Duration(seconds: 2));
    var timeouts = 0;
    m.onTimeout = () => timeouts++;
    m.begin();
    await t.pump(const Duration(seconds: 2));
    expect(m.failure, 'timeout');
    expect(timeouts, 1);
    m.begin(restart: true);
    expect(m.complete(m.generation, hasContent: true), isTrue);
    await t.pump(const Duration(seconds: 3));
    expect(m.failure, isNull);
    m.dispose();
  });
  testWidgets(
    '100 percent and loadStop with empty body cannot mask white page',
    (t) async {
      final m = WebLoadMonitor(timeout: const Duration(seconds: 2));
      m.begin();
      m.updateProgress(100);
      expect(m.complete(m.generation, hasContent: false), isFalse);
      expect(m.busy, isTrue);
      await t.pump(const Duration(seconds: 2));
      expect(m.failure, 'timeout');
      m.dispose();
    },
  );
  testWidgets('redirects cannot postpone timeout indefinitely', (t) async {
    final m = WebLoadMonitor(timeout: const Duration(seconds: 3));
    m.begin();
    await t.pump(const Duration(seconds: 2));
    m.begin();
    await t.pump(const Duration(seconds: 1));
    expect(m.failure, 'timeout');
    m.dispose();
  });
  test('late content result cannot erase a main-frame error', () {
    final m = WebLoadMonitor();
    m.begin();
    final old = m.generation;
    m.fail('http');
    expect(m.complete(old, hasContent: true), isFalse);
    m.begin(restart: true);
    expect(m.complete(old, hasContent: true), isFalse);
    expect(m.complete(m.generation, hasContent: true), isTrue);
    m.dispose();
  });
  test('new web diagnostic fields reject arbitrary sensitive categories', () {
    final d = Diagnostics();
    d.record('web_resource_error', code: -999, category: 'password=secret');
    d.record('web_http_error', status: 503, category: 'main_frame');
    final json = d.export(session: 'unknown', counts: {});
    expect(json, isNot(contains('secret')));
    expect(json, contains('-999'));
    expect(json, contains('503'));
    expect(json, contains('main_frame'));
  });
}
