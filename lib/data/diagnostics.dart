import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// An allowlist serializer, not a redactor over raw logs. Arbitrary messages,
// URLs, DOM, account labels and exception text are never accepted.
class Diagnostics extends ChangeNotifier {
  static const events = {
    'startup',
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
  final List<Map<String, Object>> _entries = [];
  List<Map<String, Object>> get entries => List.unmodifiable(_entries);
  void record(
    String event, {
    String section = 'unknown',
    int? count,
    int? status,
    int? code,
    String category = 'unknown',
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
        'version': '1.1.1+3',
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
