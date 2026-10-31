import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/download_service.dart';
import '../core/web_load_monitor.dart';
import '../core/navigation_policy.dart';
import 'components.dart';
import '../data/fanta_store.dart';
import '../data/diagnostics.dart';

class OfficialWebPage extends StatefulWidget {
  const OfficialWebPage({
    super.key,
    required this.store,
    required this.onReturn,
    this.visible = true,
  });
  final FantaStore store;
  final VoidCallback onReturn;
  final bool visible;
  @override
  State<OfficialWebPage> createState() => OfficialWebPageState();
}

class OfficialWebPageState extends State<OfficialWebPage>
    with WidgetsBindingObserver {
  Future<void> disconnect() => _resetSession();
  InAppWebViewController? _web;
  PullToRefreshController? _refresh;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _downloads = DownloadService();
  Timer? _scanTimer;
  final _load = WebLoadMonitor();
  bool _loadStopped = false;
  bool _probing = false;
  String? _script;
  Set<String> _available = {};
  Uri? _uri = NavigationPolicy.home;
  String? _error;
  String _title = 'Il tuo fantacalcio, sempre con te';
  int _progress = 0;
  int _webGeneration = 0;
  bool _canBack = false;
  bool _ready = false;

  bool _intro = true;
  bool _downloading = false;
  bool _scanning = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load.onTimeout = () {
      widget.store.diagnostics.record(
        'web_timeout',
        category: _web == null ? 'creation' : 'document',
      );
      widget.store.networkError();
      unawaited(_refresh?.endRefreshing());
    };
    _load.addListener(_loadChanged);
    widget.store.diagnostics.record('web_visible');
    unawaited(_prepare());
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_scan());
      if (_loadStopped && _load.busy) unawaited(_verifyDocument());
    });
  }

  Future<void> _prepare() async {
    _load.begin(restart: true);
    try {
      _script = await rootBundle.loadString('assets/navigation.js');
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _intro = !(prefs.getBool('introDismissed') ?? false);
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      // A preference-store failure must not prevent access to the official site.
      setState(() {
        _ready = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _scanTimer?.cancel();
    widget.store.diagnostics.record(
      state == AppLifecycleState.resumed ? 'resumed' : 'web_paused',
    );
    if (state == AppLifecycleState.resumed) {
      _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_scan());
        if (_loadStopped && _load.busy) unawaited(_verifyDocument());
      });
      unawaited(_scan());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _load.removeListener(_loadChanged);
    _load.dispose();
    if (identical(widget.store.controller, _web)) {
      widget.store.controller = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OfficialWebPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      widget.store.diagnostics.record(
        widget.visible ? 'web_visible' : 'web_hidden',
      );
      if (widget.visible && _loadStopped && _load.busy) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _verifyDocument());
      }
    }
  }

  void _loadChanged() {
    if (!mounted) return;
    setState(() {
      _progress = _load.progress;
      _error = switch (_load.failure) {
        null => null,
        'timeout' =>
          'Caricamento non completato entro 35 secondi. Controlla la rete e premi Riprova.',
        'webkit' =>
          'Il contenuto web è stato interrotto da iOS. Premi Riprova per ricrearlo.',
        'http' => 'Il sito ha restituito un errore. Attendi e premi Riprova.',
        _ =>
          'Impossibile caricare il sito ufficiale. Controlla la connessione e premi Riprova.',
      };
    });
  }

  Future<void> _verifyDocument() async {
    final c = _web;
    if (c == null || _probing || !_load.busy || !_loadStopped) return;
    _probing = true;
    final generation = _load.generation;
    try {
      // Read only: no input values, text or URLs leave WKWebView.
      final visible = await c.evaluateJavascript(
        source: r"""
        (() => {const b=document.body;
          if(!b || document.readyState==='loading') return false;
          const r=b.getBoundingClientRect();
          return r.width>0 && r.height>0 &&
            (!!b.innerText.trim() || !!b.querySelector('input,button,img,canvas,video,iframe'));
        })()
      """,
      );
      if (!mounted || c != _web || generation != _load.generation) return;
      final ok = visible == true;
      widget.store.diagnostics.record(ok ? 'web_dom_ready' : 'web_dom_empty');
      if (_load.complete(generation, hasContent: ok)) {
        widget.store.pageFinished();
        await _refresh?.endRefreshing();
        await _scan();
      }
    } catch (_) {
      widget.store.diagnostics.record('web_probe_error');
    } finally {
      _probing = false;
    }
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _notice('Nessuna app disponibile per aprire il collegamento.');
      }
    } catch (_) {
      _notice('Impossibile aprire il collegamento.');
    }
  }

  Future<NavigationActionPolicy> _navigate(NavigationAction action) async {
    // Never redirect ad, consent, captcha or other subframes into external apps.
    if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
    final uri = Uri.tryParse(action.request.url?.toString() ?? '');
    switch (NavigationPolicy.classify(uri)) {
      case LinkAction.web:
        widget.store.diagnostics.record('web_navigation_allow');
        return NavigationActionPolicy.ALLOW;
      case LinkAction.external:
        widget.store.diagnostics.record('web_navigation_external');
        if (uri != null) await _openExternal(uri);
        return NavigationActionPolicy.CANCEL;
      case LinkAction.block:
        widget.store.diagnostics.record('web_navigation_block');
        _notice(
          'Collegamento non supportato. Usa il sito originale per continuare.',
        );
        return NavigationActionPolicy.CANCEL;
    }
  }

  Future<void> _scan() async {
    if (_scanning || _resetting || _web == null || _script == null) return;
    _scanning = true;
    try {
      final controller = _web!;
      final actual = Uri.tryParse(
        (await controller.getUrl())?.toString() ?? '',
      );
      final back = await controller.canGoBack();
      if (!mounted || controller != _web) return;
      if (!NavigationPolicy.isOfficial(actual)) {
        setState(() {
          _available = {};
          _uri = actual;
          _canBack = back;
        });
        return;
      }
      await controller.evaluateJavascript(source: _script!);
      final value = await controller.evaluateJavascript(
        source:
            'JSON.stringify(window.__phNavigation?.scan(${jsonEncode(sectionLabels)}, ${false}) || {})',
      );
      if (!mounted || controller != _web) return;
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is! Map) return;
      final keys = (decoded['available'] as List? ?? [])
          .whereType<String>()
          .toSet();
      setState(() {
        _available = keys.intersection(sectionLabels.keys.toSet());
        widget.store.available = _available;
        _uri = actual;
        _canBack = back;
      });
    } catch (_) {
      // Site structure may change. The complete web UI remains the fallback.
    } finally {
      _scanning = false;
      unawaited(widget.store.capture());
    }
  }

  Future<bool> _click(String key) async {
    try {
      final controller = _web;
      if (controller == null) return false;
      final actual = Uri.tryParse(
        (await controller.getUrl())?.toString() ?? '',
      );
      if (!NavigationPolicy.isOfficial(actual)) return false;
      await controller.evaluateJavascript(source: _script!);
      final result = await controller.evaluateJavascript(
        source:
            'window.__phNavigation?.click(${jsonEncode(sectionLabels[key] ?? [])}) === true',
      );
      unawaited(_scan());
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showOriginal() async {
    if (!mounted) return;
    await _scan();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('originalSite', true);
  }

  Future<void> _reload() async {
    widget.store.diagnostics.record('web_retry');
    // Recreate only failed/uncreated views. Keep the persistent website store;
    // never delete cookies or modify the official authentication flow.
    final recreate = _web == null || _load.failure != null;
    _loadStopped = false;
    _load.begin(restart: true);
    if (recreate) {
      widget.store.controller = null;
      setState(() {
        _web = null;
        _webGeneration++;
        _ready = true;
      });
    } else {
      try {
        await _web!.reload();
      } catch (_) {
        _fail('network');
      }
    }
  }

  Future<void> _home() async {
    if (_web == null || _load.failure != null) {
      await _reload();
      return;
    }
    _loadStopped = false;
    _load.begin(restart: true);
    try {
      await _web!.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(NavigationPolicy.home)),
      );
    } catch (_) {
      _fail('network');
    }
  }

  void _started() {
    _loadStopped = false;
    widget.store.pageStarted();
    _load.begin();
    setState(() {
      _available = {};
    });
  }

  Future<void> _finished() async {
    widget.store.diagnostics.record('web_load_stop');
    _loadStopped = true;
    // A cancelled TLS handshake or an empty document is not a loaded page.
    await _verifyDocument();
  }

  void _fail(String category) {
    widget.store.networkError();
    _load.fail(category);
    unawaited(_refresh?.endRefreshing());
  }

  Future<void> _download(DownloadStartRequest request) async {
    if (_downloading) {
      _notice('Un download è già in corso.');
      return;
    }
    final uri = Uri.tryParse(request.url.toString());
    if (!NavigationPolicy.isOfficial(uri)) {
      _notice(
        'Questo download richiede il browser. La sessione del browser è separata.',
      );
      if (uri?.scheme == 'https') await _openExternal(uri!);
      return;
    }
    setState(() => _downloading = true);
    try {
      final file = await _downloads.download(uri!, request.suggestedFilename);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on DownloadException catch (e) {
      _notice(e.message);
    } catch (_) {
      _notice('Download non riuscito. Riprova dal sito o apri il browser.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnetti questo dispositivo?'),
        content: const Text(
          'Verranno rimossi cookie, dati web e file temporanei di PlantHead Fanta. Dovrai accedere di nuovo. Le altre sessioni non saranno revocate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _resetting = true;
    await _web?.stopLoading();
    // Destroy the WebView before deleting data so a live page cannot recreate it.
    setState(() {
      _ready = false;
      _web = null;
      _available = {};
      _error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    try {
      widget.store.clear();
      await CookieManager.instance().deleteAllCookies();
      if (Platform.isIOS) {
        await WebStorageManager.instance().removeDataModifiedSince(
          dataTypes: WebsiteDataType.ALL,
          date: DateTime.fromMillisecondsSinceEpoch(0),
        );
      } else {
        await WebStorageManager.instance().deleteAllData();
      }
      await InAppWebViewController.clearAllCache();
      await DownloadService.clearTemporaryFiles();
      if (!mounted) return;
      setState(() {
        _webGeneration++;
        _load.begin(restart: true);
        _ready = true;
        _uri = NavigationPolicy.home;
        _title = 'Accedi dal sito ufficiale';
        _canBack = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _ready = true);
        _notice(
          'Pulizia non completata. Riprova prima di condividere il dispositivo.',
        );
      }
    } finally {
      _resetting = false;
    }
  }

  Future<void> _popup(CreateWindowAction action) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _PopupPage(
          windowId: action.windowId,
          diagnostics: widget.store.diagnostics,
          navigate: _navigate,
          download: _download,
        ),
      ),
    );
    await _scan();
  }

  Widget _browser() {
    _refresh ??= PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xff285bd7)),
      onRefresh: _reload,
    );
    return InAppWebView(
      key: ValueKey(_webGeneration),
      initialUrlRequest: URLRequest(url: WebUri.uri(NavigationPolicy.home)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        incognito: false,
        sharedCookiesEnabled: true,
        thirdPartyCookiesEnabled: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: false,
        allowsBackForwardNavigationGestures: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: true,
        isInspectable: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([]),
      pullToRefreshController: _refresh,
      onWebViewCreated: (controller) {
        _web = controller;
        widget.store.attach(controller);
        widget.store.diagnostics.record('web_created');
      },
      shouldOverrideUrlLoading: (_, action) => _navigate(action),
      onLoadStart: (_, url) {
        if (mounted) {
          _uri = Uri.tryParse(url?.toString() ?? "");
          widget.store.diagnostics.record('web_load_start');
          _started();
        }
      },
      onLoadStop: (_, url) => _finished(),
      onProgressChanged: (_, value) {
        if (mounted) _load.updateProgress(value);
      },
      onTitleChanged: (_, title) {
        if (mounted) {
          setState(
            () => _title = title?.trim().isNotEmpty == true
                ? title!
                : 'PlantHead Fanta',
          );
        }
      },
      onUpdateVisitedHistory: (_, url, reload) {
        widget.store.diagnostics.record('web_history');
        unawaited(_scan());
      },
      onWebContentProcessDidTerminate: (_) {
        widget.store.diagnostics.record(
          'web_process_terminated',
          category: 'webkit',
        );
        _fail('webkit');
      },
      onReceivedError: (_, request, error) {
        final cancelled = error.type == WebResourceErrorType.CANCELLED;
        widget.store.diagnostics.record(
          'web_resource_error',
          code: error.type.toNativeValue(),
          category: cancelled
              ? 'cancelled'
              : request.isForMainFrame == true
              ? 'main_frame'
              : 'subframe',
        );
        if (request.isForMainFrame == true && !cancelled) _fail('network');
      },
      onReceivedHttpError: (_, request, response) {
        widget.store.diagnostics.record(
          'web_http_error',
          status: response.statusCode,
          category: request.isForMainFrame == true ? 'main_frame' : 'subframe',
        );
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 0) >= 400) {
          _fail('http');
        }
      },
      // No server-trust override: WKWebView performs normal system TLS validation.
      onPermissionRequest: (_, request) async => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      ),
      onGeolocationPermissionsShowPrompt: (_, origin) async =>
          GeolocationPermissionShowPromptResponse(
            origin: origin,
            allow: false,
            retain: false,
          ),
      onDownloadStartRequest: (_, request) => _download(request),
      onCreateWindow: (_, action) async {
        unawaited(_popup(action));
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffold,
    onEndDrawerChanged: (_) {
      if (mounted) setState(() {});
    },
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: _canBack ? 'Indietro' : 'Pagina iniziale',
        icon: Icon(
          _canBack ? Icons.arrow_back_rounded : Icons.sports_soccer_rounded,
        ),
        onPressed: () async {
          if (_canBack) {
            await _web?.goBack();
            await _scan();
          } else {
            await _home();
          }
        },
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PlantHead Fanta',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(
            NavigationPolicy.isOfficial(_uri)
                ? _title
                : (_uri?.host ?? 'Accesso'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xffdce6ff)),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Torna all’app nativa',
          onPressed: () {
            unawaited(widget.store.capture());
            widget.onReturn();
          },
          icon: const Icon(Icons.apps_rounded),
        ),
        IconButton(
          tooltip: 'Aggiorna pagina',
          onPressed: _ready ? _reload : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Menu PlantHead',
          onPressed: () => _scaffold.currentState?.openEndDrawer(),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: _load.busy && _ready
            ? LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100 : null,
                minHeight: 3,
                color: const Color(0xffffd45a),
                backgroundColor: Colors.white24,
              )
            : const SizedBox(height: 3),
      ),
    ),
    endDrawer: _menu(),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_intro)
            MaterialBanner(
              content: const Text(
                'Accedi dal sito ufficiale. Leghe, competizioni e dati restano quelli del tuo account.',
              ),
              leading: const Icon(Icons.lock_outline_rounded),
              actions: [
                TextButton(
                  onPressed: () async {
                    setState(() => _intro = false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('introDismissed', true);
                  },
                  child: const Text('Ho capito'),
                ),
              ],
            ),
          if (_downloading) const LinearProgressIndicator(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready)
                  _browser()
                else
                  const Center(child: CircularProgressIndicator()),
                if (_load.busy && _error == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Caricamento del sito ufficiale…'),
                            ),
                            TextButton(
                              onPressed: _reload,
                              child: const Text('Riprova'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Positioned.fill(
                    child: LoadFailurePanel(
                      message: _error!,
                      onRetry: _reload,
                      onHome: _home,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: null,
  );

  Widget _menu() => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff285bd7), Color(0xff19378e)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xffffd45a),
                  size: 34,
                ),
                SizedBox(height: 12),
                Text(
                  'Il tuo spazio di gioco',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'PlantHead Fanta • 1.1',
                  style: TextStyle(color: Color(0xffdce6ff)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_open_rounded),
                  title: const Text('Menu del sito'),
                  subtitle: const Text('Tutte le funzioni del tuo account'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!await _click('menu')) {
                      await _showOriginal();
                      _notice(
                        'Usa il menu della pagina. Accedi prima alla tua lega.',
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Lega e competizione'),
                  subtitle: const Text('Usa i selettori in alto nella pagina'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _web?.scrollTo(x: 0, y: 0, animated: true);
                    _notice(
                      'Seleziona lega e competizione nei controlli del sito.',
                    );
                  },
                ),
                if (_available.any(
                  (k) => !FantaNavigation.keys.contains(k) && k != 'logout',
                )) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'DISPONIBILI NELLA PAGINA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final key in sectionLabels.keys.where(
                    (k) =>
                        _available.contains(k) &&
                        !FantaNavigation.keys.contains(k) &&
                        k != 'logout',
                  ))
                    ListTile(
                      title: Text(sectionLabels[key]!.first),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        Navigator.pop(context);
                        if (!await _click(key)) {
                          _notice(
                            'Il comando è cambiato. Usa il menu del sito.',
                          );
                        }
                      },
                    ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.open_in_browser_rounded),
                  title: const Text('Apri nel browser'),
                  subtitle: const Text('Il browser ha una sessione separata'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      _openExternal(
                        NavigationPolicy.safeBrowserUri(_uri) ??
                            NavigationPolicy.home,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Pagina iniziale'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_home());
                  },
                ),
                if (_available.contains('logout'))
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Logout dal sito'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _click('logout');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.phonelink_erase_rounded),
                  title: const Text('Disconnetti dispositivo'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_resetSession());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Informazioni'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'PlantHead Fanta',
                      applicationVersion: '1.1.1 (3)',
                      children: [
                        const Text(
                          'Client indipendente, non affiliato a Fantacalcio. Le funzioni e le autorizzazioni sono quelle del sito ufficiale. Password gestite esclusivamente dalle pagine web. Nessuna notifica push nativa in questa versione.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Bind the actual native popup window: preserves POST requests, opener and
// shared cookies. Loading just the target URL would break many login flows.
class _PopupPage extends StatefulWidget {
  const _PopupPage({
    required this.windowId,
    required this.diagnostics,
    required this.navigate,
    required this.download,
  });
  final int windowId;
  final Diagnostics diagnostics;
  final Future<NavigationActionPolicy> Function(NavigationAction) navigate;
  final Future<void> Function(DownloadStartRequest) download;
  @override
  State<_PopupPage> createState() => _PopupPageState();
}

class _PopupPageState extends State<_PopupPage> {
  String _host = 'Finestra del sito';
  final _load = WebLoadMonitor();
  String? get _error => _load.failure == null
      ? null
      : 'La finestra del sito non è disponibile. Riprova o torna alla pagina precedente.';
  @override
  void initState() {
    super.initState();
    _load.begin();
    _load.addListener(_changed);
    _load.onTimeout = () =>
        widget.diagnostics.record('web_timeout', category: 'document');
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _load.removeListener(_changed);
    _load.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    _load.begin(restart: true);
    try {
      await _controller?.reload();
    } catch (_) {
      _load.fail('network');
    }
  }

  InAppWebViewController? _controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_host, style: const TextStyle(fontSize: 15))),
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          InAppWebView(
            windowId: widget.windowId,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              sharedCookiesEnabled: true,
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
              supportMultipleWindows: false,
              isInspectable: false,
              mediaPlaybackRequiresUserGesture: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              widget.diagnostics.record('web_created');
            },
            onProgressChanged: (_, value) => _load.updateProgress(value),
            onLoadStop: (controller, url) async {
              widget.diagnostics.record('web_load_stop');
              final generation = _load.generation;
              try {
                final content = await controller.evaluateJavascript(
                  source:
                      "!!document.body && (!!document.body.innerText.trim() || !!document.body.querySelector('input,button,img,iframe'))",
                );
                if (mounted) {
                  _load.complete(generation, hasContent: content == true);
                }
              } catch (_) {
                widget.diagnostics.record('web_probe_error');
              }
            },
            onUpdateVisitedHistory: (_, url, reload) =>
                widget.diagnostics.record('web_history'),
            onWebContentProcessDidTerminate: (_) {
              widget.diagnostics.record(
                'web_process_terminated',
                category: 'webkit',
              );
              _load.fail('webkit');
            },
            onReceivedHttpError: (_, request, response) {
              widget.diagnostics.record(
                'web_http_error',
                status: response.statusCode,
                category: request.isForMainFrame == true
                    ? 'main_frame'
                    : 'subframe',
              );
              if (request.isForMainFrame == true &&
                  (response.statusCode ?? 0) >= 400) {
                _load.fail('http');
              }
            },
            shouldOverrideUrlLoading: (_, action) => widget.navigate(action),
            onLoadStart: (_, url) {
              widget.diagnostics.record('web_load_start');
              _load.begin();
              if (mounted) {
                setState(() {
                  _host = url?.host ?? 'Finestra del sito';
                });
              }
            },
            onCloseWindow: (_) {
              if (mounted) Navigator.of(context).pop();
            },
            onDownloadStartRequest: (_, request) => widget.download(request),
            onPermissionRequest: (_, request) async => PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY,
            ),
            onReceivedError: (_, request, error) {
              final cancelled = error.type == WebResourceErrorType.CANCELLED;
              widget.diagnostics.record(
                'web_resource_error',
                code: error.type.toNativeValue(),
                category: cancelled
                    ? 'cancelled'
                    : request.isForMainFrame == true
                    ? 'main_frame'
                    : 'subframe',
              );
              if (request.isForMainFrame == true && !cancelled) {
                _load.fail('network');
              }
            },
          ),
          if (_load.busy)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Caricamento della finestra ufficiale…'),
                ),
              ),
            ),
          if (_error != null)
            Positioned.fill(
              child: LoadFailurePanel(
                message: _error!,
                onRetry: _retry,
                onHome: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    ),
  );
}
