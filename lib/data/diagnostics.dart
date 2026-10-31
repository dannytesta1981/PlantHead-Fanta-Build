import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// An allowlist serializer, not a redactor over raw logs. Arbitrary messages,
// URLs, DOM, account labels and exception text are never accepted.
class Diagnostics extends ChangeNotifier {
  static const events = {
    'startup',
    'access_inspection',
    'web_app_command',
    'web_request',
    'web_server_redirect',
    'web_commit',
    'web_main_404',
    'web_popup_requested',
    'web_popup_closed',
    'web_access_requested',
    'web_access_unavailable',
    'web_access_visible',
    'login_form_observed',
    'web_created',
    'web_visible',
    'web_hidden',
    'web_load_start',
    'web_load_stop',
    'web_history',
    'web_resource_error',
    'web_http_error',
    'web_timeout',
    'web_dom_ready',
    'web_dom_empty',
    'web_probe_error',
    'web_process_terminated',
    'web_retry',
    'web_navigation_allow',
    'web_navigation_external',
    'web_navigation_block',
    'web_paused',
    'page_start',
    'page_loaded',
    'history',
    'http_error',
    'network_error',
    'extract_ok',
    'extract_error',
    'origin_rejected',
    'navigation_requested',
    'navigation_missing',
    'session_cleared',
    'resumed',
    'web_open',
    'native_open',
  };
  static const sections = {
    'dashboard',
    'rose',
    'calendario',
    'classifica',
    'web',
    'menu',
    'unknown',
  };
  int _navigationSequence = 0;
  int nextNavigation() => ++_navigationSequence;
  static const routes = {
    'unknown',
    'blank',
    'official_home',
    'official_login',
    'official_other',
    'identity',
    'external',
    'blocked',
  };
  static const causes = {
    'unknown',
    'web_link',
    'web_form',
    'web_history',
    'web_reload',
    'web_other',
    'server_redirect',
    'app_initial_home',
    'app_home',
    'app_retry_home',
    'app_reload',
    'app_control',
    'app_back',
    'app_access',
    'popup',
  };
  final List<Map<String, Object>> _entries = [];
  List<Map<String, Object>> get entries => List.unmodifiable(
    _entries.map((entry) => Map<String, Object>.unmodifiable(entry)),
  );
  void recordAccessInspection(dynamic raw) {
    const fields = <String, List<String>>{
      'command': ['executed', 'origin_rejected', 'execution_failed', 'not_visible'],
      'trigger': ['absent_active_dom', 'hidden', 'disabled_or_form_owned', 'eligible_unique', 'unmatched_or_ambiguous', 'excluded', 'ambiguous', 'recognized'],
      'dialog': ['absent', 'hidden', 'visible'],
      'password': ['absent', 'hidden', 'visible'],
      'username': ['absent', 'hidden', 'visible'],
      'passwordEnabled': ['absent', 'disabled', 'enabled'],
      'usernameEnabled': ['absent', 'disabled', 'enabled'],
      'modalInstance': ['unknown', 'present', 'absent'],
      'plugin': ['absent', 'present'],
      'handler': ['unknown'],
      'initialization': ['unknown'],
      'ready': ['loading', 'interactive', 'complete', 'unknown'],
    };
    if (raw is! Map) return;
    final safe = <String, Object>{};
    for (final entry in fields.entries) {
      if (entry.value.contains(raw[entry.key])) safe[entry.key] = raw[entry.key] as String;
    }
    _entries.add({'at': DateTime.now().toUtc().toIso8601String(), 'event': 'access_inspection', ...safe});
    if (_entries.length > 150) _entries.removeAt(0);
    notifyListeners();
  }

  void record(
    String event, {
    String section = 'unknown',
    int? count,
    int? status,
    int? code,
    String category = 'unknown',
    String route = 'unknown',
    String from = 'unknown',
    String cause = 'unknown',
    String window = 'unknown',
    String method = 'unknown',
    int? navigation,
  }) {
    if (!events.contains(event)) return;
    _entries.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      'category':
          const {
            'unknown',
            'main_frame',
            'subframe',
            'cancelled',
            'creation',
            'document',
            'webkit',
          }.contains(category)
          ? category
          : 'unknown',
      if (code != null && code >= -9999 && code <= 9999) 'code': code,
      'route': routes.contains(route) ? route : 'unknown',
      'from': routes.contains(from) ? from : 'unknown',
      'cause': causes.contains(cause) ? cause : 'unknown',
      'window': const {'main', 'popup'}.contains(window) ? window : 'unknown',
      'method': const {'get', 'post', 'other'}.contains(method)
          ? method
          : 'unknown',
      if (navigation != null) 'navigation': navigation.clamp(0, 1000000),
      'section': sections.contains(section) ? section : 'unknown',
      if (count != null) 'count': count.clamp(0, 10000),
      if (status != null && status >= 100 && status <= 599)
        'httpStatus': status,
    });
    if (_entries.length > 150) _entries.removeAt(0);
    notifyListeners();
  }

  String export({required String session, required Map<String, int> counts}) =>
      const JsonEncoder.withIndent('  ').convert({
        'app': 'PlantHead Fanta',
        'version': '1.1.4+7',
        'adapter': 'ph-dom/1',
        'platform': Platform.operatingSystem,
        'session':
            const {'league_page', 'login_form', 'unknown'}.contains(session)
            ? session
            : 'unknown',
        'counts': {
          for (final k in [
            'ranking',
            'teams',
            'matches',
            'players',
            'tables',
            'matchCards',
            'teamCards',
          ])
            k: (counts[k] ?? 0).clamp(0, 10000),
        },
        'events': _entries,
      });
}
