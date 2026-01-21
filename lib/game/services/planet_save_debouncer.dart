import 'dart:async';

class PlanetSaveDebouncer {
  PlanetSaveDebouncer({
    Duration interval = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _interval = interval,
       _now = now ?? DateTime.now;

  final Duration _interval;
  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _lastSaveAt;

  void schedule(
    Future<void> Function() saveCallback, {
    bool immediate = false,
  }) {
    if (immediate) {
      _timer?.cancel();
      _timer = null;
      _lastSaveAt = _now();
      unawaited(saveCallback());
      return;
    }

    final now = _now();
    final lastSaveAt = _lastSaveAt;
    if (lastSaveAt == null || now.difference(lastSaveAt) >= _interval) {
      _lastSaveAt = now;
      unawaited(saveCallback());
      return;
    }

    final delay = _interval - now.difference(lastSaveAt);
    _timer?.cancel();
    _timer = Timer(delay, () {
      _lastSaveAt = _now();
      unawaited(saveCallback());
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
