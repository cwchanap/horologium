import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/managers/game_manager_context.dart';

class TestGameManagerContext implements GameManagerContext {
  @override
  // Safe in these tests because manager paths only exercise Grid occupancy
  // and dialog state, never a mounted Flame game.
  final Grid grid = Grid();

  @override
  Building? buildingToPlace;

  int hidePlacementPreviewCallCount = 0;

  @override
  void hidePlacementPreview() {
    hidePlacementPreviewCallCount++;
  }
}
