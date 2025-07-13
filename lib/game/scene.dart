import 'dart:async' as async;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:horologium/game/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'building.dart';
import 'grid.dart';

class MainGame extends FlameGame
    with
        flame_events.TapCallbacks,
        flame_events.DragCallbacks,
        flame_events.PointerMoveCallbacks {
  late Grid _grid;
  Function(int, int)? onGridCellTapped;
  Function(int, int)? onGridCellLongTapped;
  Function(int, int)? onGridCellSecondaryTapped;
  Function(Vector2)? onPointerMoveCallback;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  final double _startZoom = _minZoom;

  Building? buildingToPlace;
  final PlacementPreview placementPreview = PlacementPreview();

  MainGame();

  Grid get grid => _grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    _grid = Grid();
    _grid.size =
        Vector2(_grid.gridSize * cellWidth, _grid.gridSize * cellHeight);
    _grid.anchor = Anchor.center;
    world.add(_grid);
    await loadBuildings();
  }

  Future<void> loadBuildings() async {
    final prefs = await SharedPreferences.getInstance();
    final buildingData = prefs.getStringList('buildings');
    if (buildingData == null) {
      return;
    }

    for (final data in buildingData) {
      final parts = data.split(',');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);
      final buildingName = parts[2];

      final building = Building.availableBuildings
          .firstWhere((b) => b.name == buildingName, orElse: () {
        return Building.powerPlant2;
      });
      _grid.placeBuilding(x, y, building);
    }
  }

  @override
  void onDragUpdate(flame_events.DragUpdateEvent event) {
    camera.viewfinder.position -= event.canvasDelta / camera.viewfinder.zoom;
  }

  @override
  void onPointerMove(flame_events.PointerMoveEvent event) {
    super.onPointerMove(event);
    onPointerMoveCallback?.call(event.canvasPosition);
  }

  @override
  void onTapUp(flame_events.TapUpEvent event) {
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid.toLocal(worldPosition);
    final gridPosition = _grid.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellTapped?.call(gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  @override
  void onLongTapDown(flame_events.TapDownEvent event) {
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid.toLocal(worldPosition);
    final gridPosition = _grid.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellLongTapped?.call(
          gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  @override
  void onSecondaryTapUp(flame_events.TapUpEvent event) {
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid.toLocal(worldPosition);
    final gridPosition = _grid.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellSecondaryTapped?.call(
          gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
  }

  void showPlacementPreview(Building building, int x, int y) {
    if (!world.contains(placementPreview)) {
      world.add(placementPreview);
    }
    placementPreview.updatePreview(
        building, x, y, _grid.isAreaAvailable(x, y, building.gridSize));
  }

  void hidePlacementPreview() {
    if (world.contains(placementPreview)) {
      world.remove(placementPreview);
    }
  }
}

class PlacementPreview extends PositionComponent {
  Building? building;
  bool isValid = false;

  void updatePreview(Building building, int gridX, int gridY, bool isValid) {
    this.building = building;
    this.isValid = isValid;
    x = (gridX * cellWidth).toDouble();
    y = (gridY * cellHeight).toDouble();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (building == null) {
      return;
    }

    final buildingSize = sqrt(building!.gridSize).toInt();
    final paint = Paint()
      ..color = (isValid ? Colors.green : Colors.red).withAlpha(100)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(
      0,
      0,
      (cellWidth * buildingSize).toDouble(),
      (cellHeight * buildingSize).toDouble(),
    );
    canvas.drawRect(rect, paint);
  }
}

class MainGameWidget extends StatefulWidget {
  const MainGameWidget({super.key});

  @override
  State<MainGameWidget> createState() => _MainGameWidgetState();
}

class _MainGameWidgetState extends State<MainGameWidget> {
  late MainGame _game;
  int? _selectedGridX;
  int? _selectedGridY;
  bool _showBuildingSelection = false;
  final Resources _resources = Resources();
  async.Timer? _resourceTimer;

  Building? _buildingToPlace;
  bool get _isInPlacementMode => _buildingToPlace != null;

  @override
  void initState() {
    super.initState();
    _game = MainGame();
    _game.onGridCellTapped = _onGridCellTapped;
    _game.onGridCellLongTapped = _onGridCellLongTapped;
    _game.onGridCellSecondaryTapped = _onGridCellSecondaryTapped;
    _game.onPointerMoveCallback = _onPointerMove;
    _loadSavedData();
    _startResourceGeneration();
  }

  @override
  void dispose() {
    _resourceTimer?.cancel();
    super.dispose();
  }

  void _startResourceGeneration() {
    _resourceTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      final buildings = _game.grid.getAllBuildings();
      setState(() {
        _resources.update(buildings);
        _saveResources();
      });
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _resources.money = prefs.getDouble('money') ?? 1000.0;
      _resources.population = prefs.getInt('population') ?? 0;
      _resources.gold = prefs.getDouble('gold') ?? 0.0;
      _resources.wood = prefs.getDouble('wood') ?? 0.0;
      _resources.coal = prefs.getDouble('coal') ?? 0.0;
    });
  }

  Future<void> _saveResources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('money', _resources.money);
    await prefs.setInt('population', _resources.population);
    await prefs.setDouble('gold', _resources.gold);
    await prefs.setDouble('wood', _resources.wood);
    await prefs.setDouble('coal', _resources.coal);
  }

  void _onPointerMove(Vector2 canvasPosition) {
    if (_isInPlacementMode) {
      final worldPosition = _game.camera.globalToLocal(canvasPosition);
      final localPosition = _game.grid.toLocal(worldPosition);
      final gridPosition = _game.grid.getGridPosition(localPosition);

      if (gridPosition != null) {
        _game.showPlacementPreview(
            _buildingToPlace!, gridPosition.x.toInt(), gridPosition.y.toInt());
      } else {
        _game.hidePlacementPreview();
      }
    }
  }

  void _onGridCellTapped(int x, int y) {
    if (_isInPlacementMode) {
      if (_game.grid.isAreaAvailable(x, y, _buildingToPlace!.gridSize)) {
        if (_resources.money >= _buildingToPlace!.cost) {
          _game.grid.placeBuilding(x, y, _buildingToPlace!);
          setState(() {
            _resources.money -= _buildingToPlace!.cost;
            _resources.population += _buildingToPlace!.population;
            _saveResources();
            _buildingToPlace = null;
            _game.hidePlacementPreview();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insufficient funds!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This area is occupied!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final building = _game.grid.getBuildingAt(x, y);
      if (building != null) {
        if (building.upgrades.isNotEmpty) {
          _showUpgradeDialog(x, y, building);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No upgrades available for this building.'),
            ),
          );
        }
      } else {
        setState(() {
          _selectedGridX = x;
          _selectedGridY = y;
          _showBuildingSelection = true;
        });
      }
    }
  }

  void _onGridCellLongTapped(int x, int y) {
    final building = _game.grid.getBuildingAt(x, y);
    if (building != null) {
      _showDeleteConfirmationDialog(x, y, building);
    }
  }

  void _onGridCellSecondaryTapped(int x, int y) {
    final building = _game.grid.getBuildingAt(x, y);
    if (building != null) {
      _showDeleteConfirmationDialog(x, y, building);
    }
  }

  void _showUpgradeDialog(int x, int y, Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade ${building.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: building.upgrades.map((upgrade) {
            return ListTile(
              title: Text(upgrade.name),
              subtitle: Text('Cost: ${upgrade.cost}'),
              onTap: () {
                if (_resources.money >= upgrade.cost) {
                  setState(() {
                    _resources.money -= upgrade.cost;
                    _game.grid.placeBuilding(x, y, upgrade);
                    _saveResources();
                  });
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not enough money to upgrade.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(int x, int y, Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${building.name}?'),
        content: Text('This will refund ${building.cost} money.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _game.grid.removeBuilding(x, y);
              setState(() {
                _resources.money += building.cost;
                if (building.type == BuildingType.house) {
                  _resources.population -= building.population;
                }
                _saveResources();
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onBuildingSelected(Building building) {
    setState(() {
      _buildingToPlace = building;
      _showBuildingSelection = false;
    });
  }

  void _closeBuildingSelection() {
    setState(() {
      _showBuildingSelection = false;
      _selectedGridX = null;
      _selectedGridY = null;
      _buildingToPlace = null;
      _game.hidePlacementPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(
            game: _game,
          ),
          // Top UI Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_isInPlacementMode) {
                        setState(() {
                          _buildingToPlace = null;
                          _game.hidePlacementPreview();
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(
                        _isInPlacementMode ? Icons.close : Icons.arrow_back,
                        color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Money: ${_resources.money.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Electricity: ${_resources.electricity.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Population: ${_resources.population}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Gold: ${_resources.gold.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.brown.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Wood: ${_resources.wood.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Coal: ${_resources.coal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Building Selection Popup
          if (_showBuildingSelection)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((255 * 0.9).round()),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.cyanAccent, width: 1),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Building ($_selectedGridX, $_selectedGridY)',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _closeBuildingSelection,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Building List
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: Building.availableBuildings.length,
                          itemBuilder: (context, index) {
                            final building =
                                Building.availableBuildings[index];
                            return _buildBuildingCard(building);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
    return GestureDetector(
      onTap: () => _onBuildingSelected(building),
      child: Container(
        decoration: BoxDecoration(
          color: building.color.withAlpha((255 * 0.2).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: building.color,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                building.icon,
                color: building.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      building.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${building.cost} money',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}