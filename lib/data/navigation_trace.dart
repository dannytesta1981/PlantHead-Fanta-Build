import '../core/navigation_policy.dart';
import 'diagnostics.dart';

/// Deliberately coarse routing. No path, URL, query, fragment or hashes retained.
String routeCategory(Uri? uri) {
  if (uri == null) return 'unknown';
  if (uri.scheme == 'about' && uri.path == 'blank') return 'blank';
  if (NavigationPolicy.isOfficial(uri)) {
    if (uri.path.isEmpty || uri.path == '/') return 'official_home';
    if (uri.path == '/login' || uri.path == '/login/') return 'official_login';
    return 'official_other';
  }
  if (NavigationPolicy.classify(uri) == LinkAction.web) return 'identity';
  if (NavigationPolicy.classify(uri) == LinkAction.external) return 'external';
  return 'blocked';
}

class NavigationTrace {
  NavigationTrace(this.diagnostics, {this.window = 'main'});
  final Diagnostics diagnostics;
  final String window;
  int navigation = 0;
  String current = 'unknown';
  String _from = 'unknown';
  String _cause = 'unknown';
  bool _pendingAction = false;
  bool _redirectPending = false;

  void command(String command, {Uri? destination}) {
    event('web_app_command', uri: destination, cause: command);
  }

  void action(
    Uri? uri, {
    required bool mainFrame,
    String cause = 'web_other',
    String method = 'unknown',
  }) {
    if (mainFrame) {
      if (!_redirectPending) navigation = diagnostics.nextNavigation();
      _from = current;
      current = routeCategory(uri);
      _cause = _redirectPending ? 'server_redirect' : cause;
      _redirectPending = false;
      _pendingAction = true;
    }
    event(
      'web_request',
      uri: uri,
      mainFrame: mainFrame,
      cause: mainFrame ? _cause : cause,
      method: method,
    );
  }

  void started(Uri? uri) {
    if (!_pendingAction) {
      navigation = diagnostics.nextNavigation();
      _from = current;
      _cause = 'unknown';
    }
    _pendingAction = false;
    current = routeCategory(uri);
    event('web_load_start', uri: uri, mainFrame: true);
  }

  void redirect() {
    _redirectPending = true;
    _cause = 'server_redirect';
    _from = current;
    // WKWebView reports the redirect but supplies no destination in this callback.
    event('web_server_redirect', cause: 'server_redirect', mainFrame: true);
  }

  void event(
    String name, {
    Uri? uri,
    bool? mainFrame,
    String? cause,
    String method = 'unknown',
    int? status,
    int? code,
  }) {
    diagnostics.record(
      name,
      route: routeCategory(uri),
      from: _from,
      cause: cause ?? _cause,
      window: window,
      navigation: navigation,
      method: method,
      status: status,
      code: code,
      category: mainFrame == null
          ? 'unknown'
          : mainFrame
          ? 'main_frame'
          : 'subframe',
    );
    if (name == 'web_commit' || name == 'web_load_stop')
      _redirectPending = false;
  }
}
