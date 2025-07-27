import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/building_selection_panel.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/research.dart';
import 'package:horologium/game/grid.dart';

void main() {
  group('BuildingSelectionPanel Widget Tests', () {
    late ResearchManager testResearchManager;
    late BuildingLimitManager testBuildingLimitManager;
    late Grid testGrid;
    bool panelClosed = false;
    Building? selectedBuilding;

    setUp(() {
      testResearchManager = ResearchManager();
      testBuildingLimitManager = BuildingLimitManager();
      testGrid = Grid();
      panelClosed = false;
      selectedBuilding = null;
    });

    testWidgets('does not render when not visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: false,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.text('Select Building (5, 3)'), findsNothing);
    });

    testWidgets('renders correctly when visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.text('Select Building (5, 3)'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays grid coordinates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 10,
              selectedGridY: 7,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.text('Select Building (10, 7)'), findsOneWidget);
    });

    testWidgets('calls onClose when close button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(panelClosed, isTrue);
    });

    testWidgets('has TabBar with building categories', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
      
      // Should have tabs for each building category
      expect(find.byType(Tab), findsNWidgets(BuildingCategory.values.length));
    });

    testWidgets('displays building cards in grid view', (WidgetTester tester) async {
      // Unlock some research to have buildings available
      testResearchManager.completeResearch('electricity');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsAtLeastNWidgets(1));
    });

    testWidgets('shows "No buildings" message for empty categories', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      // Should show "No buildings in this category" for categories without available buildings
      expect(find.text('No buildings in this category'), findsAtLeastNWidgets(1));
    });

    testWidgets('has correct layout structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      // Check positioned widget
      expect(find.byType(Positioned), findsOneWidget);
      
      // Check main column structure
      expect(find.byType(Column), findsOneWidget);
      
      // Check container decoration
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('panel takes 50% of screen height', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: 5,
              selectedGridY: 3,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      // Check that the panel is positioned at the bottom and takes up space
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.bottom, equals(0));
      expect(positioned.left, equals(0));
      expect(positioned.right, equals(0));
    });

    testWidgets('handles null grid coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingSelectionPanel(
              isVisible: true,
              selectedGridX: null,
              selectedGridY: null,
              onClose: () => panelClosed = true,
              onBuildingSelected: (building) => selectedBuilding = building,
              researchManager: testResearchManager,
              buildingLimitManager: testBuildingLimitManager,
              grid: testGrid,
            ),
          ),
        ),
      );

      expect(find.text('Select Building (null, null)'), findsOneWidget);
    });
  });
}