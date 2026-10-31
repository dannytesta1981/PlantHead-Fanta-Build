import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bounds creation, redirects and empty documents independently of progress=100.
/// Never receives URLs, cookies, exception text or page contents.
class WebLoadMonitor extends ChangeNotifier {
  WebLoadMonitor({this.timeout = const Duration(seconds: 35)});
  final Duration timeout;
  Timer? _timer;
  int generation = 0;
  int progress = 0;
  bool busy = false;
  String? failure;
  VoidCallback? onTimeout;

  void begin({bool restart = false}) {
    if (restart || !busy) {
      generation++;
      _timer?.cancel();
      _timer = Timer(timeout, () {
        fail('timeout');
        onTimeout?.call();
      });
    }
    busy = true;
    failure = null;
    progress = 0;
    notifyListeners();
  }

  void updateProgress(int value) {
    progress = value.clamp(0, 100);
    notifyListeners();
  }

  bool complete(int expectedGeneration, {required bool hasContent}) {
    if (expectedGeneration != generation || failure != null || !hasContent) {
      return false;
    }
    _timer?.cancel();
    busy = false;
    progress = 100;
    notifyListeners();
    return true;
  }

  void fail(String category) {
    _timer?.cancel();
    generation++; // Ignore late DOM probes from a failed document.
    busy = false;
    failure = category;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
