import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planthead_fanta/data/fanta_store.dart';
import 'package:planthead_fanta/data/models.dart';
import 'package:planthead_fanta/ui/native_home.dart';

// Synthetic public test fixture only, never imported by production code.
FantaStore fixture() {
  final s = FantaStore();
  s.accept(
    PageSnapshot.fromJson({
      'schema': 'ph-dom/1',
      'scope': 'reference',
      'contextLabel': 'Test League · synthetic fixture',
      'session': 'league_page',
      'ownTeam': 'Test Beta',
      'ranking': [
        {
          'name': 'Test Alpha',
          'owner': 'Test Owner A',
          'rank': 1,
          'points': 17,
          'played': 5,
          'total': 401,
        },
        {
          'name': 'Test Beta',
          'owner': 'Test Owner B',
          'rank': 2,
          'points': 12,
          'played': 5,
          'total': 399,
        },
      ],
      'matches': [
        {
          'home': 'Test Beta',
          'away': 'Test Gamma',
          'homeScore': 3,
          'awayScore': 1,
          'round': 5,
        },
        {'home': 'Test Delta', 'away': 'Test Beta', 'round': 6},
      ],
    }),
  );
  return s;
}

Widget app(FantaStore s, {double scale = 1, Key? boundary}) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff285bd7)),
    scaffoldBackgroundColor: const Color(0xffeff3fb),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff285bd7),
      foregroundColor: Colors.white,
    ),
  ),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(
      key: boundary,
      child: NativeHome(
        store: s,
        webBuilder: (s, onReturn) => Scaffold(
          appBar: AppBar(
            title: const Text('Operazione web'),
            actions: [
              IconButton(onPressed: onReturn, icon: const Icon(Icons.apps)),
            ],
          ),
          body: const Text('Contenuto web di test'),
        ),
      ),
    ),
  ),
);
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    );
    final rootUri =
        config['packages'].firstWhere((p) => p['name'] == 'flutter')['rootUri']
            as String;
    final root = Directory.fromUri(
      File('.dart_tool/package_config.json').absolute.uri.resolve(rootUri),
    ).parent.parent.path;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              '$root/bin/cache/artifacts/material_fonts/${entry.value}',
            ).readAsBytes(),
          ),
        ),
      );
      await loader.load();
    }
  });
  testWidgets(
    'native pages show snapshot data and exactly one visible navigation bar',
    (tester) async {
      phone(tester);
      final s = fixture();
      await tester.pumpWidget(app(s));
      await tester.pumpAndSettle();
      expect(find.text('LA MIA SQUADRA'), findsOneWidget);
      expect(find.text('Contenuto web di test'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Classifica'));
      await tester.pumpAndSettle();
      expect(find.text('Test Alpha'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.text('3 – 1'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      await tester.tap(find.text('Squadre'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Test Beta');
      await tester.pump();
      expect(find.text('Test Alpha'), findsNothing);
      await tester.tap(find.byTooltip('Lega e accesso'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Operazione web'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 1.3]) {
    testWidgets('phone visual capture at text scale $scale', (tester) async {
      phone(tester);
      final s = fixture();
      final boundary = GlobalKey();
      await tester.pumpWidget(app(s, scale: scale, boundary: boundary));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('docs/qa/native-dashboard-$scale.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes!.buffer.asUint8List());
      });
      if (scale == 1.0) {
        for (final label in ['Classifica', 'Calendario', 'Squadre']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'docs/qa/native-$label.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
      }
    });
  }
  testWidgets('release without session has no fabricated points', (
    tester,
  ) async {
    phone(tester);
    final s = FantaStore();
    await tester.pumpWidget(app(s));
    await tester.pumpAndSettle();
    expect(find.text('La tua squadra'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('Test Beta'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
