import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/services/planet_save_debouncer.dart';

void main() {
  test('serializes overlapping immediate saves', () async {
    final debouncer = PlanetSaveDebouncer();
    final events = <String>[];
    final firstSave = Completer<void>();
    final secondSave = Completer<void>();
    int saveCount = 0;

    debouncer.schedule(() async {
      saveCount++;
      events.add('start-1');
      await firstSave.future;
      events.add('end-1');
    }, immediate: true);

    debouncer.schedule(() async {
      saveCount++;
      events.add('start-2');
      await secondSave.future;
      events.add('end-2');
    }, immediate: true);

    await Future<void>.delayed(Duration.zero);
    expect(saveCount, 1);
    expect(events, equals(['start-1']));

    firstSave.complete();
    await Future<void>.delayed(Duration.zero);
    expect(events, equals(['start-1', 'end-1', 'start-2']));

    secondSave.complete();
    await Future<void>.delayed(Duration.zero);
    expect(events, equals(['start-1', 'end-1', 'start-2', 'end-2']));

    debouncer.dispose();
  });
}
