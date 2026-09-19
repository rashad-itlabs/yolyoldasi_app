import 'dart:async';

import 'package:flutter/foundation.dart';

/// Collapses rapid-fire calls into one — used by the city search field and the
/// ride search form so we do not hit the backend on every keystroke.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs a pending action immediately, if any is queued.
  void flush(VoidCallback action) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      action();
    }
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
