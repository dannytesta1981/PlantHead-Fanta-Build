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
  bool contentReady = false;
  bool navigationComplete = false;
  bool documentCommitted = false;
  String? failure;
  VoidCallback? onTimeout;

  bool get _acceptsContent => !contentReady && (failure == null || failure == 'timeout');
  bool get canProbe => documentCommitted && _acceptsContent;

  void markCommitted() {
    documentCommitted = true;
    notifyListeners();
  }

  void navigationStopped() {
    navigationComplete = true;
    documentCommitted = true;
    notifyListeners();
  }

  void begin({bool restart = false}) {
    generation++; // Reject probes issued before a new document/redirect.
    if (restart || !busy) {
      _timer?.cancel();
      _timer = Timer(timeout, () {
        fail('timeout');
        onTimeout?.call();
      });
    }
    busy = true;
    contentReady = false;
    navigationComplete = false;
    documentCommitted = false;
    failure = null;
    progress = 0;
    notifyListeners();
  }

  void updateProgress(int value) {
    progress = value.clamp(0, 100);
    notifyListeners();
  }

  bool complete(int expectedGeneration, {required bool hasContent}) {
    if (expectedGeneration != generation || !_acceptsContent || !hasContent) {
      return false;
    }
    _timer?.cancel();
    busy = false;
    contentReady = true;
    documentCommitted = true;
    failure = null;
    progress = 100;
    notifyListeners();
    return true;
  }

  void fail(String category) {
    _timer?.cancel();
    // Timeout is recoverable by usable content from this SAME document.
    // Hard errors invalidate in-flight probes and require a new navigation.
    if (category != 'timeout') generation++;
    busy = false;
    contentReady = false;
    failure = category;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
