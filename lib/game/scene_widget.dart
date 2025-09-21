import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../widgets/game/building_selection_panel.dart';
import '../widgets/game/game_controls.dart';
import '../widgets/game/game_overlay.dart';
import '../widgets/game/hamburger_menu.dart';
import '../widgets/game/delete_confirmation_dialog.dart';
import '../widgets/game/resource_display.dart';
import 'building/building.dart';
import 'main_game.dart';
import 'managers/building_placement_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/input_handler.dart';
import 'managers/persistence_manager.dart';
import 'planet/index.dart';
import 'services/resource_service.dart';
import 'services/save_service.dart';

class MainGameWidget extends StatefulWidget {
  final Planet planet;

  const MainGameWidget({super.key, required this.planet});

  @override
  State<MainGameWidget> createState() => _MainGameWidgetState();
}

class _MainGameWidgetState extends State<MainGameWidget> {
  late MainGame _game;
  late GameStateManager _gameStateManager;
  late BuildingPlacementManager _placementManager;
  late InputHandler _inputHandler;

  int? _selectedGridX;
  int? _selectedGridY;
  bool _showBuildingSelection = false;
  bool _showHamburgerMenu = false;
  bool _uiOverlayOpen = false; // gates pointer events to GameWidget


  @override
  void initState() {
    super.initState();
    _initializeGame();
    _loadSavedData();
    _startResourceGeneration();
  }

  void _initializeGame() {
    _game = MainGame(planet: widget.planet);
    _game.onPlanetChanged = _onPlanetChanged;
    _gameStateManager = GameStateManager(resources: widget.planet.resources);
    
    _placementManager = BuildingPlacementManager(
      game: _game,
      resources: widget.planet.resources,
      buildingLimitManager: _gameStateManager.buildingLimitManager,
      onResourcesChanged: _onResourcesChanged,
    );

    _inputHandler = InputHandler(
      game: _game,
      resources: widget.planet.resources,
      placementManager: _placementManager,
      onEmptyGridTapped: _onEmptyGridTapped,
      onBuildingLongTapped: _onBuildingLongTapped,
      onResourcesChanged: _onResourcesChanged,
    );

    _game.onGridCellTapped = _handleGridCellTapped;
    _game.onGridCellLongTapped = _inputHandler.handleGridCellLongTapped;
    _game.onGridCellSecondaryTapped = _inputHandler.handleGridCellLongTapped;
  }

  @override
  void dispose() {
    _gameStateManager.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    await PersistenceManager.loadSavedData(
      widget.planet.resources,
      _gameStateManager.researchManager,
    );
    setState(() {});
  }

  void _startResourceGeneration() {
    _gameStateManager.startResourceGeneration(
      () => _game.hasLoaded ? _game.grid.getAllBuildings() : <Building>[],
      _onResourcesChanged,
    );
  }

  void _onResourcesChanged() {
    setState(() {
      PersistenceManager.saveResources(
        widget.planet.resources,
        _gameStateManager.researchManager,
      );
    });
  }

  void _onPlanetChanged(Planet planet) {
    // Update the global active planet
    ActivePlanet().updateActivePlanet(planet);
    
    setState(() {
      // Save the planet changes immediately
      SaveService.savePlanet(planet);
    });
  }

  void _handleGridCellTapped(int x, int y) {
    _inputHandler.handleGridCellTapped(x, y, context);
  }

  void _onEmptyGridTapped(int x, int y) {
    setState(() {
      _selectedGridX = x;
      _selectedGridY = y;
      _showBuildingSelection = true;
    });
  }

  void _onBuildingLongTapped(int x, int y, Building building) {
    _showDeleteConfirmationDialog(x, y, building);
  }

  void _onBuildingSelected(Building building) {
    _placementManager.selectBuilding(building);
    setState(() {
      _showBuildingSelection = false;
    });
  }

  void _closeBuildingSelection() {
    setState(() {
      _showBuildingSelection = false;
      _selectedGridX = null;
      _selectedGridY = null;
    });
    _placementManager.cancelPlacement();
  }

