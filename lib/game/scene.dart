import 'dart:async' as async;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:horologium/game/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'building.dart';
import 'grid.dart';

class MainGame extends FlameGame with TapCallbacks, DragCallbacks {
  final int gridSize;
  late Grid _grid;
  Function(int, int)? onGridCellTapped;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  final double _startZoom = _minZoom;

  MainGame({this.gridSize = 10});

  Grid get grid => _grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    _grid = Grid(gridSize: gridSize)
      ..size = Vector2(gridSize * cellWidth, gridSize * cellHeight)
      ..anchor = Anchor.center;
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
          .firstWhere((b) => b.name == buildingName);
      _grid.placeBuilding(x, y, building);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    camera.viewfinder.position -= event.canvasDelta / camera.viewfinder.zoom;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid.toLocal(worldPosition);
    final gridPosition = _grid.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellTapped?.call(gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
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

  @override
  void initState() {
    super.initState();
    _game = MainGame();
    _game.onGridCellTapped = _onGridCellTapped;
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
      _resources.money = prefs.getInt('money') ?? 1000;
      _resources.population = prefs.getInt('population') ?? 0;
    });
  }

  Future<void> _saveResources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('money', _resources.money);
    await prefs.setInt('population', _resources.population);
  }

  void _onGridCellTapped(int x, int y) {
    final building = _game.grid.getBuildingAt(x, y);
    if (building != null) {
      _showDeleteConfirmationDialog(x, y, building);
    } else {
      setState(() {
        _selectedGridX = x;
        _selectedGridY = y;
        _showBuildingSelection = true;
      });
    }
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
    if (_selectedGridX != null && _selectedGridY != null) {
      if (_resources.money >= building.cost) {
        _game.grid.placeBuilding(_selectedGridX!, _selectedGridY!, building);
        setState(() {
          _resources.money -= building.cost;
          if (building.type == BuildingType.house) {
            _resources.population += building.population;
          }
          _saveResources();
          _showBuildingSelection = false;
          _selectedGridX = null;
          _selectedGridY = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient funds!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _closeBuildingSelection() {
    setState(() {
      _showBuildingSelection = false;
      _selectedGridX = null;
      _selectedGridY = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final newZoom = _game.camera.viewfinder.zoom -
                    pointerSignal.scrollDelta.dy / 100;
                _game.camera.viewfinder.zoom = newZoom.clamp(0.5, 2.0);
              }
            },
            child: GameWidget(
              game: _game,
            ),
          ),
          // Top UI Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.7).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Colony Builder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                          'Money: ${_resources.money}',
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
                          'Electricity: ${_resources.electricity}',
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
