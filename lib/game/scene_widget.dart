import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/game/building_selection_panel.dart';
import '../widgets/game/game_controls.dart';
import '../widgets/game/game_overlay.dart';
import '../widgets/game/hamburger_menu.dart';
import '../widgets/game/building_options_dialog.dart';
import '../widgets/game/production_overlay/production_overlay.dart';
import '../widgets/game/resource_display.dart';
import '../widgets/game/terrain_debug_sheet.dart';
import 'audio_manager.dart';
import 'building/building.dart';
import 'main_game.dart';
import 'managers/building_placement_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/input_handler.dart';
import 'planet/index.dart';
import 'services/resource_service.dart';
import 'services/planet_save_debouncer.dart';
import 'services/save_service.dart';

class MainGameWidget extends StatefulWidget {
  final Planet planet;

  const MainGameWidget({super.key, required this.planet});

  @override
  State<MainGameWidget> createState() => _MainGameWidgetState();
}

class _MainGameWidgetState extends State<MainGameWidget>
    with WidgetsBindingObserver {
  late MainGame _game;
  late GameStateManager _gameStateManager;
  late BuildingPlacementManager _placementManager;
  late InputHandler _inputHandler;

  int? _selectedGridX;
  int? _selectedGridY;
  bool _showBuildingSelection = false;
  bool _showHamburgerMenu = false;
  bool _showProductionOverlay = false;
  bool _uiOverlayOpen = false; // gates pointer events to GameWidget
  final AudioManager _audioManager = AudioManager();
  final PlanetSaveDebouncer _planetSaveDebouncer = PlanetSaveDebouncer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    _loadSavedData();
    _audioManager
        .loadPrefs()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e, StackTrace s) {
          debugPrint('Failed to load audio preferences: $e\n$s');
          if (mounted) setState(() {});
        });
    _startResourceGeneration();
    _applyTerrainPrefsWhenReady();
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
    _game.onUserInteracted = () {
      _audioManager
          .maybeStartBgm()
          .then((_) {
            if (_audioManager.bgmStarted && mounted) setState(() {});
          })
          .catchError((Object e, StackTrace s) {
            debugPrint('Failed to start BGM on user interaction: $e\n$s');
          });
    };
  }

  @override
  void dispose() {
    _gameStateManager.dispose();
    _planetSaveDebouncer.dispose();
    _audioManager.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _audioManager.handleLifecycleChange(state);
  }

  void _loadSavedData() {
    // Planet data is already loaded before this widget is created.
    // Research state is synced from the planet.
    _gameStateManager.researchManager.loadFromList(
      widget.planet.researchManager.toList(),
    );
    // Sync building limits from the planet to GameStateManager
    _gameStateManager.buildingLimitManager.loadFromMap(
      widget.planet.buildingLimitManager.toMap(),
    );
    setState(() {});
  }

  void _startResourceGeneration() {
    _gameStateManager.startResourceGeneration(
      () => _game.hasLoaded ? _game.grid.getAllBuildings() : <Building>[],
      _onResourcesChanged,
    );
  }

  // Load saved terrain debug toggles and generation parameters once the game is ready
  Future<void> _applyTerrainPrefsWhenReady() async {
    final prefs = await SharedPreferences.getInstance();
    // Read toggle prefs
    final terrainDebug = prefs.getBool('terrain.debug') ?? false;
    final showCenters = prefs.getBool('terrain.showCenters') ?? false;
    final showEdges = prefs.getBool('terrain.showEdges') ?? false;
    final gridDebug = prefs.getBool('grid.debug') ?? false;

    // Wait for the game to finish loading before applying terrain-related prefs.
    try {
      await _game.isLoadedFuture;
    } catch (e) {
      debugPrint('Game failed to load, skipping terrain prefs: $e');
      return;
    }
    if (!mounted || !_game.hasLoaded) return;

    // Apply toggles
    _game.terrain?.setDebugOverlays(terrainDebug);
    _game.terrain?.setPatchDebugOverlays(
      showCenters: showCenters,
      showEdges: showEdges,
    );
    _game.grid.showDebug = gridDebug;

    // Apply parameter prefs (fallback to current generator values)
    final gen = _game.terrain!.generator;
    final newPatchSizeBase =
        prefs.getInt('terrain.patchSizeBase') ?? gen.patchSizeBase;
    final newPatchJitter =
        prefs.getInt('terrain.patchJitter') ?? gen.patchJitter;
    final newPrimaryWeight =
        prefs.getDouble('terrain.primaryWeight') ?? gen.primaryWeight;
    final newWarpAmplitude =
        prefs.getDouble('terrain.warpAmplitude') ?? gen.warpAmplitude;
    final newWarpFrequency =
        prefs.getDouble('terrain.warpFrequency') ?? gen.warpFrequency;
    final newEdgeWidth = prefs.getDouble('terrain.edgeWidth') ?? gen.edgeWidth;
    final newEdgeGamma = prefs.getDouble('terrain.edgeGamma') ?? gen.edgeGamma;

    final paramsChanged =
        newPatchSizeBase != gen.patchSizeBase ||
        newPatchJitter != gen.patchJitter ||
        newPrimaryWeight != gen.primaryWeight ||
        newWarpAmplitude != gen.warpAmplitude ||
        newWarpFrequency != gen.warpFrequency ||
        newEdgeWidth != gen.edgeWidth ||
        newEdgeGamma != gen.edgeGamma;
    if (paramsChanged) {
      await _game.terrain?.updateTerrainParams(
        patchSizeBase: newPatchSizeBase,
        patchJitter: newPatchJitter,
        primaryWeight: newPrimaryWeight,
        warpAmplitude: newWarpAmplitude,
        warpFrequency: newWarpFrequency,
        edgeWidth: newEdgeWidth,
        edgeGamma: newEdgeGamma,
      );
    }
  }

  void _syncPlanetFromGrid() {
    // Sync current building state (level, assignedWorkers) from grid to planet
    if (!_game.hasLoaded) return;

    final placedBuildings = _game.grid.getAllPlacedBuildings();
    for (final placedBuilding in placedBuildings) {
      final building = placedBuilding.building;

      // Update the planet's PlacedBuildingData with current state
      final existingData = widget.planet.getBuildingAt(
        placedBuilding.x,
        placedBuilding.y,
      );
      if (existingData != null) {
        // Sync variant for Field/Bakery subtypes
        String? variant = existingData.variant;
        if (building is Field) {
          variant = building.cropType.name;
        } else if (building is Bakery) {
          variant = building.productType.name;
        }

        final newData = existingData.copyWith(
          level: building.level,
          assignedWorkers: building.assignedWorkers,
          variant: variant,
        );
        widget.planet.updateBuildingAt(
          placedBuilding.x,
          placedBuilding.y,
          newData,
        );
      }
    }
  }

  void _onResourcesChanged() {
    _handleResourcesChanged();
  }

  void _handleResourcesChanged({bool immediateSave = false}) {
    setState(() {
      // Sync worker assignments from grid to planet before saving
      _syncPlanetFromGrid();
      // Sync research state from GameStateManager back to planet
      widget.planet.researchManager.loadFromList(
        _gameStateManager.researchManager.toList(),
      );
      // Sync building limits from GameStateManager back to planet
      widget.planet.buildingLimitManager.loadFromMap(
        _gameStateManager.buildingLimitManager.toMap(),
      );
    });
    _schedulePlanetSave(immediateSave: immediateSave);
  }

  void _schedulePlanetSave({bool immediateSave = false}) {
    _planetSaveDebouncer.schedule(
      () => SaveService.savePlanet(widget.planet),
      immediate: immediateSave,
    );
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
    // Fire-and-forget audio start to avoid blocking the tap with audio latency
    _audioManager.maybeStartBgm().catchError((Object e) {
      debugPrint('Audio start failed during tap: $e');
    });
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
    _showBuildingOptionsDialog(x, y, building);
  }

  void _onBuildingSelected(Building building) {
    _placementManager.selectBuilding(building);
    setState(() {
      _showBuildingSelection = false;
      // Re-enable game input once a building is selected for placement
      _uiOverlayOpen = false;
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
                ignoring:
                    _uiOverlayOpen ||
                    _showHamburgerMenu ||
                    _showBuildingSelection ||
                    _showProductionOverlay,
                child: GameWidget(game: _game),
              ),
            ),

            // Top UI Bar
            GameOverlay(game: _game, onBackPressed: _handleBackPressed),

            // Resource Display (upper right)
            if (_game.hasLoaded)
              Positioned(
                top: 20,
                right: 20,
                child: ResourceDisplay(
                  resources: widget.planet.resources,
                  onProductionChainTap: () {
                    setState(() {
                      _showProductionOverlay = true;
                      _uiOverlayOpen = true;
                    });
                  },
                ),
              ),

            // Hamburger Menu Button
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  // Fire-and-forget audio start to avoid blocking UI
                  _audioManager.maybeStartBgm().catchError((Object e) {
                    debugPrint('Audio start failed during menu tap: $e');
                  });
                  setState(() {
                    _showHamburgerMenu = !_showHamburgerMenu;
                    // Only reflect current overlays; do not OR with existing value to avoid sticky state
                    _uiOverlayOpen =
                        _showHamburgerMenu ||
                        _showBuildingSelection ||
                        _showProductionOverlay;
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
                onPressed: () {
                  // Fire-and-forget audio start to avoid blocking UI
                  _audioManager.maybeStartBgm().catchError((Object e) {
                    debugPrint('Audio start failed during debug tap: $e');
                  });
                  _openDebugSheet();
                },
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
                  _uiOverlayOpen =
                      _showBuildingSelection ||
                      _showProductionOverlay; // remain open if other panels are open
                }),
                resources: widget.planet.resources,
                researchManager: _gameStateManager.researchManager,
                buildingLimitManager: _gameStateManager.buildingLimitManager,
                grid: _game.grid,
                onResourcesChanged: _onResourcesChanged,
                musicEnabled: _audioManager.musicEnabled,
                musicVolume: _audioManager.musicVolume,
                onMusicEnabledChanged: (v) async {
                  await _audioManager.setMusicEnabled(v);
                  setState(() {});
                },
                onMusicVolumeChanged: (v) {
                  _audioManager.setMusicVolume(v);
                  setState(() {});
                },
              ),

            // Building Selection Panel (only add when visible)
            if (_game.hasLoaded && _showBuildingSelection)
              BuildingSelectionPanel(
                isVisible: true,
                selectedGridX: _selectedGridX,
                selectedGridY: _selectedGridY,
                onClose: () {
                  _closeBuildingSelection();
                  setState(
                    () => _uiOverlayOpen =
                        _showHamburgerMenu || _showProductionOverlay,
                  );
                },
                onBuildingSelected: _onBuildingSelected,
                researchManager: _gameStateManager.researchManager,
                buildingLimitManager: _gameStateManager.buildingLimitManager,
                grid: _game.grid,
              ),

            // Production Chain Overlay (only add when visible)
            if (_game.hasLoaded && _showProductionOverlay)
              ProductionOverlay(
                getBuildings: () => _game.grid.getAllBuildings(),
                getResources: () => widget.planet.resources,
                onClose: () {
                  setState(() {
                    _showProductionOverlay = false;
                    _uiOverlayOpen =
                        _showHamburgerMenu || _showBuildingSelection;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openDebugSheet() {
    if (!_game.hasLoaded) return;
    setState(() => _uiOverlayOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TerrainDebugSheet.show(context, _game);
      if (!mounted) return;
      setState(
        () => _uiOverlayOpen =
            _showHamburgerMenu ||
            _showBuildingSelection ||
            _showProductionOverlay,
      );
    });
  }

  void _showBuildingOptionsDialog(int x, int y, Building building) {
    if (!_game.hasLoaded) return;

    BuildingOptionsDialog.show(
      context: context,
      building: building,
      currentCash: widget.planet.resources.cash,
      onUpgrade: () {
        _upgradeBuilding(x, y, building);
      },
      onDelete: () {
        _game.grid.removeBuilding(x, y);
        setState(() {
          ResourceService.refundBuilding(widget.planet.resources, building);
        });
        _handleResourcesChanged(immediateSave: true);
      },
    );
  }

  void _upgradeBuilding(int x, int y, Building building) {
    if (!building.canUpgrade) return;
    if (widget.planet.resources.cash < building.upgradeCost) return;

    setState(() {
      // Deduct upgrade cost
      widget.planet.resources.cash -= building.upgradeCost;

      // Upgrade the building
      building.upgrade();

      // Update the planet's building data
      _updatePlanetBuildingLevel(x, y, building.level);
    });

    _handleResourcesChanged(immediateSave: true);
  }

  void _updatePlanetBuildingLevel(int x, int y, int newLevel) {
    // Update the building data in the planet using the mutable API
    final oldData = widget.planet.getBuildingAt(x, y);
    if (oldData != null) {
      final newData = oldData.copyWith(level: newLevel);
      widget.planet.updateBuildingAt(x, y, newData);
    }
  }
}
