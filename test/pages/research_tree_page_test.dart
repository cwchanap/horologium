import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/pages/research_tree_page.dart';

void main() {
  group('ResearchTreePage', () {
    late ResearchManager researchManager;
    late Resources resources;
    late BuildingLimitManager buildingLimitManager;
    late int resourcesChangedCalls;

    setUp(() {
      researchManager = ResearchManager();
      resources = Resources();
      buildingLimitManager = BuildingLimitManager();
      resourcesChangedCalls = 0;
    });

    Future<void> pumpResearchTreePage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResearchTreePage(
            researchManager: researchManager,
            resources: resources,
            buildingLimitManager: buildingLimitManager,
            onResourcesChanged: () => resourcesChangedCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder researchCard(String title) {
      return find
          .ancestor(
            of: find.text(title),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          )
          .first;
    }

    testWidgets('shows locked prerequisites for advanced construction', (
      tester,
    ) async {
      resources.research = 100;

      await pumpResearchTreePage(tester);
      await tester.scrollUntilVisible(find.text('Advanced Construction'), 200);

      expect(
        find.descendant(
          of: researchCard('Advanced Construction'),
          matching: find.text('Locked'),
        ),
        findsOneWidget,
      );
      expect(find.text('Prerequisites Required:'), findsOneWidget);
      expect(find.text('Expansion Planning'), findsWidgets);
    });

    testWidgets(
      'shows not enough state when prerequisites are met but points are low',
      (tester) async {
        researchManager.completeResearch(ResearchType.electricity);
        resources.research = 0;

        await pumpResearchTreePage(tester);
        await tester.scrollUntilVisible(find.text('Modern Housing'), 200);

        expect(
          find.descendant(
            of: researchCard('Modern Housing'),
            matching: find.text('Not Enough'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('completed research shows completed state', (tester) async {
      researchManager.completeResearch(ResearchType.electricity);
      resources.research = 100;

      await pumpResearchTreePage(tester);

      expect(
        find.descendant(
          of: researchCard('Electricity'),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'researching expansion planning deducts points and raises limits',
      (tester) async {
        resources.research = 100;
        final initialHouseLimit = buildingLimitManager.getBuildingLimit(
          BuildingType.house,
        );

        await pumpResearchTreePage(tester);
        await tester.scrollUntilVisible(find.text('Expansion Planning'), 200);
        final button = find.descendant(
          of: researchCard('Expansion Planning'),
          matching: find.widgetWithText(ElevatedButton, 'Research'),
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();

        await tester.tap(button, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          researchManager.isResearched(ResearchType.expansionPlanning),
          isTrue,
        );
        expect(resources.research, 85);
        expect(
          buildingLimitManager.getBuildingLimit(BuildingType.house),
          initialHouseLimit + 2,
        );
        expect(resourcesChangedCalls, 1);
        expect(
          find.text('Research completed: Expansion Planning'),
          findsOneWidget,
        );
      },
    );

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ResearchTreePage(
                          researchManager: researchManager,
                          resources: resources,
                          buildingLimitManager: buildingLimitManager,
                          onResourcesChanged: () => resourcesChangedCalls++,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Research Tree'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
    });
  });
}
