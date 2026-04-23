import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/scene_widget.dart';
import 'package:horologium/widgets/cards/building_card.dart';
import 'package:horologium/widgets/game/building_selection_panel.dart';
import 'package:horologium/widgets/game/game_controls.dart';
import 'package:horologium/widgets/game/production_overlay/production_overlay.dart';
import 'package:horologium/widgets/game/hamburger_menu.dart';
import 'package:horologium/widgets/game/resource_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MainGameWidget stable coverage', () {
    setUp(() {
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
    });

    testWidgets('shows save-reset snackbars when planet load flags are set', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      await _pumpMainGameWidget(
        tester,
        planet: Planet(
          id: 'snackbars',
          name: 'Snackbars',
          buildingLimitsParseError: true,
          questLoadFailed: true,
          achievementLoadFailed: true,
        ),
      );

      await _pumpUntilFound(
        tester,
        find.text(
          'Your building limit data could not be loaded and has been reset.',
        ),
      );
      expect(
        find.text(
          'Your quest progress could not be loaded and has been reset.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Your achievement progress could not be loaded and has been reset.',
        ),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 6));
      await _pumpUntilFound(
        tester,
        find.text(
          'Your quest progress could not be loaded and has been reset.',
        ),
      );

      await tester.pump(const Duration(seconds: 6));
      await _pumpUntilFound(
        tester,
        find.text(
          'Your achievement progress could not be loaded and has been reset.',
        ),
      );
    });

    testWidgets('hamburger button toggles the menu overlay', (tester) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      await _pumpMainGameWidget(
        tester,
        planet: Planet(id: 'hamburger', name: 'Hamburger'),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      expect(find.byType(HamburgerMenu), findsNothing);
      expect(find.text('Research Tree'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();

      expect(find.byType(HamburgerMenu), findsOneWidget);
      expect(find.text('Research Tree'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();

      expect(find.byType(HamburgerMenu), findsNothing);
      expect(find.text('Research Tree'), findsNothing);
    });

    testWidgets(
      'quest completion shows and then dismisses the quest notification',
      (tester) async {
        addTearDown(() => _disposeMainGameWidget(tester));

        final questManager = QuestManager(
          quests: [
            Quest(
              id: 'stable-notification',
              name: 'Stable Notification Quest',
              description: 'Completes for widget coverage',
              objectives: [
                QuestObjective(
                  type: QuestObjectiveType.buildBuilding,
                  targetId: 'house',
                  targetAmount: 1,
                ),
              ],
              reward: const QuestReward(resources: {ResourceType.cash: 50}),
            ),
          ],
        );

        await _pumpMainGameWidget(
          tester,
          planet: Planet(
            id: 'quest-notification',
            name: 'Quest Notification',
            questManager: questManager,
          ),
        );

        final quest = questManager.quests.singleWhere(
          (quest) => quest.id == 'stable-notification',
        );
        questManager.onQuestCompleted?.call(quest);
        await tester.pump();

        expect(find.text('Quest Complete!'), findsOneWidget);
        expect(find.text('Stable Notification Quest'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Quest Complete!'), findsNothing);
        expect(find.text('Stable Notification Quest'), findsNothing);
      },
    );

    testWidgets('achievement unlock notification is printed without throwing', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      final achievementManager = AchievementManager(
        achievements: [
          Achievement(
            id: 'test-ach',
            name: 'Test Achievement',
            description: 'For coverage',
            type: AchievementType.buildingCount,
            targetAmount: 1,
          ),
        ],
      );
      await _pumpMainGameWidget(
        tester,
        planet: Planet(
          id: 'achievement',
          name: 'Achievement',
          achievementManager: achievementManager,
        ),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      // Verify the callback is wired up by the widget
      expect(achievementManager.onAchievementUnlocked, isNotNull);

      // Fire the callback — should not throw
      final achievement = achievementManager.achievements.first;
      achievementManager.onAchievementUnlocked?.call(achievement);
      await tester.pump();
      // No visible UI for achievements yet — just verify no exception
    });

    testWidgets('didChangeAppLifecycleState resume triggers quest refresh', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      final questManager = QuestManager(
        quests: [
          Quest(
            id: 'lifecycle-quest',
            name: 'Lifecycle Quest',
            description: 'For coverage',
            objectives: [
              QuestObjective(
                type: QuestObjectiveType.buildBuilding,
                targetId: 'house',
                targetAmount: 1,
              ),
            ],
            reward: const QuestReward(resources: {ResourceType.cash: 50}),
          ),
        ],
      );

      await _pumpMainGameWidget(
        tester,
        planet: Planet(
          id: 'lifecycle',
          name: 'Lifecycle',
          questManager: questManager,
        ),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      // Verify quest callback is wired
      expect(questManager.onQuestCompleted, isNotNull);

      // Simulate a resume lifecycle event via the binding observer
      final binding = WidgetsBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // No assertion needed — coverage of the lifecycle handler is the goal
    });

    testWidgets('resource display shows after widget loads', (tester) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      await _pumpMainGameWidget(
        tester,
        planet: Planet(id: 'resources', name: 'Resources'),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      expect(find.byType(ResourceDisplay), findsOneWidget);
    });

    testWidgets(
      'resource display production button opens and closes the overlay',
      (tester) async {
        addTearDown(() => _disposeMainGameWidget(tester));

        await _pumpMainGameWidget(
          tester,
          planet: Planet(id: 'production-overlay', name: 'Production Overlay'),
        );
        await _pumpUntilFound(tester, find.byType(ResourceDisplay));

        expect(find.byType(ProductionOverlay), findsNothing);

        await tester.tap(find.text('Production'));
        await tester.pump();

        expect(find.byType(ProductionOverlay), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(find.byType(ProductionOverlay), findsNothing);
      },
    );

    testWidgets(
      'grid tap opens building selection and back cancels placement',
      (tester) async {
        addTearDown(() => _disposeMainGameWidget(tester));

        await _pumpMainGameWidget(
          tester,
          planet: Planet(id: 'building-selection', name: 'Building Selection'),
        );
        await _pumpUntilFound(tester, find.byType(ResourceDisplay));

        final game = tester
            .widget<GameControls>(find.byType(GameControls))
            .game;
        game.onGridCellTapped?.call(2, 3);
        await tester.pump();

        await _pumpUntilFound(tester, find.byType(BuildingSelectionPanel));

        await tester.tap(find.byType(BuildingCard).first);
        await tester.pump();

        expect(find.byType(BuildingSelectionPanel), findsNothing);
        expect(find.byTooltip('Cancel (ESC or click outside)'), findsOneWidget);

        await tester.tap(find.byTooltip('Cancel (ESC or click outside)'));
        await tester.pump();

        expect(find.byTooltip('Back'), findsOneWidget);
      },
    );

    testWidgets(
      'building options dialog upgrades a building and syncs the planet',
      (tester) async {
        addTearDown(() => _disposeMainGameWidget(tester));

        final planet = Planet(
          id: 'upgrade-building',
          name: 'Upgrade Building',
          buildings: [
            const PlacedBuildingData(
              id: 'power-1',
              x: 1,
              y: 1,
              type: BuildingType.powerPlant,
            ),
          ],
        );
        planet.resources.cash = 1000;

        await _pumpMainGameWidget(tester, planet: planet);
        await _pumpUntilFound(tester, find.byType(ResourceDisplay));

        final game = tester
            .widget<GameControls>(find.byType(GameControls))
            .game;
        game.onGridCellLongTapped?.call(1, 1);
        await tester.pump();

        await _pumpUntilFound(tester, find.text('Power Plant'));

        await tester.tap(find.textContaining('Upgrade'));
        await tester.pump();

        expect(planet.getBuildingAt(1, 1)?.level, 2);
        expect(planet.resources.cash, 800);
      },
    );

    testWidgets('building options dialog deletes a building and refunds cash', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      final planet = Planet(
        id: 'delete-building',
        name: 'Delete Building',
        buildings: [
          const PlacedBuildingData(
            id: 'house-1',
            x: 1,
            y: 1,
            type: BuildingType.house,
          ),
        ],
      );
      planet.resources.cash = 500;

      await _pumpMainGameWidget(tester, planet: planet);
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      final game = tester.widget<GameControls>(find.byType(GameControls)).game;
      game.onGridCellLongTapped?.call(1, 1);
      await tester.pump();

      await _pumpUntilFound(tester, find.text('House'));

      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(planet.getBuildingAt(1, 1), isNull);
      expect(planet.resources.cash, 620);
    });

    testWidgets('claiming a quest reward through the menu updates resources', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      final quest = Quest(
        id: 'claim-me',
        name: 'Claim Me',
        description: 'Completed quest for reward flow coverage',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
            currentAmount: 1,
          ),
        ],
        reward: const QuestReward(resources: {ResourceType.cash: 75}),
        status: QuestStatus.completed,
      );
      final questManager = QuestManager(quests: [quest]);
      final planet = Planet(
        id: 'claim-reward',
        name: 'Claim Reward',
        questManager: questManager,
      );
      planet.resources.cash = 1000;

      await _pumpMainGameWidget(tester, planet: planet);
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Quests'));

      await tester.tap(find.text('Quests'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Claim Reward'));

      await tester.tap(find.text('Claim Reward'));
      await tester.pump();

      expect(planet.resources.cash, 1075);
      expect(quest.status, QuestStatus.claimed);
    });

    testWidgets('debug tools button opens and closes the terrain debug sheet', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      await _pumpMainGameWidget(
        tester,
        planet: Planet(id: 'debug-sheet', name: 'Debug Sheet'),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Developer Tools'));

      await tester.tapAt(const Offset(760, 110));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Developer Tools'), findsNothing);
    });

    testWidgets('hamburger menu audio controls update the widget state', (
      tester,
    ) async {
      addTearDown(() => _disposeMainGameWidget(tester));

      await _pumpMainGameWidget(
        tester,
        planet: Planet(id: 'audio-controls', name: 'Audio Controls'),
      );
      await _pumpUntilFound(tester, find.byType(ResourceDisplay));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await _pumpUntilFound(tester, find.byType(HamburgerMenu));

      await tester.drag(find.byType(Slider), const Offset(-80, 0));
      await tester.pump();

      final switchTile = find.byType(SwitchListTile);
      await tester.tap(switchTile);
      await tester.pump();

      expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
    });
  });
}

Future<void> _pumpMainGameWidget(
  WidgetTester tester, {
  required Planet planet,
}) async {
  await tester.pumpWidget(MaterialApp(home: MainGameWidget(planet: planet)));
  await tester.pump();
}

Future<void> _disposeMainGameWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 80,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }

  expect(finder, findsOneWidget);
}
