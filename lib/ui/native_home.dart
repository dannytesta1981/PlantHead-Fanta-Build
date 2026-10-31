import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/navigation_policy.dart';
import '../data/fanta_store.dart';
import '../data/models.dart';
import 'fanta_home.dart';
import 'native_parts.dart';

class NativeHome extends StatefulWidget {
  const NativeHome({super.key, this.store, this.webBuilder});
  final FantaStore? store;
  final Widget Function(FantaStore, VoidCallback)? webBuilder;
  @override
  State<NativeHome> createState() => _NativeHomeState();
}

class _NativeHomeState extends State<NativeHome> {
  late final FantaStore store;
  late final Widget webPage;
  final webKey = GlobalKey<OfficialWebPageState>();
  final scaffold = GlobalKey<ScaffoldState>();
  int selected = 0;
  bool webVisible = false;
  bool webMounted = false;
  String search = '';
  int? round;
  static const tabs = ['Dashboard', 'Squadre', 'Calendario', 'Classifica'];
  @override
  void initState() {
    super.initState();
    store = widget.store ?? FantaStore();
    webPage =
        widget.webBuilder?.call(store, returnNative) ??
        OfficialWebPage(key: webKey, store: store, onReturn: returnNative);
  }

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  void returnNative() {
    if (!mounted) return;
    setState(() => webVisible = false);
    store.diagnostics.record('native_open');
    unawaited(store.capture());
  }

