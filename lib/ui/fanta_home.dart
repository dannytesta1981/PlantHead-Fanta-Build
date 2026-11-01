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
import '../data/navigation_trace.dart';

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
  late final NavigationTrace _trace;
  int? _httpStatus;
  bool _accessAfterHome = false;
  bool _probing = false;
  String? _script;
  String? _contentProbe;
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
    _trace = NavigationTrace(widget.store.diagnostics);
    _trace.command('app_initial_home', destination: NavigationPolicy.home);
    widget.store.onWebCommand = () => _trace.command('app_control');
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
      if (_load.canProbe) unawaited(_verifyDocument());
    });
  }

  Future<void> _prepare() async {
    _load.begin(restart: true);
    try {
      _script = await rootBundle.loadString('assets/navigation.js');
      _contentProbe = await rootBundle.loadString('assets/content_readiness.js');
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
        if (_load.canProbe) unawaited(_verifyDocument());
      });
      unawaited(_scan());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    widget.store.onWebCommand = null;
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
      if (widget.visible && _load.canProbe) {
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
          'Il contenuto non è diventato utilizzabile entro 35 secondi. Puoi attendere ancora o premere Riprova.',
        'webkit' =>
          'Il contenuto web è stato interrotto da iOS. Premi Riprova per ricrearlo.',
        'http' =>
          _httpStatus == 404
              ? 'Il sito ha restituito HTTP 404 per la pagina principale. Puoi tornare alla home ufficiale e usare il suo modulo di accesso. Riprova riapre la home.'
              : 'Il sito ha restituito HTTP ${_httpStatus ?? 0}. Torna alla home ufficiale o riprova.',
        _ =>
          'Impossibile caricare il sito ufficiale. Controlla la connessione e premi Riprova.',
      };
    });
  }

  Future<void> _verifyDocument() async {
    final c = _web;
    if (c == null || !widget.visible || _probing || !_load.canProbe) return;
    _probing = true;
    final generation = _load.generation;
    try {
      // Only a boolean leaves the document. No field values, HTML or URLs.
      final source = _contentProbe ??= await rootBundle.loadString(
        'assets/content_readiness.js',
      );
      final visible = await c.evaluateJavascript(source: source).timeout(
        const Duration(seconds: 3),
      );
      if (!mounted || c != _web || generation != _load.generation) return;
      final ok = visible == true;
      widget.store.diagnostics.record(ok ? 'web_dom_ready' : 'web_dom_empty');
      if (_load.complete(generation, hasContent: ok)) {
        widget.store.diagnostics.record('web_content_usable');
        widget.store.pageFinished();
        await _refresh?.endRefreshing();
        await _scan();
        if (_accessAfterHome) {
          _accessAfterHome = false;
          unawaited(_openAccess(afterHome: true));
        }
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

  String _navigationCause(NavigationAction action) {
    if (action.isRedirect == true) return 'server_redirect';
    if (action.navigationType == NavigationType.LINK_ACTIVATED)
      return 'web_link';
    if (action.navigationType == NavigationType.FORM_SUBMITTED ||
        action.navigationType == NavigationType.FORM_RESUBMITTED)
      return 'web_form';
    if (action.navigationType == NavigationType.BACK_FORWARD)
      return 'web_history';
    if (action.navigationType == NavigationType.RELOAD) return 'web_reload';
    return 'web_other';
  }

  Future<NavigationActionPolicy> _navigate(
    NavigationAction action, {
    NavigationTrace? journal,
  }) async {
    // Subframes retain the existing allow policy; only their errors are journalled.
    if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
    final trace = journal ?? _trace;
    final uri = Uri.tryParse(action.request.url?.toString() ?? '');
    final method = action.request.method?.toLowerCase();
    trace.action(
      uri,
      mainFrame: action.isForMainFrame,
      cause: _navigationCause(action),
      method: method == 'get' || method == 'post' ? method! : 'other',
    );
    // Keep the existing navigation policy. Never redirect subframes externally.
    if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
    switch (NavigationPolicy.classify(uri)) {
      case LinkAction.web:
        trace.event('web_navigation_allow', uri: uri, mainFrame: true);
        return NavigationActionPolicy.ALLOW;
      case LinkAction.external:
        trace.event('web_navigation_external', uri: uri, mainFrame: true);
        if (uri != null) await _openExternal(uri);
        return NavigationActionPolicy.CANCEL;
      case LinkAction.block:
        trace.event('web_navigation_block', uri: uri, mainFrame: true);
        _notice(
          'Collegamento non supportato. Usa il sito originale per continuare.',
        );
        return NavigationActionPolicy.CANCEL;
    }
  }

  Future<void> _openOfficialAccess() async {
    final c = _web;
    if (c == null || !widget.visible) return;
    const reasons = <int, String>{
      0: 'Modulo ufficiale visibile. Puoi accedere dalla pagina.',
      1: 'Pulsante LOGIN principale assente.',
      2: 'Più pulsanti LOGIN principali: azione annullata.',
      3: 'Pulsante disabilitato o associato a un form.',
      4: 'Controllo o antenato hidden/inert.',
      5: 'Pulsante con display none.', 6: 'Antenato con display none.',
      7: 'Pulsante con visibility nascosta.', 8: 'Antenato con visibility nascosta.',
      9: 'Pulsante con opacità zero.', 10: 'Antenato con opacità zero.',
      11: 'Pulsante senza dimensioni visibili.', 12: 'Interazione pointer-events disabilitata.',
      13: 'Pulsante fuori schermo: scorri manualmente fino a LOGIN e riprova.',
      14: 'Pulsante coperto da un altro elemento.',
      15: 'Modale ufficiale assente o ambigua.',
      16: 'Plugin ufficiale della modale non disponibile.',
      17: 'Click eseguito, ma il campo password non è diventato utilizzabile.',
      18: 'Pagina non supportata o verifica non completata.',
    };
    var code = 18;
    try {
      final installed = await c.evaluateJavascript(source: await rootBundle.loadString('assets/official_access.js'));
      if (installed == true) {
        final response = await c.callAsyncJavaScript(functionBody: 'return await window.__phOfficialAccess.open();').timeout(const Duration(seconds: 5));
        final result = response?.value;
        if (result is int && reasons.containsKey(result)) code = result;
      }
    } catch (_) {}
    widget.store.diagnostics.record('access_inspection', code: code);
    _notice(reasons[code]!);
  }

  Future<void> _verifyAccess() async {
    final c = _web;
    if (c == null || !widget.visible) {
      widget.store.diagnostics.recordAccessInspection({'command': 'not_visible'});
      return;
    }
    try {
      final raw = await c.evaluateJavascript(
        source: await rootBundle.loadString('assets/access_inspection.js'),
      ).timeout(const Duration(seconds: 8));
      if (raw is! String) throw const FormatException();
      widget.store.diagnostics.recordAccessInspection(jsonDecode(raw));
      _notice('Verifica registrata. Menu nativo → Diagnostica → Esporta.');
    } catch (_) {
      widget.store.diagnostics.recordAccessInspection({'command': 'execution_failed'});
      _notice('Verifica non completata. Esporta la diagnostica.');
    }
  }

  Future<void> _openAccess({bool afterHome = false}) async {
    final c = _web;
    _trace.command('app_access', destination: NavigationPolicy.home);
    try {
      final actual = c == null
          ? null
          : Uri.tryParse((await c.getUrl())?.toString() ?? '');
      if (c != null &&
          _load.failure == null &&
          NavigationPolicy.isOfficial(actual)) {
        await c.evaluateJavascript(
          source: await rootBundle.loadString('assets/access_bridge.js'),
        );
        final inspection = await c.evaluateJavascript(
          source: 'JSON.stringify(window.__phAccessBridge?.inspect() ?? null)',
        );
        if (inspection is String) {
          widget.store.diagnostics.recordAccessInspection(jsonDecode(inspection));
        }
        // A legitimate site redirect may already expose the login form. Preserve
        // that page and its state, rather than forcing another home navigation.
        var visible = await c.evaluateJavascript(
          source: 'window.__phAccessBridge?.probe().passwordVisible === true',
        );
        if (visible != true && routeCategory(actual) == 'official_home') {
          final outcome = await c.evaluateJavascript(
            source: 'window.__phAccessBridge?.open()',
          );
          if (outcome == 'requested') {
            _trace.event(
              'web_access_requested',
              uri: actual,
              cause: 'app_access',
            );
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (!mounted || c != _web) return;
            visible = await c.evaluateJavascript(
              source:
                  'window.__phAccessBridge?.probe().passwordVisible === true',
            );
          }
        }
        if (!mounted || c != _web) return;
        if (visible == true) {
          _trace.event('web_access_visible', uri: actual, cause: 'app_access');
          return;
        }
        if (routeCategory(actual) == 'official_home' || afterHome) {
          _trace.event(
            'web_access_unavailable',
            uri: actual,
            cause: 'app_access',
          );
          _notice(
            'Modulo non riconosciuto o non ancora visibile. Usa i controlli della pagina ufficiale.',
          );
          return;
        }
      }
      if (afterHome) {
        _trace.event(
          'web_access_unavailable',
          uri: actual,
          cause: 'app_access',
        );
        _notice(
          'Il ritorno alla home non ha reso disponibile il modulo. Usa i controlli del sito.',
        );
        return;
      }
      // At most one app-issued home recovery per explicit user action.
      _accessAfterHome = true;
      await _home();
    } catch (_) {
      _trace.event('web_access_unavailable', cause: 'app_access');
      _notice(
        'Impossibile aprire il modulo esistente. Usa i controlli del sito.',
      );
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
      _trace.command('app_control');
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
    _trace.event('web_retry');
    // Recreate only failed/uncreated views. Keep the persistent website store;
    // never delete cookies or modify the official authentication flow.
    final recreate = _web == null || _load.failure != null;
    _trace.command(
      recreate ? 'app_retry_home' : 'app_reload',
      destination: recreate ? NavigationPolicy.home : _uri,
    );
    _httpStatus = null;
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
    _trace.command('app_home', destination: NavigationPolicy.home);
    _httpStatus = null;
    if (_web == null || _load.failure != null) {
      await _reload();
      return;
    }
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
    _httpStatus = null;
    widget.store.pageStarted();
    _load.begin();
    setState(() {
      _available = {};
    });
  }

  Future<void> _finished(WebUri? url) async {
    _trace.event(
      'web_load_stop',
      uri: Uri.tryParse(url?.toString() ?? ''),
      mainFrame: true,
    );
    _load.navigationStopped();
    // A cancelled TLS handshake or an empty document is not a loaded page.
    await _verifyDocument();
  }

  void _fail(String category, {int? status}) {
    _httpStatus = status;
    widget.store.networkError(status: status);
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
    _trace.event(
      'web_popup_requested',
      uri: Uri.tryParse(action.request.url?.toString() ?? ''),
      cause: 'popup',
    );
    final popupTrace = NavigationTrace(
      widget.store.diagnostics,
      window: 'popup',
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _PopupPage(
          windowId: action.windowId,
          diagnostics: widget.store.diagnostics,
          trace: popupTrace,
          navigate: (action) => _navigate(action, journal: popupTrace),
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
        _trace.event('web_created');
      },
      shouldOverrideUrlLoading: (_, action) => _navigate(action),
      onLoadStart: (_, url) {
        if (mounted) {
          _uri = Uri.tryParse(url?.toString() ?? "");
          _trace.started(_uri);
          _started();
        }
      },
      onLoadStop: (_, url) => _finished(url),
      onDidReceiveServerRedirectForProvisionalNavigation: (_) =>
          _trace.redirect(),
      onPageCommitVisible: (_, url) {
        _load.markCommitted();
        _trace.event(
          'web_commit',
          uri: Uri.tryParse(url?.toString() ?? ''),
          mainFrame: true,
        );
        unawaited(_verifyDocument());
      },
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
        _trace.event(
          'web_history',
          uri: Uri.tryParse(url?.toString() ?? ''),
          mainFrame: true,
          cause: 'web_history',
        );
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
        _trace.event(
          'web_resource_error',
          uri: Uri.tryParse(request.url.toString()),
          mainFrame: request.isForMainFrame,
          code: error.type.toNativeValue(),
        );
        if (request.isForMainFrame == true && !cancelled) _fail('network');
      },
      onReceivedHttpError: (_, request, response) {
        final uri = Uri.tryParse(request.url.toString());
        _trace.event(
          'web_http_error',
          uri: uri,
          mainFrame: request.isForMainFrame,
          status: response.statusCode,
        );
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 0) >= 400) {
          if (response.statusCode == 404)
            _trace.event(
              'web_main_404',
              uri: uri,
              mainFrame: true,
              status: 404,
            );
          _fail('http', status: response.statusCode);
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
            _trace.command('app_back');
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
                      title: _httpStatus == 404
                          ? 'Pagina non trovata · HTTP 404'
                          : 'Riprendiamo da qui',
                      onAccess: _httpStatus == 404 ? _openAccess : null,
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
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Apri accesso ufficiale'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_openOfficialAccess());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Verifica accesso'),
                  subtitle: const Text('Osservazione senza click o navigazioni'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_verifyAccess());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Accesso dalla home ufficiale'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_openAccess());
                  },
                ),
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
                      applicationVersion: '1.1.2 (5)',
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
    required this.trace,
    required this.navigate,
    required this.download,
  });
  final int windowId;
  final Diagnostics diagnostics;
  final NavigationTrace trace;
  final Future<NavigationActionPolicy> Function(NavigationAction) navigate;
  final Future<void> Function(DownloadStartRequest) download;
  @override
  State<_PopupPage> createState() => _PopupPageState();
}

