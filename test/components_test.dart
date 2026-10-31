import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/ui/components.dart';

void main() {
  testWidgets(
    'all five destinations are accessible and dispatch intended tab',
    (tester) async {
      var destination = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FantaNavigation(
              selected: 0,
              available: const {
                'dashboard',
                'rose',
                'calendario',
                'classifica',
              },
              onSelected: (value) => destination = value,
            ),
          ),
        ),
      );
      for (final label in [
        'Dashboard',
        'Rose',
        'Calendario',
        'Classifica',
        'Menu',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Calendario'));
      expect(destination, 2);
      await tester.tap(find.text('Menu'));
      expect(destination, 4);
    },
  );
  testWidgets(
    'unavailable sections cannot navigate before the league is open',
    (tester) async {
      var destination = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FantaNavigation(
              selected: 0,
              available: const {},
              onSelected: (value) => destination = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rose'));
      expect(destination, -1);
      await tester.tap(find.text('Menu'));
      expect(destination, 4);
    },
  );
  testWidgets(
    'network error presents working recovery actions at large text scale',
    (tester) async {
      var retries = 0;
      var home = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: LoadFailurePanel(
                message: 'Connessione non disponibile',
                onRetry: () => retries++,
                onHome: () => home++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Riprova'));
      await tester.ensureVisible(find.text('Vai alla pagina iniziale'));
      await tester.tap(find.text('Vai alla pagina iniziale'));
      expect(retries, 1);
      expect(home, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
