import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/serial_task_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('operations run in enqueue order without overtaking', () async {
    final errors = <Object>[];
    final queue = SerialTaskQueue(errors.add);
    final order = <String>[];
    final firstGate = Completer<void>();

    final first = queue.enqueue(() async {
      order.add('first:start');
      await firstGate.future;
      order.add('first:end');
      return 1;
    });
    final second = queue.enqueue(() async {
      order.add('second');
      return 2;
    });
    await Future<void>.delayed(Duration.zero);
    expect(order, ['first:start']);

    firstGate.complete();
    expect(await first, 1);
    expect(await second, 2);
    expect(order, ['first:start', 'first:end', 'second']);
  });

  test('an operation error reaches its caller, is logged, and never stalls '
      'the queue', () async {
    final errors = <Object>[];
    final queue = SerialTaskQueue(errors.add);

    await expectLater(
      queue.enqueue<int>(() => throw StateError('boom')),
      throwsStateError,
    );
    expect(await queue.enqueue(() async => 3), 3);
    expect(errors.single, isA<StateError>());
  });
}
