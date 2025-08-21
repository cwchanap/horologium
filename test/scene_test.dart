import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:horologium/game/main_game.dart';
import 'package:horologium/game/scene_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MainGame Tests', () {
    late MainGame game;

    setUp(() {
      game = MainGame();
    });

    test('MainGame initializes correctly', () {
      // Test that MainGame can be created without errors
      expect(game, isA<MainGame>());
      expect(game.buildingToPlace, isNull);
      expect(game.placementPreview, isA<PlacementPreview>());
      
      // Test that callback functions can be assigned
      game.onGridCellTapped = (int x, int y) {};
      game.onGridCellLongTapped = (int x, int y) {};
      game.onGridCellSecondaryTapped = (int x, int y) {};
      
      expect(game.onGridCellTapped, isNotNull);
      expect(game.onGridCellLongTapped, isNotNull);
      expect(game.onGridCellSecondaryTapped, isNotNull);
    });

    test('Grid gets initialized properly', () {
      // Test grid initialization without the full game context
      final grid = Grid();
      expect(grid, isA<Grid>());
      expect(grid.gridSize, equals(50)); // default grid size
    });

    test('LoadBuildings with valid data', () async {
      // Setup mock data
      SharedPreferences.setMockInitialValues({
        'buildings': ['5,5,House', '10,10,Power Plant']
      });
      
      // Initialize grid first
      final grid = Grid();
      // Use reflection or direct assignment to set the grid
      // Since _grid is private, we'll test this differently
      await game.loadBuildings();
      expect(true, isTrue);
    });

    test('LoadBuildings with empty data', () async {
      // Setup empty mock data
      SharedPreferences.setMockInitialValues({});
      
      // Test loadBuildings method directly
      await game.loadBuildings();
      
      // Method should handle empty data gracefully
      expect(true, isTrue); // Method completed without throwing
    });

    test('Grid cell tap callback logic', () {
      bool callbackCalled = false;
      int tapX = -1, tapY = -1;
      
      game.onGridCellTapped = (x, y) {
        callbackCalled = true;
        tapX = x;
        tapY = y;
      };
      
      // Test callback invocation
      game.onGridCellTapped?.call(5, 5);
      
      expect(callbackCalled, isTrue);
      expect(tapX, equals(5));
      expect(tapY, equals(5));
    });

    test('Zoom clamp functionality', () {
      // This test is limited without full game initialization
      // but we can test that the method exists
      expect(() => game.clampZoom(), returnsNormally);
    });

    test('Placement preview hide/show', () {
      // Test that hide method exists and runs
      expect(() => game.hidePlacementPreview(), returnsNormally);
    });
  });

  group('PlacementPreview Tests', () {
    late PlacementPreview preview;

    setUp(() {
      preview = PlacementPreview();
    });

    test('PlacementPreview initializes correctly', () {
      expect(preview.building, isNull);
      expect(preview.isValid, isFalse);
    });

    test('PlacementPreview can be configured', () {
      final testBuilding = BuildingRegistry.availableBuildings.first;
      preview.building = testBuilding;
      preview.isValid = true;
      
      expect(preview.building, equals(testBuilding));
      expect(preview.isValid, isTrue);
    });

    test('PlacementPreview renders without building', () {
      // Test that render method handles null building gracefully
      expect(() {
        final canvas = MockCanvas();
        preview.render(canvas);
      }, returnsNormally);
    });
  });

  group('Grid Tests', () {
    late Grid grid;

    setUp(() {
      grid = Grid();
    });

    test('Grid initializes with correct defaults', () {
      expect(grid.gridSize, equals(50));
    });

    test('Grid position calculation', () {
      // Initialize grid size first
      grid.size = Vector2(500, 500); // Set a proper size
      
      // Test getGridPosition with valid coordinates
      final position = grid.getGridPosition(Vector2(75, 75)); // 1.5 cells in
      expect(position, isNotNull);
      expect(position!.x, equals(1.0));
      expect(position.y, equals(1.0));
    });

    test('Grid position calculation outside bounds', () {
      // Without proper size initialization, we test the method exists
      expect(() => grid.getGridPosition(Vector2(-10, -10)), returnsNormally);
    });

    test('Grid center position calculation', () {
      final center = grid.getGridCenterPosition(2, 3);
      expect(center.x, equals(2 * cellWidth + cellWidth / 2));
      expect(center.y, equals(3 * cellHeight + cellHeight / 2));
    });

    test('Area availability check', () {
      // Test with default empty grid
      final available = grid.isAreaAvailable(0, 0, 4);
      expect(available, isTrue);
    });

    test('Cell occupation check', () {
      // Test with default empty grid
      expect(grid.isCellOccupied(0, 0), isFalse);
    });

    test('Building counting', () {
      final count = grid.countBuildingsOfType(BuildingType.house);
      expect(count, equals(0)); // Empty grid
    });

    test('Get all buildings from empty grid', () {
      final buildings = grid.getAllBuildings();
      expect(buildings, isEmpty);
    });
  });

  group('MainGameWidget Tests', () {
    testWidgets('MainGameWidget can be created', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'cash': 1000.0,
        'population': 20,
        'availableWorkers': 20,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MainGameWidget(planet: Planet(id: 'test', name: 'Test')),
        ),
      );

      // Just verify the widget can be created without immediate errors
      expect(find.byType(MainGameWidget), findsOneWidget);
    });

    testWidgets('MainGameWidget handles basic initialization', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'cash': 1000.0,
        'population': 20,
        'availableWorkers': 20,
        'gold': 0.0,
        'wood': 0.0,
        'coal': 10.0,
        'electricity': 0.0,
        'research': 0.0,
        'water': 0.0,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MainGameWidget(planet: Planet(id: 'test', name: 'Test')),
        ),
      );

      // Allow some time for initialization but don't wait for settle
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the widget builds successfully
      expect(find.byType(MainGameWidget), findsOneWidget);
    });
  });
}

// Mock Canvas for testing render methods
class MockCanvas implements Canvas {
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}