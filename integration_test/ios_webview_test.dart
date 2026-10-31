import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/ui/native_home.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'trace existing login link and verify home-dialog recovery in WKWebView',
    (tester) async {
      final store = FantaStore();
      final result = <String, dynamic>{};
      binding.reportData = result;
      Future<void> waitFor(bool Function() ready, [int seconds = 50]) async {
        for (var i = 0; i < seconds && !ready(); i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }

      Future<Map<String, dynamic>> probe() async {
        final raw = await store.controller?.evaluateJavascript(
          source: r'''
        JSON.stringify((() => { const p=document.querySelector('input[type="password"]');
          const r=p?.getBoundingClientRect(); return {
            officialOrigin:location.origin==='https://leghe.fantacalcio.it',
            passwordVisible:!!r && r.width>0 && r.height>0,
            ready:document.readyState==='complete'}; })())
      ''',
        );
        return raw is String
            ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
            : {};
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
        result['initialDocument'] = await probe();
        // Follow only the /login anchor actually supplied by the current home.
        // This opens no account and never submits the login form.
        final followed = await store.controller?.evaluateJavascript(
          source: r'''
        (()=>{const a=Array.from(document.querySelectorAll('a[href]')).find(e=>{
          const u=new URL(e.href,location.href);return u.origin===location.origin && u.pathname==='/login';});
          if(!a)return false;a.click();return true;})()
      ''',
        );
        result['existingLoginAnchorFollowed'] = followed == true;
        if (followed == true) {
          await waitFor(
            () =>
                store.diagnostics.entries.any(
                  (e) => e['event'] == 'web_main_404',
                ) ||
                find
                    .text('Pagina non trovata · HTTP 404')
                    .evaluate()
                    .isNotEmpty,
            20,
          );
        }
        result['main404Reproduced'] = store.diagnostics.entries.any(
          (e) => e['event'] == 'web_main_404',
        );
        await binding.takeScreenshot('iOS-1.1.2-login-link-result');
        // User-visible recovery invokes the existing modal trigger, not a guessed route.
        await tester.tap(find.byTooltip('Menu PlantHead'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
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
        result['recoveredDocument'] = await probe();
        result['accessVisibleEvent'] = store.diagnostics.entries.any(
          (e) => e['event'] == 'web_access_visible',
        );
        result['flutterErrorVisible'] =
            find.text('Pagina non trovata · HTTP 404').evaluate().isNotEmpty ||
            find.text('Riprendiamo da qui').evaluate().isNotEmpty;
        await binding.takeScreenshot('iOS-1.1.2-home-login-recovery');
        final controller = store.controller;
        await tester.tap(find.byTooltip('Torna all’app nativa'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.tap(find.byTooltip('Lega e accesso'));
        await tester.pump(const Duration(seconds: 2));
        result['controllerPreserved'] = identical(controller, store.controller);
        await binding.takeScreenshot('iOS-1.1.2-reopened-access');
        final doc = result['recoveredDocument'] as Map;
        expect(doc['officialOrigin'], true);
        expect(doc['passwordVisible'], true);
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
        store.dispose();
      }
    },
  );
}
