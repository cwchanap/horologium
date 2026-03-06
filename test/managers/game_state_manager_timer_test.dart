import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/managers/game_state_manager.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GameStateManager timer resilience', () {
    test(
      'resource generation timer survives exception in getBuildingsCallback',
      () async {
        SharedPreferences.setMockInitialValues({});
        var updateCount = 0;
        var throwCount = 0;
        final manager = GameStateManager(resources: Resources());

        manager.startResourceGeneration(() {
          throwCount++;
          if (throwCount <= 2) throw Exception('simulated error');
          return [];
        }, () => updateCount++);

        // Wait for 3+ ticks (3 seconds + a bit)
        await Future<void>.delayed(const Duration(milliseconds: 3200));
        manager.stopResourceGeneration();

        // Timer must have continued running past the exceptions
        // updateCount should be > 0 (at least tick 3 succeeded)
        expect(updateCount, greaterThan(0));
        // throwCount should be >= 3 (all 3 ticks ran, first 2 threw, 3rd succeeded)
        expect(throwCount, greaterThanOrEqualTo(3));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
