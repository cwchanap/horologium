import '../research/research.dart';
import '../resources/resources.dart';
import '../services/save_service.dart';

/// Legacy wrapper for SaveService - use SaveService directly for new code
class PersistenceManager {
  static Future<void> loadSavedData(Resources resources, ResearchManager researchManager) async {
    await SaveService.loadGameState(
      resources: resources,
      researchManager: researchManager,
    );
  }

  static Future<void> saveResources(Resources resources, ResearchManager researchManager) async {
    await SaveService.saveGameState(
      resources: resources,
      researchManager: researchManager,
    );
  }
}