class _PopupPageState extends State<_PopupPage> {
  String _host = 'Finestra del sito';
  int? _httpStatus;
  final _load = WebLoadMonitor();
  String? get _error => _load.failure == null
      ? null
      : _httpStatus == 404
      ? 'HTTP 404: la pagina richiesta dalla finestra del sito non esiste. Torna alla pagina precedente.'
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
    widget.trace.event('web_popup_closed', cause: 'popup');
    _load.removeListener(_changed);
    _load.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    widget.trace.command('app_reload');
    _httpStatus = null;
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
              widget.trace.event('web_created');
            },
            onProgressChanged: (_, value) => _load.updateProgress(value),
            onLoadStop: (controller, url) async {
              _load.navigationStopped();
              widget.trace.event(
                'web_load_stop',
                uri: Uri.tryParse(url?.toString() ?? ''),
                mainFrame: true,
              );
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
            onUpdateVisitedHistory: (_, url, reload) => widget.trace.event(
              'web_history',
              uri: Uri.tryParse(url?.toString() ?? ''),
              mainFrame: true,
              cause: 'web_history',
            ),
            onDidReceiveServerRedirectForProvisionalNavigation: (_) =>
                widget.trace.redirect(),
            onPageCommitVisible: (_, url) => widget.trace.event(
              'web_commit',
              uri: Uri.tryParse(url?.toString() ?? ''),
              mainFrame: true,
            ),
            onWebContentProcessDidTerminate: (_) {
              widget.diagnostics.record(
                'web_process_terminated',
                category: 'webkit',
              );
              _load.fail('webkit');
            },
            onReceivedHttpError: (_, request, response) {
              final uri = Uri.tryParse(request.url.toString());
              widget.trace.event(
                'web_http_error',
                uri: uri,
                mainFrame: request.isForMainFrame,
                status: response.statusCode,
              );
              if (request.isForMainFrame == true &&
                  (response.statusCode ?? 0) >= 400) {
                _httpStatus = response.statusCode;
                if (_httpStatus == 404)
                  widget.trace.event(
                    'web_main_404',
                    uri: uri,
                    mainFrame: true,
                    status: 404,
                  );
                _load.fail('http');
              }
            },
            shouldOverrideUrlLoading: (_, action) => widget.navigate(action),
            onLoadStart: (_, url) {
              _httpStatus = null;
              widget.trace.started(Uri.tryParse(url?.toString() ?? ''));
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
              widget.trace.event(
                'web_resource_error',
                uri: Uri.tryParse(request.url.toString()),
                mainFrame: request.isForMainFrame,
                code: error.type.toNativeValue(),
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
