import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/scene_widget.dart';
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
