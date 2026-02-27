import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('AchievementManager', () {
    late AchievementManager manager;

    setUp(() {
      manager = AchievementManager(
        achievements: [
          Achievement(
            id: 'ach_first_building',
            name: 'Foundation',
            description: 'Place your first building',
            type: AchievementType.buildingCount,
            targetAmount: 1,
          ),
          Achievement(
            id: 'ach_builder_10',
            name: 'Builder',
            description: 'Place 10 buildings',
            type: AchievementType.buildingCount,
            targetAmount: 10,
          ),
          Achievement(
            id: 'ach_population_50',
            name: 'Small Town',
            description: 'Reach 50 population',
            type: AchievementType.populationReached,
            targetAmount: 50,
          ),
          Achievement(
            id: 'ach_rich',
            name: 'Wealthy',
            description: 'Accumulate 10000 cash',
            type: AchievementType.resourceAccumulated,
            targetAmount: 10000,
            targetId: 'cash',
          ),
          Achievement(
            id: 'ach_all_research',
            name: 'Scholar',
            description: 'Complete all research',
            type: AchievementType.researchCompleted,
            targetAmount: ResearchType.values.length,
          ),
          Achievement(
            id: 'ach_happiness_90',
            name: 'Utopia',
            description: 'Achieve 90+ happiness',
            type: AchievementType.happinessReached,
            targetAmount: 90,
          ),
        ],
      );
    });

    test('getAll returns all achievements', () {
      expect(manager.getAll(), hasLength(6));
    });

    test('no achievements unlocked initially', () {
      expect(manager.getUnlocked(), isEmpty);
    });

    group('checkProgress', () {
      test('unlocks building count achievement', () {
        final buildings = List.generate(
          1,
          (_) => Building(
            type: BuildingType.house,
            name: 'House',
            description: 'A house',
            icon: const IconData(0),
            color: const Color(0xFF000000),
            baseCost: 100,
            category: BuildingCategory.residential,
          ),
        );

        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(manager.getUnlocked(), hasLength(1));
        expect(manager.getUnlocked().first.id, 'ach_first_building');
      });

      test('unlocks population achievement', () {
        final resources = Resources();
        resources.population = 50;

        manager.checkProgress(resources, [], ResearchManager());

        expect(
          manager.getUnlocked().any((a) => a.id == 'ach_population_50'),
          isTrue,
        );
      });

      test('unlocks resource accumulation achievement', () {
        final resources = Resources();
        resources.resources[ResourceType.cash] = 10000;

        manager.checkProgress(resources, [], ResearchManager());

        expect(manager.getUnlocked().any((a) => a.id == 'ach_rich'), isTrue);
      });

      test('unlocks happiness achievement', () {
        final resources = Resources();
        resources.happiness = 92;

        manager.checkProgress(resources, [], ResearchManager());

        expect(
          manager.getUnlocked().any((a) => a.id == 'ach_happiness_90'),
          isTrue,
        );
      });

      test('does not unlock when target not reached', () {
        final resources = Resources();
        resources.population = 30;

        manager.checkProgress(resources, [], ResearchManager());

        expect(
          manager.getUnlocked().any((a) => a.id == 'ach_population_50'),
          isFalse,
        );
      });

      test('fires onAchievementUnlocked callback', () {
        Achievement? unlocked;
        manager.onAchievementUnlocked = (a) => unlocked = a;

        final buildings = [
          Building(
            type: BuildingType.house,
            name: 'House',
            description: 'A house',
            icon: const IconData(0),
            color: const Color(0xFF000000),
            baseCost: 100,
            category: BuildingCategory.residential,
          ),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(unlocked, isNotNull);
        expect(unlocked!.id, 'ach_first_building');
      });

      test('does not fire callback for already unlocked achievement', () {
        int callCount = 0;
        manager.onAchievementUnlocked = (_) => callCount++;

        final buildings = [
          Building(
            type: BuildingType.house,
            name: 'House',
            description: 'A house',
            icon: const IconData(0),
            color: const Color(0xFF000000),
            baseCost: 100,
            category: BuildingCategory.residential,
          ),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(callCount, 1);
      });
    });

    group('serialization', () {
      test('toJson and loadFromJson round-trip', () {
        // Unlock an achievement
        final buildings = [
          Building(
            type: BuildingType.house,
            name: 'House',
            description: 'A house',
            icon: const IconData(0),
            color: const Color(0xFF000000),
            baseCost: 100,
            category: BuildingCategory.residential,
          ),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        final json = manager.toJson();

        // Create fresh manager and restore
        final restored = AchievementManager(
          achievements: [
            Achievement(
              id: 'ach_first_building',
              name: 'Foundation',
              description: 'Place your first building',
              type: AchievementType.buildingCount,
              targetAmount: 1,
            ),
            Achievement(
              id: 'ach_builder_10',
              name: 'Builder',
              description: 'Place 10 buildings',
              type: AchievementType.buildingCount,
              targetAmount: 10,
            ),
          ],
        );
        restored.loadFromJson(json);

        expect(restored.getUnlocked(), hasLength(1));
        expect(restored.getUnlocked().first.id, 'ach_first_building');
      });

      test('loadFromJson handles empty data', () {
        manager.loadFromJson({});

        expect(manager.getUnlocked(), isEmpty);
      });

      test('loadFromJson ignores unknown achievement IDs', () {
        manager.loadFromJson({
          'unlocked': ['unknown_achievement'],
          'progress': {'unknown_achievement': 5},
        });

        expect(manager.getUnlocked(), isEmpty);
      });
    });
  });
}
