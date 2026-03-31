import '../building/building.dart';
import '../grid.dart';

abstract interface class GameManagerContext {
  Grid get grid;
  Building? get buildingToPlace;
  set buildingToPlace(Building? value);
  void hidePlacementPreview();
}
