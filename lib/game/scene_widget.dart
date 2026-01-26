import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/game/building_selection_panel.dart';
import '../widgets/game/game_controls.dart';
import '../widgets/game/game_overlay.dart';
import '../widgets/game/hamburger_menu.dart';
import '../widgets/game/building_options_dialog.dart';
import '../widgets/game/production_overlay/production_overlay.dart';
import '../widgets/game/resource_display.dart';
import 'building/building.dart';
import 'main_game.dart';
import 'managers/building_placement_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/input_handler.dart';
import 'managers/persistence_manager.dart';
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
  bool _bgmStarted =
      false; // start audio after first user interaction (web-safe)
  bool _musicEnabled = true;
  double _musicVolume = 0.5;
  AudioPlayer? _bgm;
  final PlanetSaveDebouncer _planetSaveDebouncer = PlanetSaveDebouncer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    _loadSavedData();
    _loadAudioPrefs();
    _startResourceGeneration();
    _applyTerrainPrefsWhenReady();
    // Do not auto-start audio; start on first user interaction to satisfy web autoplay policy
  }

  // Helper for labeled slider rows in debug sheet
  Widget _buildSliderRow({
    required String label,
    required String valueText,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(valueText, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          child,
        ],
      ),
    );
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
    _game.onUserInteracted = _maybeStartBgm;
  }

  @override
  void dispose() {
    _gameStateManager.dispose();
    _planetSaveDebouncer.dispose();
    // Stop and dispose background music only if started
    if (_bgmStarted) {
      try {
        _bgm?.stop();
        _bgm?.dispose();
      } catch (e) {
        debugPrint('BGM dispose error: $e');
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initAudio() async {
    try {
      _bgm ??= AudioPlayer();
      await _bgm!.setReleaseMode(ReleaseMode.loop);
      await _bgm!.setVolume(_musicVolume);
      await _bgm!.play(AssetSource('audio/background.mp3'));
      debugPrint('BGM started (volume=$_musicVolume).');
    } catch (e) {
      debugPrint('Failed to initialize/play BGM: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (!_bgmStarted) return; // nothing to do until BGM has started
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _bgm?.pause();
          debugPrint('BGM paused due to lifecycle.');
          break;
        case AppLifecycleState.resumed:
          if (_musicEnabled) {
            _bgm?.resume();
            debugPrint('BGM resumed due to lifecycle.');
          }
          break;
        case AppLifecycleState.detached:
          // App is terminating; ensure BGM is stopped
          _bgm?.stop();
          debugPrint('BGM stopped due to lifecycle detach.');
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('BGM lifecycle handling error: $e');
    }
  }

  void _maybeStartBgm() {
    if (_bgmStarted || !_musicEnabled) return;
    setState(() => _bgmStarted = true);
    _initAudio();
  }

  Future<void> _loadAudioPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('audio.musicEnabled');
      final volume = prefs.getDouble('audio.musicVolume');
      setState(() {
        if (enabled != null) _musicEnabled = enabled;
        if (volume != null) _musicVolume = volume.clamp(0.0, 1.0);
      });
    } catch (e) {
      debugPrint('Failed to load audio prefs: $e');
    }
  }

  Future<void> _saveAudioPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio.musicEnabled', _musicEnabled);
      await prefs.setDouble('audio.musicVolume', _musicVolume);
    } catch (e) {
      debugPrint('Failed to save audio prefs: $e');
    }
  }

  void _setMusicEnabled(bool value) {
    setState(() => _musicEnabled = value);
    _saveAudioPrefs();
    if (!_bgmStarted && value) {
      // Start after the user's explicit toggle (gesture) on web
      _maybeStartBgm();
    } else if (_bgmStarted && !value) {
      try {
        _bgm?.pause();
        debugPrint('BGM paused by user.');
      } catch (e) {
        debugPrint('Failed to pause BGM: $e');
      }
    } else if (_bgmStarted && value) {
      try {
        _bgm?.resume();
        debugPrint('BGM resumed by user.');
      } catch (e) {
        debugPrint('Failed to resume BGM: $e');
      }
    }
  }

  void _setMusicVolume(double value) {
    setState(() => _musicVolume = value.clamp(0.0, 1.0));
    _saveAudioPrefs();
    if (_bgmStarted) {
      // Change volume without restarting playback
      try {
        _bgm?.setVolume(_musicVolume);
        debugPrint('BGM volume changed to $_musicVolume.');
      } catch (e) {
        debugPrint('Failed to change BGM volume: $e');
      }
    }
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

  // Load saved terrain debug toggles and generation parameters once the game is ready
  Future<void> _applyTerrainPrefsWhenReady() async {
    final prefs = await SharedPreferences.getInstance();
    // Read toggle prefs
    final terrainDebug = prefs.getBool('terrain.debug') ?? false;
    final showCenters = prefs.getBool('terrain.showCenters') ?? false;
    final showEdges = prefs.getBool('terrain.showEdges') ?? false;
    final gridDebug = prefs.getBool('grid.debug') ?? false;

    // Wait until game is loaded
    while (mounted && !_game.hasLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
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

  Future<void> _saveTerrainTogglePrefs({
    required bool terrainDebug,
    required bool showCenters,
    required bool showEdges,
    required bool gridDebug,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terrain.debug', terrainDebug);
    await prefs.setBool('terrain.showCenters', showCenters);
    await prefs.setBool('terrain.showEdges', showEdges);
    await prefs.setBool('grid.debug', gridDebug);
  }

  Future<void> _saveTerrainParamPrefs({
    required int patchSizeBase,
    required int patchJitter,
    required double primaryWeight,
    required double warpAmplitude,
    required double warpFrequency,
    required double edgeWidth,
    required double edgeGamma,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('terrain.patchSizeBase', patchSizeBase);
    await prefs.setInt('terrain.patchJitter', patchJitter);
    await prefs.setDouble('terrain.primaryWeight', primaryWeight);
    await prefs.setDouble('terrain.warpAmplitude', warpAmplitude);
    await prefs.setDouble('terrain.warpFrequency', warpFrequency);
    await prefs.setDouble('terrain.edgeWidth', edgeWidth);
    await prefs.setDouble('terrain.edgeGamma', edgeGamma);
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
        final newData = existingData.copyWith(
          level: building.level,
          assignedWorkers: building.assignedWorkers,
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
      PersistenceManager.saveResources(
        widget.planet.resources,
        _gameStateManager.researchManager,
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
    _maybeStartBgm();
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
                  _maybeStartBgm();
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
                  _maybeStartBgm();
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
                musicEnabled: _musicEnabled,
                musicVolume: _musicVolume,
                onMusicEnabledChanged: _setMusicEnabled,
                onMusicVolumeChanged: _setMusicVolume,
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
        isScrollControlled: true,
        builder: (ctx) {
          bool terrainDebug = initialTerrainDebug;
          bool gridDebug = initialGridDebug;
          bool showCenters = _game.terrain?.showPatchCentersDebug ?? false;
          bool showEdges = _game.terrain?.showEdgeZonesDebug ?? false;
          // Terrain generator parameters
          final gen = _game.terrain!.generator;
          int patchSizeBase = gen.patchSizeBase;
          int patchJitter = gen.patchJitter;
          double primaryWeight = gen.primaryWeight;
          double warpAmplitude = gen.warpAmplitude;
          double warpFrequency = gen.warpFrequency;
          double edgeWidth = gen.edgeWidth;
          double edgeGamma = gen.edgeGamma;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Developer Tools',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Terrain debug overlays',
                          style: TextStyle(color: Colors.white70),
                        ),
                        value: terrainDebug,
                        onChanged: (v) {
                          setSheetState(() => terrainDebug = v);
                          _game.terrain?.setDebugOverlays(v);
                          _saveTerrainTogglePrefs(
                            terrainDebug: terrainDebug,
                            showCenters: showCenters,
                            showEdges: showEdges,
                            gridDebug: gridDebug,
                          );
                        },
                      ),
                      // Patch overlay toggles
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Show patch centers',
                          style: TextStyle(color: Colors.white70),
                        ),
                        value: showCenters,
                        onChanged: (v) {
                          setSheetState(() => showCenters = v);
                          _game.terrain?.setPatchDebugOverlays(showCenters: v);
                          _saveTerrainTogglePrefs(
                            terrainDebug: terrainDebug,
                            showCenters: showCenters,
                            showEdges: showEdges,
                            gridDebug: gridDebug,
                          );
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Show edge zones',
                          style: TextStyle(color: Colors.white70),
                        ),
                        value: showEdges,
                        onChanged: (v) {
                          setSheetState(() => showEdges = v);
                          _game.terrain?.setPatchDebugOverlays(showEdges: v);
                          _saveTerrainTogglePrefs(
                            terrainDebug: terrainDebug,
                            showCenters: showCenters,
                            showEdges: showEdges,
                            gridDebug: gridDebug,
                          );
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Grid debug overlays',
                          style: TextStyle(color: Colors.white70),
                        ),
                        value: gridDebug,
                        onChanged: (v) {
                          setSheetState(() => gridDebug = v);
                          _game.grid.showDebug = v;
                          _saveTerrainTogglePrefs(
                            terrainDebug: terrainDebug,
                            showCenters: showCenters,
                            showEdges: showEdges,
                            gridDebug: gridDebug,
                          );
                        },
                      ),
                      const Divider(color: Colors.white24),
                      const Text(
                        'Presets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                // Smooth Plains
                                patchSizeBase = 12;
                                patchJitter = 1;
                                primaryWeight = 0.90;
                                warpAmplitude = 1.0;
                                warpFrequency = 0.12;
                                edgeWidth = 1.1;
                                edgeGamma = 1.4;
                              });
                            },
                            child: const Text('Plains'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                // Rugged / patchy
                                patchSizeBase = 8;
                                patchJitter = 2;
                                primaryWeight = 0.80;
                                warpAmplitude = 2.0;
                                warpFrequency = 0.22;
                                edgeWidth = 1.4;
                                edgeGamma = 1.8;
                              });
                            },
                            child: const Text('Rugged'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                // Coastal / accentuated borders
                                patchSizeBase = 10;
                                patchJitter = 2;
                                primaryWeight = 0.75;
                                warpAmplitude = 1.6;
                                warpFrequency = 0.18;
                                edgeWidth = 1.6;
                                edgeGamma = 1.6;
                              });
                            },
                            child: const Text('Coastal'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Terrain parameters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Patch size
                      _buildSliderRow(
                        label: 'Patch Size',
                        valueText: '$patchSizeBase',
                        child: Slider(
                          value: patchSizeBase.toDouble(),
                          min: 5,
                          max: 15,
                          divisions: 10,
                          label: '$patchSizeBase',
                          onChanged: (v) =>
                              setSheetState(() => patchSizeBase = v.round()),
                        ),
                      ),
                      // Patch jitter
                      _buildSliderRow(
                        label: 'Patch Jitter',
                        valueText: '$patchJitter',
                        child: Slider(
                          value: patchJitter.toDouble(),
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: '$patchJitter',
                          onChanged: (v) =>
                              setSheetState(() => patchJitter = v.round()),
                        ),
                      ),
                      // Primary weight
                      _buildSliderRow(
                        label: 'Primary Weight',
                        valueText: primaryWeight.toStringAsFixed(2),
                        child: Slider(
                          value: primaryWeight,
                          min: 0.6,
                          max: 1.0,
                          divisions: 20,
                          label: primaryWeight.toStringAsFixed(2),
                          onChanged: (v) =>
                              setSheetState(() => primaryWeight = v),
                        ),
                      ),
                      // Warp amplitude
                      _buildSliderRow(
                        label: 'Warp Amplitude',
                        valueText: warpAmplitude.toStringAsFixed(2),
                        child: Slider(
                          value: warpAmplitude,
                          min: 0.0,
                          max: 3.0,
                          divisions: 30,
                          label: warpAmplitude.toStringAsFixed(2),
                          onChanged: (v) =>
                              setSheetState(() => warpAmplitude = v),
                        ),
                      ),
                      // Warp frequency
                      _buildSliderRow(
                        label: 'Warp Frequency',
                        valueText: warpFrequency.toStringAsFixed(2),
                        child: Slider(
                          value: warpFrequency,
                          min: 0.05,
                          max: 0.4,
                          divisions: 35,
                          label: warpFrequency.toStringAsFixed(2),
                          onChanged: (v) =>
                              setSheetState(() => warpFrequency = v),
                        ),
                      ),
                      // Edge width
                      _buildSliderRow(
                        label: 'Edge Width',
                        valueText: edgeWidth.toStringAsFixed(2),
                        child: Slider(
                          value: edgeWidth,
                          min: 0.5,
                          max: 2.5,
                          divisions: 20,
                          label: edgeWidth.toStringAsFixed(2),
                          onChanged: (v) => setSheetState(() => edgeWidth = v),
                        ),
                      ),
                      // Edge gamma
                      _buildSliderRow(
                        label: 'Edge Gamma',
                        valueText: edgeGamma.toStringAsFixed(2),
                        child: Slider(
                          value: edgeGamma,
                          min: 1.0,
                          max: 2.5,
                          divisions: 15,
                          label: edgeGamma.toStringAsFixed(2),
                          onChanged: (v) => setSheetState(() => edgeGamma = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _game.terrain?.updateTerrainParams(
                                patchSizeBase: patchSizeBase,
                                patchJitter: patchJitter,
                                primaryWeight: primaryWeight,
                                warpAmplitude: warpAmplitude,
                                warpFrequency: warpFrequency,
                                edgeWidth: edgeWidth,
                                edgeGamma: edgeGamma,
                              );
                              _saveTerrainParamPrefs(
                                patchSizeBase: patchSizeBase,
                                patchJitter: patchJitter,
                                primaryWeight: primaryWeight,
                                warpAmplitude: warpAmplitude,
                                warpFrequency: warpFrequency,
                                edgeWidth: edgeWidth,
                                edgeGamma: edgeGamma,
                              );
                            },
                            icon: const Icon(Icons.tune),
                            label: const Text('Apply Params'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _game.terrain?.shuffleSeed(),
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Shuffle Seed'),
                          ),
                        ],
                      ),
                      // Parallax is enabled by default and no longer toggled here.
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
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
