import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/hamburger_menu.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';

void main() {
  group('HamburgerMenu Widget Tests', () {
    late Resources testResources;
    late ResearchManager testResearchManager;
    late BuildingLimitManager testBuildingLimitManager;
    late Grid testGrid;
    bool menuClosed = false;

    setUp(() {
      testResources = Resources();
      testResearchManager = ResearchManager();
      testBuildingLimitManager = BuildingLimitManager();
      testGrid = Grid();
      menuClosed = false;
      
    });

    testWidgets('does not render when not visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: false,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.text('Research Tree'), findsNothing);
    });

    testWidgets('renders all menu items when visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Research Tree'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Trade'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('displays correct icons for each menu item', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.science), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onClose when Close item is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Close'));
      await tester.pump();

      expect(menuClosed, isTrue);
    });

    testWidgets('navigates to Research Tree page when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Research Tree'));
      await tester.pumpAndSettle();

      expect(menuClosed, isTrue); // Should close menu before navigating
    });

    testWidgets('navigates to Resources page when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      expect(menuClosed, isTrue); // Should close menu before navigating
    });

    testWidgets('navigates to Trade page when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trade'));
      await tester.pumpAndSettle();

      expect(menuClosed, isTrue); // Should close menu before navigating
    });

    testWidgets('has correct styling and layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Check that it's positioned correctly
      expect(find.byType(Positioned), findsOneWidget);
      
      // Check container styling
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
      
      // Check that there are ListTiles for each menu item (Research, Resources, Trade, Planet Selection, Close)
      expect(find.byType(ListTile), findsNWidgets(5));
      
      // Check that there are Dividers between items
      expect(find.byType(Divider), findsNWidgets(4));
    });

    testWidgets('has correct width', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HamburgerMenu(
                  isVisible: true,
                  onClose: () => menuClosed = true,
                  resources: testResources,
                  researchManager: testResearchManager,
                  buildingLimitManager: testBuildingLimitManager,
                  grid: testGrid,
                  onResourcesChanged: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Check that the menu is positioned correctly
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.bottom, equals(80));
      expect(positioned.right, equals(20));
    });
  });
}