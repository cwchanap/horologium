import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../widgets/game/building_selection_panel.dart';
import '../widgets/game/game_controls.dart';
import '../widgets/game/game_overlay.dart';
import '../widgets/game/hamburger_menu.dart';
import '../widgets/game/delete_confirmation_dialog.dart';
import 'building/building.dart';
import 'main_game.dart';
import 'managers/building_placement_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/input_handler.dart';
import 'managers/persistence_manager.dart';
import 'services/resource_service.dart';
import 'resources/resources.dart';

class MainGameWidget extends StatefulWidget {
  final Resources resources;

  const MainGameWidget({super.key, required this.resources});

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

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _loadSavedData();
    _startResourceGeneration();
  }

  void _initializeGame() {
    _game = MainGame();
    _gameStateManager = GameStateManager(resources: widget.resources);
    
    _placementManager = BuildingPlacementManager(
      game: _game,
      resources: widget.resources,
      buildingLimitManager: _gameStateManager.buildingLimitManager,
      onResourcesChanged: _onResourcesChanged,
    );

    _inputHandler = InputHandler(
      game: _game,
      resources: widget.resources,
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
      widget.resources,
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
        widget.resources,
        _gameStateManager.researchManager,
      );
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
          children: [
            GameWidget(game: _game),
            
            // Top UI Bar
            GameOverlay(
              game: _game,
              onBackPressed: _handleBackPressed,
            ),
            
            // Hamburger Menu Button
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showHamburgerMenu = !_showHamburgerMenu;
                  });
                },
                backgroundColor: Colors.purple.withAlpha((255 * 0.8).round()),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
            ),
            
            // Hamburger Menu
            if (_game.hasLoaded)
              HamburgerMenu(
                isVisible: _showHamburgerMenu,
                onClose: () => setState(() => _showHamburgerMenu = false),
                resources: widget.resources,
                researchManager: _gameStateManager.researchManager,
                buildingLimitManager: _gameStateManager.buildingLimitManager,
                grid: _game.grid,
                onResourcesChanged: _onResourcesChanged,
              ),
            
            // Building Selection Panel
            if (_game.hasLoaded)
              BuildingSelectionPanel(
                isVisible: _showBuildingSelection,
                selectedGridX: _selectedGridX,
                selectedGridY: _selectedGridY,
                onClose: _closeBuildingSelection,
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

  void _showDeleteConfirmationDialog(int x, int y, Building building) {
    if (!_game.hasLoaded) return;
    
    DeleteConfirmationDialog.show(
      context: context,
      building: building,
      onConfirm: () {
        _game.grid.removeBuilding(x, y);
        setState(() {
          ResourceService.refundBuilding(widget.resources, building);
        });
        _onResourcesChanged();
      },
    );
  }
}