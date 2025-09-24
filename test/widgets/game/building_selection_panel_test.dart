import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/building_selection_panel.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/grid.dart';

void main() {
  group('BuildingSelectionPanel Widget Tests', () {
    late ResearchManager testResearchManager;
    late BuildingLimitManager testBuildingLimitManager;
    late Grid testGrid;
    bool panelClosed = false;
    // selectedBuilding variable removed; we only verify callback invocations indirectly

    setUp(() {
      testResearchManager = ResearchManager();
      testBuildingLimitManager = BuildingLimitManager();
      testGrid = Grid();
      panelClosed = false;
    });

    testWidgets('does not render when not visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BuildingSelectionPanel(
                  isVisible: false,
                  selectedGridX: 5,
                  selectedGridY: 3,
                  onClose: () => panelClosed = true,
                  onBuildingSelected: (_) {},
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                ),
              ],
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
            body: Stack(
              children: [
                BuildingSelectionPanel(
                  isVisible: true,
                  selectedGridX: 5,
                  selectedGridY: 3,
                  onClose: () => panelClosed = true,
                  onBuildingSelected: (_) {},
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Select Building (5, 3)'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays grid coordinates correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BuildingSelectionPanel(
                  isVisible: true,
                  selectedGridX: 10,
                  selectedGridY: 7,
                  onClose: () => panelClosed = true,
                  onBuildingSelected: (_) {},
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Select Building (10, 7)'), findsOneWidget);
    });

    testWidgets('calls onClose when close button is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BuildingSelectionPanel(
                  isVisible: true,
                  selectedGridX: 5,
                  selectedGridY: 3,
                  onClose: () => panelClosed = true,
                  onBuildingSelected: (_) {},
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(panelClosed, isTrue);
    });

    testWidgets('has TabBar with building categories', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                BuildingSelectionPanel(
                  isVisible: true,
                  selectedGridX: 5,
                  selectedGridY: 3,
                  onClose: () => panelClosed = true,
                  onBuildingSelected: (_) {},
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      // Should have tabs for each building category
      expect(find.byType(Tab), findsNWidgets(BuildingCategory.values.length));
    });
  });
}
