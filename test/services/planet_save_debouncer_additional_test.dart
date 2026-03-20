import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/services/planet_save_debouncer.dart';

void main() {
  test(
    'runs the first scheduled save immediately when no prior save exists',
    () async {
      final debouncer = PlanetSaveDebouncer();
      int saveCount = 0;

      debouncer.schedule(() async {
        saveCount++;
      });

      await Future<void>.delayed(Duration.zero);
      expect(saveCount, equals(1));

      debouncer.dispose();
    },
  );

  test('delays saves scheduled inside the debounce interval', () {
    fakeAsync((async) {
      var now = DateTime(2026, 1, 1, 12);
      final debouncer = PlanetSaveDebouncer(
        interval: const Duration(seconds: 5),
        now: () => now,
      );
      int saveCount = 0;

      debouncer.schedule(() async {
        saveCount++;
      });
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 2));
      debouncer.schedule(() async {
        saveCount++;
      });
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 2));
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(saveCount, equals(2));

      debouncer.dispose();
    });
  });

  test('rescheduling cancels the previous pending timer', () {
    fakeAsync((async) {
      var now = DateTime(2026, 1, 1, 12);
      final debouncer = PlanetSaveDebouncer(
        interval: const Duration(seconds: 5),
        now: () => now,
      );
      int saveCount = 0;

      debouncer.schedule(() async {
        saveCount++;
      });
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 1));
      debouncer.schedule(() async {
        saveCount++;
      });

      now = now.add(const Duration(seconds: 1));
      debouncer.schedule(() async {
        saveCount++;
      });

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(saveCount, equals(2));

      debouncer.dispose();
    });
  });

  test('dispose cancels a pending delayed save', () {
    fakeAsync((async) {
      var now = DateTime(2026, 1, 1, 12);
      final debouncer = PlanetSaveDebouncer(
        interval: const Duration(seconds: 5),
        now: () => now,
      );
      int saveCount = 0;

      debouncer.schedule(() async {
        saveCount++;
      });
      async.flushMicrotasks();
      expect(saveCount, equals(1));

      now = now.add(const Duration(seconds: 1));
      debouncer.schedule(() async {
        saveCount++;
      });
      debouncer.dispose();

      now = now.add(const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(saveCount, equals(1));
    });
  });

  test('swallows save errors so later queued saves still run', () async {
    final debouncer = PlanetSaveDebouncer();
    final events = <String>[];

    debouncer.schedule(() async {
      events.add('first');
      throw StateError('boom');
    }, immediate: true);

    debouncer.schedule(() async {
      events.add('second');
    }, immediate: true);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(events, equals(['first', 'second']));

    debouncer.dispose();
  });
}
