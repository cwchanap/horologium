/// Serialized async operations behind a single Future chain.
///
/// Each [enqueue] runs after every previously enqueued operation settles,
/// so a later call can never overtake in-flight work (e.g. a cancellation
/// overtaking a schedule). The returned future carries the operation's own
/// result or error to its caller; the queue itself only orders work, so one
/// failure never stalls the chain. Every error is also reported through
/// [onError], which makes an unawaited call safe.
class SerialTaskQueue {
  SerialTaskQueue(this.onError);

  /// Reports every enqueued operation's error (typically a `debugPrint`).
  final void Function(Object error) onError;

  Future<void>? _tail;

  Future<T> enqueue<T>(Future<T> Function() operation) {
    late final Future<void> tail;
    final result = (_tail ?? Future<void>.value()).then((_) => operation());
    tail = result.then<void>((_) {}, onError: onError).whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    _tail = tail;
    return result;
  }
}
