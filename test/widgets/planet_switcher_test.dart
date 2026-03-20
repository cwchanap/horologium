import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/planet/active_planet.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/widgets/planet_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PlanetSwitcher', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ActivePlanet().reset();
    });

    tearDown(() {
      ActivePlanet().reset();
    });

    testWidgets('shows the default Earth state when uninitialized', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PlanetSwitcher())),
      );

      expect(find.text('Planet Selection'), findsOneWidget);
      expect(find.text('Current Planet: Earth'), findsOneWidget);
      expect(find.text('Available Planets:'), findsOneWidget);
      expect(
        find.text('More planets will be unlocked as you progress!'),
        findsOneWidget,
      );

      final earthButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Earth'),
      );
      expect(earthButton.onPressed, isNull);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('switches planets and notifies listeners', (
      WidgetTester tester,
    ) async {
      ActivePlanet().initialize(Planet(id: 'mars', name: 'Mars'));
      int changeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanetSwitcher(onPlanetChanged: () => changeCount++),
          ),
        ),
      );

      expect(find.text('Current Planet: Mars'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Earth'));
      await tester.pumpAndSettle();

      expect(changeCount, equals(1));
      expect(ActivePlanet().activePlanetId, equals('earth'));
      expect(find.text('Current Planet: Earth'), findsOneWidget);
      expect(find.text('Switched to Earth'), findsOneWidget);

      final earthButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Earth'),
      );
      expect(earthButton.onPressed, isNull);
    });
  });
}
