import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/services/building_service.dart';

void main() {
  group('BuildingService.getAvailableBuildings', () {
    late ResearchManager researchManager;

    setUp(() {
      researchManager = ResearchManager();
    });

    test(
      'returns non-research-gated buildings regardless of research state',
      () {
        // With no research completed, only buildings that are NOT behind
        // research gates should be available.
        final available = BuildingService.getAvailableBuildings(
          researchManager,
        );

        // Research-gated types should not appear
        final types = available.map((b) => b.type).toSet();
        expect(types, isNot(contains(BuildingType.powerPlant)));
        expect(types, isNot(contains(BuildingType.goldMine)));
      },
    );

    test('includes power plant after electricity research', () {
      researchManager.completeResearch(ResearchType.electricity);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.powerPlant));
    });

    test('includes gold mine after gold mining research', () {
      researchManager.completeResearch(ResearchType.goldMining);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.goldMine));
    });

    test('includes large house after modern housing research', () {
      researchManager.completeResearch(ResearchType.modernHousing);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.largeHouse));
    });

    test('includes grain buildings after grain processing research', () {
      researchManager.completeResearch(ResearchType.grainProcessing);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.windMill));
      expect(types, contains(BuildingType.grinderMill));
    });

    test('includes advanced grain buildings after advanced grain research', () {
      researchManager.completeResearch(ResearchType.advancedGrainProcessing);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.riceHuller));
      expect(types, contains(BuildingType.maltHouse));
    });

    test('includes bakery after food processing research', () {
      researchManager.completeResearch(ResearchType.foodProcessing);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.bakery));
    });

    test('unlocking multiple researches accumulates available buildings', () {
      researchManager.completeResearch(ResearchType.electricity);
      researchManager.completeResearch(ResearchType.goldMining);
      final available = BuildingService.getAvailableBuildings(researchManager);
      final types = available.map((b) => b.type).toSet();
      expect(types, contains(BuildingType.powerPlant));
      expect(types, contains(BuildingType.goldMine));
    });

    test('all researches completed exposes full building list', () {
      for (final type in ResearchType.values) {
        researchManager.completeResearch(type);
      }
      final available = BuildingService.getAvailableBuildings(researchManager);
      // Should include all buildings from BuildingRegistry
      expect(
        available.length,
        equals(BuildingRegistry.availableBuildings.length),
      );
    });

    test(
      'returns list that is a subset of BuildingRegistry.availableBuildings',
      () {
        final available = BuildingService.getAvailableBuildings(
          researchManager,
        );
        final allTypes = BuildingRegistry.availableBuildings
            .map((b) => b.type)
            .toSet();
        for (final building in available) {
          expect(allTypes, contains(building.type));
        }
      },
    );
  });

  group('BuildingService research gating invariant', () {
    test('research-gated buildings only appear when unlocked', () {
      // Every building that is listed in some research.unlocksBuildings
      // should NOT appear without that research, and SHOULD appear with it.
      for (final research in Research.availableResearch) {
        if (research.unlocksBuildings.isEmpty) continue;

        final managerWithout = ResearchManager();
        final withoutResearch = BuildingService.getAvailableBuildings(
          managerWithout,
        );
        final withoutTypes = withoutResearch.map((b) => b.type).toSet();

        final managerWith = ResearchManager();
        managerWith.completeResearch(research.type);
        final withResearch = BuildingService.getAvailableBuildings(managerWith);
        final withTypes = withResearch.map((b) => b.type).toSet();

        for (final buildingType in research.unlocksBuildings) {
          expect(
            withoutTypes,
            isNot(contains(buildingType)),
            reason:
                '$buildingType should not be available without ${research.type}',
          );
          expect(
            withTypes,
            contains(buildingType),
            reason:
                '$buildingType should be available after ${research.type} is completed',
          );
        }
      }
    });
  });
}
