import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

/// Performance tests are skipped in CI due to inherent timing flakiness.
/// Run locally with: flutter test test/performance/quest_perf_test.dart
final _skipInCi = kIsWeb || Platform.environment['CI']?.toLowerCase() == 'true';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group(
    'Performance: quest check ≤5ms per quest (NFR-QST-001)',
    skip: _skipInCi,
    () {
      test('checkProgress on 50 quests completes within 250ms (5ms each)', () {
        // Build 50 quests
        final quests = <Quest>[];
        for (int i = 0; i < 50; i++) {
          quests.add(
            Quest(
              id: 'perf_$i',
              name: 'Perf Quest $i',
              description: 'Performance test quest $i',
              objectives: [
                QuestObjective(
                  type: QuestObjectiveType.buildBuilding,
                  targetId: 'house',
                  targetAmount: i + 1,
                ),
                QuestObjective(
                  type: QuestObjectiveType.accumulateResource,
                  targetId: 'cash',
                  targetAmount: (i + 1) * 100,
                ),
              ],
              reward: QuestReward(resources: {ResourceType.cash: 100}),
              status: QuestStatus.active,
            ),
          );
        }

        final manager = QuestManager(quests: quests);
        final resources = Resources();
        resources.resources[ResourceType.cash] = 5000;

        // Simulate 20 buildings
        final buildings = <Building>[];
        final houseDef = BuildingRegistry.availableBuildings.firstWhere(
          (b) => b.type == BuildingType.house,
        );
        for (int i = 0; i < 20; i++) {
          buildings.add(
            Building(
              type: houseDef.type,
              name: houseDef.name,
              description: houseDef.description,
              icon: houseDef.icon,
              assetPath: houseDef.assetPath,
              color: houseDef.color,
              baseCost: houseDef.baseCost,
              baseGeneration: Map.of(houseDef.baseGeneration),
              baseConsumption: Map.of(houseDef.baseConsumption),
              requiredWorkers: houseDef.requiredWorkers,
              category: houseDef.category,
            ),
          );
        }

        final researchManager = ResearchManager();

        // Warm up
        manager.checkProgress(resources, buildings, researchManager);

        // Measure
        final sw = Stopwatch()..start();
        const iterations = 100;
        for (int i = 0; i < iterations; i++) {
          manager.checkProgress(resources, buildings, researchManager);
        }
        sw.stop();

        final avgMs = sw.elapsedMilliseconds / iterations;
        debugPrint(
          'Quest checkProgress (50 quests): ${avgMs.toStringAsFixed(2)}ms avg over $iterations iterations',
        );

        // NFR-QST-001: ≤5ms per quest → 250ms for 50 quests
        expect(
          avgMs,
          lessThan(250),
          reason: 'checkProgress on 50 quests should be under 250ms',
        );
      });

      test('achievement checkProgress on 50 achievements within 250ms', () {
        final achievements = <Achievement>[];
        for (int i = 0; i < 50; i++) {
          achievements.add(
            Achievement(
              id: 'perf_ach_$i',
              name: 'Perf Achievement $i',
              description: 'Performance test achievement $i',
              type: AchievementType.buildingCount,
              targetAmount: i + 10,
            ),
          );
        }

        final manager = AchievementManager(achievements: achievements);
        final resources = Resources();
        final buildings = <Building>[];
        final researchManager = ResearchManager();

        // Warm up
        manager.checkProgress(resources, buildings, researchManager);

        final sw = Stopwatch()..start();
        const iterations = 100;
        for (int i = 0; i < iterations; i++) {
          manager.checkProgress(resources, buildings, researchManager);
        }
        sw.stop();

        final avgMs = sw.elapsedMilliseconds / iterations;
        debugPrint(
          'Achievement checkProgress (50 achievements): ${avgMs.toStringAsFixed(2)}ms avg over $iterations iterations',
        );

        expect(
          avgMs,
          lessThan(250),
          reason: 'checkProgress on 50 achievements should be under 250ms',
        );
      });
    },
  );

  // NFR-QST-003 (QuestLogPage cold start ≤500ms) is NOT enforced here.
  // Wall-clock `pumpWidget` timing in flutter_test debug mode is dominated by
  // framework/JIT overhead and scheduler contention, not QuestLogPage code:
  // observed cold builds range from ~250ms to ~3.6s on the same machine
  // depending on load, and even warmed median builds exceed 500ms under load.
  // A wall-clock test cannot honestly gate a 500ms production cold-start NFR.
  // Validate NFR-QST-003 via release-build profiling or an integration test
  // on an AOT build, not via this local-only flutter_test wall-clock harness.
}
