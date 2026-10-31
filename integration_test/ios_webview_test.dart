import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/ui/native_home.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'verify official login modal without navigating to login route in WKWebView',
    (tester) async {
      final store = FantaStore();
      final result = <String, dynamic>{};
      binding.reportData = result;
      void phase(String value) => debugPrint('PH112_PHASE:$value');
      void eventListener() {
        if (store.diagnostics.entries.isNotEmpty) {
          debugPrint(
            'PH112_EVENT_JSON:${jsonEncode(store.diagnostics.entries.last)}',
          );
        }
      }

      store.diagnostics.addListener(eventListener);
      phase('started');
      Future<void> waitFor(bool Function() ready, [int seconds = 50]) async {
        for (var i = 0; i < seconds && !ready(); i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }

      Future<Map<String, dynamic>> probe() async {
        try {
          final raw = await store.controller
              ?.evaluateJavascript(
                source: r'''
        JSON.stringify((() => { const p=document.querySelector('input[type="password"]');
          const r=p?.getBoundingClientRect(); return {
            officialOrigin:location.origin==='https://leghe.fantacalcio.it',
            passwordVisible:!!r && r.width>0 && r.height>0,
            passwordEnabled:!!p && !p.disabled && !p.readOnly,
            usernamePresent:!!p?.closest('form')?.querySelector('input[autocomplete="username"],input[name="username"]'),
            ready:document.readyState==='complete'}; })())
      ''',
              )
              .timeout(const Duration(seconds: 8));
          return raw is String
              ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
              : {};
        } on TimeoutException {
          return {'probeTimedOut': true};
        } catch (_) {
          return {'probeFailed': true};
        }
      }

      try {
        await tester.pumpWidget(MaterialApp(home: NativeHome(store: store)));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byTooltip('Lega e accesso'));
        await tester.pump();
        await waitFor(
          () => store.diagnostics.entries.any(
            (e) => e['event'] == 'web_dom_ready' || e['event'] == 'web_timeout',
          ),
        );
        phase('probing_initial_document');
        result['initialDocument'] = await probe();
        phase('initial_document_probed');
        // Exercise the supported modal only. Never click the known failing anchor.
        result['existingLoginAnchorFollowed'] = false;
        // User-visible recovery invokes the existing modal trigger, not a guessed route.
        phase('recovery_started');
        final recoveryStart = store.diagnostics.entries.length;
        await tester.tap(find.byTooltip('Menu PlantHead'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Accesso dalla home ufficiale'));
        await tester.pump();
        await waitFor(
          () => store.diagnostics.entries.any(
            (e) =>
                e['event'] == 'web_access_visible' ||
                e['event'] == 'web_access_unavailable',
          ),
          55,
        );
        phase('probing_recovery_document');
        result['recoveredDocument'] = await probe();
        phase('recovery_document_probed');
        result['recoveryHomeCommands'] = store.diagnostics.entries
            .skip(recoveryStart)
            .where(
              (e) =>
                  e['event'] == 'web_app_command' && e['cause'] == 'app_home',
            )
            .length;
        result['accessVisibleEvent'] = store.diagnostics.entries.any(
          (e) => e['event'] == 'web_access_visible',
        );
        result['flutterErrorVisible'] =
            find.text('Pagina non trovata · HTTP 404').evaluate().isNotEmpty ||
            find.text('Riprendiamo da qui').evaluate().isNotEmpty;
        await binding.takeScreenshot('iOS-1.1.3-home-login-recovery');
        final controller = store.controller;
        await tester.tap(find.byTooltip('Torna all’app nativa'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.tap(find.byTooltip('Lega e accesso'));
        await tester.pump(const Duration(seconds: 2));
        result['controllerPreserved'] = identical(controller, store.controller);
        await binding.takeScreenshot('iOS-1.1.3-reopened-access');
        result['unexpectedLoginNavigation'] = store.diagnostics.entries.any(
          (e) => e['event'] == 'web_request' && e['route'] == 'official_login',
        );
        final doc = result['recoveredDocument'] as Map;
        expect(result['unexpectedLoginNavigation'], false);
        expect(result['recoveryHomeCommands'] as int, lessThanOrEqualTo(1));
        expect(doc['officialOrigin'], true);
        expect(doc['passwordVisible'], true);
        expect(doc['passwordEnabled'], true);
        expect(doc['usernamePresent'], true);
        expect(result['accessVisibleEvent'], true);
        expect(result['flutterErrorVisible'], false);
        expect(result['controllerPreserved'], true);
        expect(find.byType(NavigationBar), findsNothing);
      } finally {
        // Always retain only the allowlisted diagnostic data, also on assertion failure.
        result['diagnostics'] = jsonDecode(
          store.diagnostics.export(
            session: store.session,
            counts: store.counts,
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        phase('finished');
        store.diagnostics.removeListener(eventListener);
        store.dispose();
      }
    },
  );
}