  Future<void> openWeb([String? section]) async {
    setState(() {
      webMounted = true;
      webVisible = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    store.diagnostics.record('web_open', section: section ?? 'web');
    if (section != null && !await store.navigate(section)) {
      await store.navigate('menu');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usa il menu del sito per aprire la funzione.'),
          ),
        );
      }
    }
  }

  Future<void> refresh() async {
    if (selected == 0) {
      await store.capture();
      return;
    }
    final key = ['dashboard', 'rose', 'calendario', 'classifica'][selected];
    if (!await store.navigate(key)) {
      await store.capture();
    }
  }

  void select(int index) {
    if (index == 4) {
      scaffold.currentState?.openDrawer();
      return;
    }
    setState(() => selected = index);
    // Only known read-only page controls are activated; no fabricated URLs.
    unawaited(refresh());
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !webVisible,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || !webVisible) return;
      if (await store.controller?.canGoBack() ?? false) {
        await store.controller?.goBack();
      } else {
        returnNative();
      }
    },
    child: IndexedStack(
      index: webVisible ? 1 : 0,
      children: [
        AnimatedBuilder(
          animation: store,
          builder: (context, _) => Scaffold(
            key: scaffold,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PlantHead Fanta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    store.contextLabel.isEmpty
                        ? tabs[selected]
                        : store.contextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xffdce6ff),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Lega e accesso',
                  onPressed: () => openWeb(),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                IconButton(
                  tooltip: 'Aggiorna dati',
                  onPressed: refresh,
                  icon: const Icon(Icons.sync_rounded),
                ),
              ],
            ),
            drawer: _drawer(),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (store.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          store.session == 'league_page'
                              ? Icons.verified_user_outlined
                              : Icons.link_rounded,
                          size: 16,
                          color: const Color(0xff285bd7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            store.updatedAt == null
                                ? 'Collega la tua lega per leggere i dati'
                                : 'Ultima lettura ${_time(store.updatedAt!)} · dati della pagina',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff53647c),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => openWeb(),
                          child: Text(
                            store.session == 'league_page' ? 'Lega' : 'Accedi',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        key: PageStorageKey(selected),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          if (store.issue != null)
                            NoticeCard(
                              text: store.issue!,
                              onOpen: () => openWeb(),
                            ),
                          if (selected == 0) ..._dashboard(),
                          if (selected == 1) ..._teams(),
                          if (selected == 2) ..._calendar(),
                          if (selected == 3) ..._ranking(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.1,
              child: NavigationBarTheme(
                data: const NavigationBarThemeData(
                  labelTextStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 11),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: select,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.checkroom_outlined),
                      selectedIcon: Icon(Icons.checkroom_rounded),
                      label: 'Squadre',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Calendario',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.emoji_events_outlined),
                      label: 'Classifica',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_rounded),
                      label: 'Menu',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        webMounted
            ? (widget.webBuilder != null
                  ? webPage
                  : OfficialWebPage(
                      key: webKey,
                      store: store,
                      onReturn: returnNative,
                      visible: webVisible,
                    ))
            : const SizedBox.shrink(),
      ],
    ),
  );
  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  List<Widget> _dashboard() => [
    TeamHero(team: store.myTeam, shirt: store.shirt, onChoose: _chooseTeam),
    const SizedBox(height: 22),
    const SectionTitle(
      'Prossima partita',
      subtitle: 'Il prossimo impegno della tua squadra',
    ),
    if (store.next != null)
      MatchCard(match: store.next!, highlight: store.chosenTeam)
    else
      EmptySection(
        icon: Icons.calendar_today_outlined,
        title: 'Prossima partita da leggere',
        message:
            'Apri Calendario sul sito e torna all’app. I risultati riconosciuti verranno mostrati qui.',
        onOpen: () => openWeb('calendario'),
      ),
    const SizedBox(height: 20),
    const SectionTitle('Ultimo risultato'),
    if (store.previous != null)
      MatchCard(match: store.previous!, highlight: store.chosenTeam)
    else
      EmptySection(
        icon: Icons.sports_soccer_rounded,
        title: 'Nessun risultato letto',
        message: 'Non vengono ricostruiti risultati o punteggi mancanti.',
        onOpen: () => openWeb('calendario'),
      ),
    const SizedBox(height: 20),
    const SectionTitle('La tua lega'),
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ActionChip(
          avatar: const Icon(Icons.sports_soccer_rounded, size: 17),
          label: const Text('Formazione · web'),
          onPressed: () => openWeb('formazione'),
        ),
        ActionChip(
          avatar: const Icon(Icons.shopping_cart_outlined, size: 17),
          label: const Text('Mercato · web'),
          onPressed: () => openWeb('mercato'),
        ),
      ],
    ),
  ];
  List<Widget> _ranking() => [
    const SectionTitle(
      'Classifica',
      subtitle: 'Punti e posizione letti dalla pagina ufficiale',
    ),
    if (store.ranking.isEmpty)
      EmptySection(
        icon: Icons.emoji_events_outlined,
        title: 'Classifica non ancora letta',
        message:
            'Apri la classifica della lega e torna all’app. L’adattatore accetta soltanto colonne riconosciute.',
        onOpen: () => openWeb('classifica'),
      ),
    for (final team in store.ranking)
      StandingTile(
        team: team,
        selected: team.name == store.chosenTeam,
        onTap: () => store.selectTeam(team.name),
      ),
    if (store.ranking.isNotEmpty)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Tocca la tua squadra per usarla nella dashboard.',
          style: TextStyle(fontSize: 12, color: Color(0xff61738b)),
        ),
      ),
  ];
  List<Widget> _calendar() {
    final rounds =
        store.matches.map((m) => m.round).whereType<int>().toSet().toList()
          ..sort();
    final filtered = store.matches.where(
      (m) => round == null || m.round == round,
    );
    return [
      const SectionTitle(
        'Calendario',
        subtitle: 'Partite e giornate della competizione',
      ),
      if (rounds.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Tutte'),
                selected: round == null,
                onSelected: (_) => setState(() => round = null),
              ),
              for (final r in rounds)
                ChoiceChip(
                  label: Text('$rª'),
                  selected: round == r,
                  onSelected: (_) => setState(() => round = r),
                ),
            ],
          ),
        ),
      if (store.matches.isEmpty)
        EmptySection(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario non ancora letto',
          message:
              'Le partite appariranno quando la pagina espone una struttura riconoscibile. Nessuna giornata è simulata.',
          onOpen: () => openWeb('calendario'),
        ),
      for (final match in filtered)
        MatchCard(match: match, highlight: store.chosenTeam),
    ];
  }

  List<Widget> _teams() => [
    const SectionTitle(
      'Squadre e rose',
      subtitle: 'Le persone e le squadre della tua lega',
    ),
    TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded),
        hintText: 'Cerca squadra',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (v) => setState(() => search = v),
    ),
    const SizedBox(height: 16),
    if (store.allTeams.isEmpty)
      EmptySection(
        icon: Icons.checkroom_rounded,
        title: 'Squadre non ancora lette',
        message:
            'Apri Rose o Classifica dal sito. Solo le squadre effettivamente lette compariranno in questo elenco.',
        onOpen: () => openWeb('rose'),
      ),
    for (final t in store.allTeams.where(
      (t) => t.name.toLowerCase().contains(search.toLowerCase()),
    ))
      TeamTile(
        team: t,
        selected: t.name == store.chosenTeam,
        onTap: () => _roster(t),
      ),
  ];
  void _chooseTeam() {
    if (store.allTeams.isEmpty) {
      unawaited(openWeb('classifica'));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Scegli la tua squadra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final t in store.allTeams)
                      TeamTile(
                        team: t,
                        selected: t.name == store.chosenTeam,
                        onTap: () {
                          store.selectTeam(t.name);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _roster(TeamData team) {
    final known = store.rosterTeam == team.name && store.players.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TeamTile(
                team: team,
                selected: team.name == store.chosenTeam,
                onTap: () {
                  store.selectTeam(team.name);
                  Navigator.pop(context);
                },
              ),
              const SectionTitle('Rosa'),
              if (known)
                for (final player in store.players) PlayerTile(player: player),
              if (!known)
                EmptySection(
                  icon: Icons.groups_outlined,
                  title: 'Rosa non ancora associata',
                  message:
                      'Apri la rosa sul sito. Il collegamento tra giocatori e squadra deve essere riconosciuto prima della visualizzazione nativa.',
                  onOpen: () {
                    Navigator.pop(context);
                    unawaited(openWeb('rose'));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawer() => Drawer(
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff285bd7), Color(0xff122865)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xffffd65a),
                  size: 36,
                ),
                SizedBox(height: 12),
                Text(
                  'PlantHead Fanta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '1.1 · Il tuo spazio di gioco',
                  style: TextStyle(color: Color(0xffdce6ff)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Lega, competizione e accesso'),
            onTap: () {
              Navigator.pop(context);
              unawaited(openWeb());
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'FUNZIONI DELLA LEGA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          for (final entry in sectionLabels.entries.where(
            (e) => ![
              'dashboard',
              'rose',
              'calendario',
              'classifica',
              'menu',
              'logout',
            ].contains(e.key),
          ))
            ListTile(
              title: Text(entry.value.first),
              trailing: const Text(
                'WEB',
                style: TextStyle(fontSize: 10, color: Color(0xff64748b)),
              ),
              onTap: () {
                Navigator.pop(context);
                unawaited(openWeb(entry.key));
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Diagnostica'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiagnosticsPage(store: store),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Disconnetti dispositivo'),
            onTap: () {
              Navigator.pop(context);
              unawaited(webKey.currentState?.disconnect());
            },
          ),
        ],
      ),
    ),
  );
}

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, required this.store});
  final FantaStore store;
  Future<void> _export(BuildContext context) async {
    try {
      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/planthead-fanta-diagnostica.json');
      await file.writeAsString(store.diagnosticJson());
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esportazione non riuscita. Riprova.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diagnostica')),
    body: AnimatedBuilder(
      animation: Listenable.merge([store, store.diagnostics]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Verifica sul dispositivo',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Il report contiene stato della pagina, conteggi ed eventi tecnici. Non include cookie, password, token, URL, HTML, nomi o dati della lega.',
          ),
          const SizedBox(height: 20),
          Text('Sessione osservata: ${store.session}'),
          for (final c in store.counts.entries)
            ListTile(
              dense: true,
              title: Text(c.key),
              trailing: Text('${c.value}'),
            ),
          FilledButton.icon(
            onPressed: () => _export(context),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Esporta diagnostica'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Adattatore DOM ph-dom/1 · integrazione da verificare sul sito autenticato',
            style: TextStyle(color: Color(0xff61738b)),
          ),
          const Divider(),
          for (final e in store.diagnostics.entries.reversed)
            ListTile(
              dense: true,
              title: Text('${e['event']}'),
              subtitle: Text('${e['section']} · ${e['at']}'),
            ),
        ],
      ),
    ),
  );
}
