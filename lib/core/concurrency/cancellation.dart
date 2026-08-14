import 'dart:async';

class CancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void throwIfCancelled() {
    if (_cancelled) throw StateError('Operation cancelled');
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

class AsyncSemaphore {
  AsyncSemaphore(this.limit) : assert(limit > 0);

  final int limit;
  int _active = 0;
  final List<void Function()> _waiters = [];

  Future<T> withPermit<T>(Future<T> Function() operation) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < limit) {
      _active++;
      return;
    }
    final completer = _PermitCompleter();
    _waiters.add(completer.complete);
    await completer.future;
    _active++;
  }

  void _release() {
    _active--;
    if (_waiters.isNotEmpty) _waiters.removeAt(0)();
  }
}

class _PermitCompleter {
  final _completer = Completer<void>();
  Future<void> get future => _completer.future;
  void complete() => _completer.complete();
}
