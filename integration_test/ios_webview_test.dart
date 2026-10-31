import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planthead_fanta/core/navigation_policy.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/ui/native_home.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'reproduce TLS cancellation, then render official login in real WKWebView',
    (tester) async {
      final result = <String, dynamic>{};
      binding.reportData = result;
      // Controlled reproduction of the exact 1.1.0 server-trust callback.
      // Test only; no certificate override exists in the shipping application.
      int? baselineError;
      var baselineCreated = false;
      var cancelledTrust = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri.uri(NavigationPolicy.home),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                sharedCookiesEnabled: true,
              ),
              onWebViewCreated: (_) => baselineCreated = true,
              onReceivedServerTrustAuthRequest: (_, challenge) async {
                cancelledTrust = true;
                return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.CANCEL,
                );
              },
              onReceivedError: (_, request, error) {
                if (request.isForMainFrame == true) {
                  baselineError = error.type.toNativeValue();
                }
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 25 && baselineError == null; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      result['baseline'] = {
        'created': baselineCreated,
        'trustCancelled': cancelledTrust,
        'mainErrorCode': baselineError,
      };
      await binding.takeScreenshot('iOS-1.1.0-tls-control');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      final store = FantaStore();
      await tester.pumpWidget(MaterialApp(home: NativeHome(store: store)));
      await tester.pump(const Duration(seconds: 1));
      // Lazy mount: there must be no platform view until the user opens access.
      result['lazyBeforeOpen'] = store.controller == null;
      await tester.tap(find.byTooltip('Lega e accesso'));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (store.diagnostics.entries.any(
          (e) => e['event'] == 'web_dom_ready',
        )) {
          break;
        }
        if (store.diagnostics.entries.any((e) => e['event'] == 'web_timeout')) {
          break;
        }
      }
      final c = store.controller;
      final raw = await c?.evaluateJavascript(
        source: r'''
      JSON.stringify((() => { const b=document.body;
        const p=document.querySelector('input[type="password"]');
        const r=p?.getBoundingClientRect();
        return {officialOrigin:location.origin==='https://leghe.fantacalcio.it',
          ready:document.readyState==='complete',
          nonEmpty:!!b && !!b.innerText.trim(),
          passwordFieldVisible:!!r && r.width>0 && r.height>0,
          viewportWidth:innerWidth, viewportHeight:innerHeight}; })())
    ''',
      );
      result['document'] = raw is String ? jsonDecode(raw) : raw;
      result['diagnostics'] = jsonDecode(
        store.diagnostics.export(session: store.session, counts: store.counts),
      );
      await binding.takeScreenshot('iOS-1.1.1-official-login');
      // Hide and reopen the same platform view: no session-destroying recreation.
      final originalController = store.controller;
      await tester.tap(find.byTooltip('Torna all’app nativa'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.byTooltip('Lega e accesso'));
      await tester.pump(const Duration(seconds: 2));
      result['controllerPreserved'] = identical(
        originalController,
        store.controller,
      );
      await binding.takeScreenshot('iOS-1.1.1-reopened-login');
      final doc = result['document'] as Map?;
      expect(result['lazyBeforeOpen'], true);
      expect(result['controllerPreserved'], true);
      expect(doc?['officialOrigin'], true);
      expect(doc?['nonEmpty'], true);
      expect(doc?['passwordFieldVisible'], true);
      expect(
        store.diagnostics.entries.any((e) => e['event'] == 'web_dom_ready'),
        true,
      );
      expect(find.byType(NavigationBar), findsNothing);
      // No credential entry, login click, cookie read or account access.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      store.dispose();
    },
  );
}