  void _handleBackPressed() {
    if (_game.buildingToPlace != null) {
      setState(() {
        _placementManager.cancelPlacement();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _handleEscapePressed() {
    if (_game.buildingToPlace != null) {
      setState(() {
        _placementManager.cancelPlacement();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameControls(
        game: _game,
        onEscapePressed: _handleEscapePressed,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _uiOverlayOpen || _showHamburgerMenu || _showBuildingSelection,
                child: GameWidget(game: _game),
              ),
            ),
            
            // Top UI Bar
            GameOverlay(
              game: _game,
              onBackPressed: _handleBackPressed,
            ),
            
            // Resource Display (upper right)
            if (_game.hasLoaded)
              Positioned(
                top: 20,
                right: 20,
                child: ResourceDisplay(
                  resources: widget.planet.resources,
                ),
              ),
            
            // Hamburger Menu Button
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showHamburgerMenu = !_showHamburgerMenu;
                    _uiOverlayOpen = _showHamburgerMenu || _showBuildingSelection || _uiOverlayOpen;
                  });
                },
                backgroundColor: Colors.purple.withAlpha((255 * 0.8).round()),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
            ),
            // Debug Tools Button (bottom-left)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton.small(
                heroTag: 'debug_tools_button',
                onPressed: _openDebugSheet,
                backgroundColor: Colors.teal.withAlpha((255 * 0.8).round()),
                child: const Icon(Icons.bug_report, color: Colors.white),
              ),
            ),
            
            // Hamburger Menu (only add when visible to avoid zero-size children)
            if (_game.hasLoaded && _showHamburgerMenu)
              HamburgerMenu(
                isVisible: true,
                onClose: () => setState(() {
                  _showHamburgerMenu = false;
                  _uiOverlayOpen = _showBuildingSelection; // remain open if building panel is open
                }),
                resources: widget.planet.resources,
                researchManager: _gameStateManager.researchManager,
                buildingLimitManager: _gameStateManager.buildingLimitManager,
                grid: _game.grid,
                onResourcesChanged: _onResourcesChanged,
              ),
            
            // Building Selection Panel (only add when visible)
            if (_game.hasLoaded && _showBuildingSelection)
              BuildingSelectionPanel(
                isVisible: true,
                selectedGridX: _selectedGridX,
                selectedGridY: _selectedGridY,
                onClose: () {
                  _closeBuildingSelection();
                  setState(() => _uiOverlayOpen = _showHamburgerMenu);
                },
                onBuildingSelected: _onBuildingSelected,
                researchManager: _gameStateManager.researchManager,
                buildingLimitManager: _gameStateManager.buildingLimitManager,
                grid: _game.grid,
              ),
          ],
        ),
      ),
    );
  }

  void _openDebugSheet() {
    if (!_game.hasLoaded) return;
    // Gate pointer events to the game and defer the modal until the next frame
    setState(() => _uiOverlayOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final initialTerrainDebug = _game.terrain?.showDebug ?? false;
      final initialGridDebug = _game.grid.showDebug;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black.withAlpha((255 * 0.95).round()),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          bool terrainDebug = initialTerrainDebug;
          bool gridDebug = initialGridDebug;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Developer Tools', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Terrain debug overlays', style: TextStyle(color: Colors.white70)),
                      value: terrainDebug,
                      onChanged: (v) {
                        setSheetState(() => terrainDebug = v);
                        _game.terrain?.setDebugOverlays(v);
                      },
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Grid debug overlays', style: TextStyle(color: Colors.white70)),
                      value: gridDebug,
                      onChanged: (v) {
                        setSheetState(() => gridDebug = v);
                        _game.grid.showDebug = v;
                      },
                    ),
                    // Parallax is enabled by default and no longer toggled here.
                  ],
                ),
              );
            },
          );
        },
      );
      if (!mounted) return;
      setState(() => _uiOverlayOpen = _showHamburgerMenu || _showBuildingSelection);
    });
  }

  void _showDeleteConfirmationDialog(int x, int y, Building building) {
    if (!_game.hasLoaded) return;
    
    DeleteConfirmationDialog.show(
      context: context,
      building: building,
      onConfirm: () {
        _game.grid.removeBuilding(x, y);
        setState(() {
          ResourceService.refundBuilding(widget.planet.resources, building);
        });
        _onResourcesChanged();
      },
    );
  }
}