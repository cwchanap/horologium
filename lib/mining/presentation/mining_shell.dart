import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_settings_sheet.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';
import 'package:horologium/mining/presentation/site_deck_screen.dart';
import 'package:horologium/mining/presentation/stellar_map_screen.dart';
import 'package:horologium/mining/presentation/technology_sheet.dart';
import 'package:horologium/mining/site_deck_view.dart';

class MiningShell extends StatefulWidget {
  const MiningShell({
    super.key,
    this.content,
    this.repository,
    this.nowUtc,
    this.audioManager,
  });

  final MiningContentRegistry? content;
  final MiningSaveRepository? repository;
  final DateTime Function()? nowUtc;
  final AudioManager? audioManager;

  @override
  State<MiningShell> createState() => _MiningShellState();
}

/// Read-only identity handles into the mounted [MiningShell] state.
abstract class MiningShellHandles implements State<MiningShell> {
  MiningController get controller;
  AudioManager get audioManager;
  bool get reducedMotion;
  void openSettings();
  void openTechnology();
}

class _MiningShellState extends State<MiningShell>
    with WidgetsBindingObserver
    implements MiningShellHandles {
  late final MiningContentRegistry _content;
  late final MiningController _controller;
  late final AudioManager _audioManager;
  late final bool _createdAudioManager;
  late MiningSave _displayState;
  late final ValueNotifier<MiningSave> _displayNotifier;
  Timer? _refreshTimer;
  bool _initialized = false;
  bool _reducedMotion = false;
  bool _recoverySnackBarScheduled = false;
  DockBayId? _selectedBayId;
  MiningSiteId? _openSiteId;
  int _landingBasinImpactSequence = 0;
  MiningNavigationDestination _selectedDestination =
      MiningNavigationDestination.siteDeck;

  @override
  void initState() {
    super.initState();
    _createdAudioManager = widget.audioManager == null;
    _audioManager = widget.audioManager ?? AudioManager();
    _content = widget.content ?? MiningContentRegistry.stellarMining();
    final nowUtc = widget.nowUtc ?? () => DateTime.now().toUtc();
    _controller = MiningController(
      content: _content,
      repository: widget.repository ?? MiningSaveRepository(content: _content),
      nowUtc: nowUtc,
    );
    _displayState = MiningSave.initial(nowUtc: nowUtc());
    _displayNotifier = ValueNotifier<MiningSave>(_displayState);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _audioManager.loadPrefs();
    await _controller.initialize();
    final pendingReturnSummary = _controller.takePendingReturnSummary();
    if (!mounted) return;
    _initialized = true;
    unawaited(_audioManager.playSound(GameSound.tap));
    _refreshPresentation(announceCargo: false);
    _scheduleRecoverySnackBar();
    _startRefreshTimer();
    if (pendingReturnSummary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showOfflineReturn(pendingReturnSummary));
      });
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshForegroundProduction(),
    );
  }

  void _refreshForegroundProduction() {
    if (_controller.isBusy) return;

    final before = _controller.state;

    _controller.refresh();

    final landing = _controller.state.sites[MiningSiteId.landingBasin]!;
    final hasRig = landing.rigPlacements.isNotEmpty;

    if (_openSiteId == MiningSiteId.landingBasin &&
        hasRig &&
        landing.storedAmount >
            before.sites[MiningSiteId.landingBasin]!.storedAmount) {
      _landingBasinImpactSequence++;
    }

    _refreshPresentation();
  }

  void _announceFullCargo(MiningSave before) {
    if (before.activePlanetId != _controller.state.activePlanetId) return;
    for (final site in _content.planet(before.activePlanetId).sites) {
      final progress = _controller.state.sites[site.id]!;
      final capacity = _content.effectiveSiteCapacity(
        site.id,
        progress.rigPlacements.map((rig) => rig.tier),
        _controller.state.technology.logistics,
      );
      if (capacity > 0 &&
          before.sites[site.id]!.storedAmount < capacity &&
          progress.storedAmount >= capacity) {
        unawaited(_audioManager.playSound(GameSound.cargoFull));
        break;
      }
    }
  }

  void _playMiningImpact() {
    if (mounted &&
        _openSiteId == MiningSiteId.landingBasin &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      unawaited(_audioManager.playSound(GameSound.mining));
    }
  }

  @override
  MiningController get controller => _controller;

  @override
  AudioManager get audioManager => _audioManager;

  @override
  bool get reducedMotion => _reducedMotion;

  void _refreshPresentation({bool announceCargo = true}) {
    if (!_initialized) return;
    if (announceCargo) _announceFullCargo(_displayState);
    _displayState = _controller.state;
    _displayNotifier.value = _controller.state;
    _reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? _reducedMotion;
    if (mounted) setState(() {});
  }

  void _scheduleRecoverySnackBar() {
    if (!_controller.recoveredFromInvalidSave || _recoverySnackBarScheduled) {
      return;
    }
    _recoverySnackBarScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showResult(
        'Mining progress could not be loaded, so a fresh mining save was '
        'started.',
      );
    });
  }

  Future<void> _showOfflineReturn(OfflineProductionSummary summary) {
    return _showMiningSheet(
      OfflineReturnSheet(
        summary: summary,
        content: _content,
        logisticsLevel: _displayState.technology.logistics,
        cash: _displayState.cash,
      ),
    );
  }

  Future<void> _showMiningSheet(Widget sheet) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (sheetContext) {
        if (sheet is! TechnologySheet && sheet is! MiningSettingsSheet) {
          return sheet;
        }
        final settings = sheet is MiningSettingsSheet;
        final deck = SiteDeckView.from(
          state: _displayState,
          content: _content,
          isBusy: _controller.isBusy,
        );
        final site = _content.site(_openSiteId ?? deck.sites.first.id);
        final destination = settings
            ? MiningNavigationDestination.settings
            : MiningNavigationDestination.technology;
        // The bottom-sheet route is a separate overlay route, so
        // `MiningShell.setState` does not rebuild it. Consume the shell's
        // display notifier so the scene HUD tracks live cash/cargo/capacity
        // while the foreground timer accrues.
        return ValueListenableBuilder<MiningSave>(
          valueListenable: _displayNotifier,
          builder: (context, state, _) {
            final liveDeck = SiteDeckView.from(
              state: state,
              content: _content,
              isBusy: _controller.isBusy,
            );
            return MiningSheetScene(
              backgroundAsset: settings ? site.cardAsset : site.cavernAsset,
              destination: destination,
              cash: state.cash,
              cargo: liveDeck.totalCargo,
              capacity: liveDeck.totalCapacity,
              onDestinationSelected: (next) {
                if (next == destination) return;
                Navigator.of(sheetContext).pop();
                _handleNavigation(next);
              },
              child: sheet,
            );
          },
        );
      },
    );
    if (mounted) unawaited(_audioManager.playSound(GameSound.tap));
  }

  @override
  void openSettings() {
    if (!_initialized) return;
    unawaited(_audioManager.playSound(GameSound.tap));
    unawaited(_audioManager.maybeStartBgm());
    unawaited(
      _showMiningSheet(MiningSettingsSheet(audioManager: _audioManager)),
    );
  }

  @override
  void openTechnology() {
    if (!_initialized) return;
    unawaited(_audioManager.playSound(GameSound.tap));
    unawaited(_audioManager.maybeStartBgm());
    unawaited(
      _showMiningSheet(
        TechnologySheet(
          view: TechnologySheetView.from(
            state: _controller.state,
            content: _content,
          ),
          onPurchase: _purchaseTechnology,
          onSelectionChanged: () =>
              unawaited(_audioManager.playSound(GameSound.tap)),
        ),
      ),
    );
  }

  void _purchaseTechnology(TechnologyTrack track) {
    _runSheetAction(
      () => _controller.purchaseTechnology(track),
      successMessage: 'Technology upgraded.',
      sound: GameSound.upgrade,
    );
  }

  void _unlockPlanet(MiningPlanetId id) {
    _runSheetAction(
      () => _controller.unlockPlanet(id),
      successMessage: '${_content.planet(id).name} unlocked.',
      sound: GameSound.milestone,
    );
  }

  void _travelToPlanet(MiningPlanetId id) {
    _runSheetAction(
      () => _controller.switchPlanet(id),
      successMessage: 'Traveled to ${_content.planet(id).name}.',
      sound: GameSound.travel,
    );
  }

  void _unlockSite(MiningSiteId id) {
    _runSheetAction(
      () => _controller.unlockSite(id),
      successMessage: 'Site unlocked.',
      sound: GameSound.upgrade,
    );
  }

  void _spawnRig() {
    _runSheetAction(
      _controller.spawnRig,
      successMessage: 'T1 rig spawned.',
      sound: GameSound.rig,
      onSuccess: (result) => _selectedBayId = result.dockBayId,
    );
  }

  void _handleDockBayTap(DockBayId bayId) {
    if (!_initialized || _controller.isBusy) return;
    final dockView = FleetDockView.from(
      state: _controller.state,
      content: _content,
      selectedBayId: _selectedBayId,
      isBusy: false,
    );
    final tappedBay = dockView.bay(bayId);
    if (tappedBay.rig == null) {
      setState(() => _selectedBayId = null);
      unawaited(_audioManager.playSound(GameSound.reject));
      _showResult('Select an occupied rig bay.');
      return;
    }

    final selectedBayId = _selectedBayId;
    if (selectedBayId == null || selectedBayId == bayId) {
      unawaited(_audioManager.playSound(GameSound.tap));
      setState(() => _selectedBayId = selectedBayId == bayId ? null : bayId);
      return;
    }

    if (tappedBay.canMergeWithSelection) {
      // The source stays selected while saving; the merged rig takes the
      // selection on success, and on failure the source keeps it.
      _runSheetAction(
        () => _controller.mergeDockRigs(selectedBayId, bayId),
        successMessage: 'Rigs merged.',
        sound: GameSound.merge,
        onSuccess: (_) => _selectedBayId = bayId,
      );
      return;
    }

    setState(() => _selectedBayId = bayId);
    unawaited(_audioManager.playSound(GameSound.tap));
  }

  void _enterSite(MiningSiteId id) {
    if (!_initialized || _controller.isBusy) return;
    unawaited(_audioManager.playSound(GameSound.tap));
    unawaited(_audioManager.maybeStartBgm());
    setState(() => _openSiteId = id);
  }

  void _leaveSite() {
    if (!mounted) return;
    unawaited(_audioManager.playSound(GameSound.tap));
    setState(() {
      _openSiteId = null;
      _selectedBayId = null;
    });
  }

  void _handleSiteGridCellTap(MiningGridCell cell) {
    final siteId = _openSiteId;
    if (!_initialized || siteId == null) return;

    final view = MineSiteView.from(
      state: _controller.state,
      content: _content,
      siteId: siteId,
      selectedBayId: _selectedBayId,
      isBusy: _controller.isBusy,
    );
    final outcome = view.gridTapOutcome(cell);

    switch (outcome.action) {
      case MineSiteGridTapAction.deploy:
        final bay = _selectedBayId!;
        _runSheetAction(
          () => _controller.deployRig(bay, siteId, cell),
          successMessage: 'Rig deployed.',
          sound: GameSound.rig,
        );
        break;
      case MineSiteGridTapAction.recall:
        _runSheetAction(
          () => _controller.recallRig(siteId, cell),
          successMessage: 'Rig recalled.',
          sound: GameSound.rig,
        );
        break;
      case MineSiteGridTapAction.blocked:
        unawaited(_audioManager.playSound(GameSound.reject));
        _showResult(outcome.message!);
        break;
    }
  }

  void _sellCargo() {
    if (!_initialized || _controller.isBusy) return;
    final pendingOperation = _controller.sellAllCargo();
    _refreshPresentation();
    unawaited(
      pendingOperation
          .then((result) {
            if (!mounted) return;
            _preserveDockSelection();
            _refreshPresentation();
            if (result.isSuccess) {
              unawaited(HapticFeedback.lightImpact());
              unawaited(_audioManager.playSound(GameSound.sale));
            } else {
              unawaited(_audioManager.playSound(GameSound.reject));
            }
            _showResult(
              result.isSuccess
                  ? 'Sold ${result.revenue} cash.'
                  : result.message ?? 'Sale failed.',
            );
          })
          .catchError((_) {
            if (!mounted) return;
            _refreshPresentation();
            unawaited(_audioManager.playSound(GameSound.reject));
            _showResult('Sale failed.');
          }),
    );
  }

  void _preserveDockSelection() {
    final selectedBayId = _selectedBayId;
    if (selectedBayId == null) return;
    final dock = _controller.state.docks[_controller.state.activePlanetId];
    if (dock == null || dock[selectedBayId] == null) {
      _selectedBayId = null;
    }
  }

  void _handleNavigation(MiningNavigationDestination destination) {
    switch (destination) {
      case MiningNavigationDestination.siteDeck:
        _showPrimarySurface(destination);
        break;
      case MiningNavigationDestination.technology:
        openTechnology();
        break;
      case MiningNavigationDestination.stellarMap:
        _showPrimarySurface(destination);
        break;
      case MiningNavigationDestination.settings:
        openSettings();
        break;
    }
  }

  void _showPrimarySurface(MiningNavigationDestination destination) {
    if (!_initialized) return;
    unawaited(_audioManager.playSound(GameSound.tap));
    setState(() {
      _selectedDestination = destination;
      _openSiteId = null;
      _selectedBayId = null;
    });
  }

  Future<void> _runSheetAction(
    Future<MiningActionResult> Function() operation, {
    required String successMessage,
    required GameSound sound,
    void Function(MiningActionResult result)? onSuccess,
  }) async {
    if (!_initialized || _controller.isBusy) return;
    final before = _controller.state;
    // Selection callbacks are Mine-Site-local: if the surface changed while
    // persistence was in flight, a late success must not recreate a hidden
    // selection that could deploy in another site.
    final actionSiteId = _openSiteId;
    final pendingOperation = operation();
    _refreshPresentation();
    try {
      final result = await pendingOperation;
      if (!mounted) return;
      if (result.isSuccess &&
          actionSiteId != null &&
          _openSiteId == actionSiteId) {
        onSuccess?.call(result);
      }
      if (result.isSuccess &&
          _controller.state.activePlanetId != before.activePlanetId) {
        _selectedBayId = null;
      } else {
        _preserveDockSelection();
      }
      _refreshPresentation();
      if (result.isSuccess) {
        unawaited(HapticFeedback.lightImpact());
        // First commissioning also covers planet mastery and the Mars reward.
        final commissioned = _controller.state.sites.entries.any(
          (entry) =>
              entry.value.commissioned &&
              !before.sites[entry.key]!.commissioned,
        );
        unawaited(
          _audioManager.playSound(commissioned ? GameSound.milestone : sound),
        );
      } else {
        unawaited(_audioManager.playSound(GameSound.reject));
      }
      _showResult(
        result.isSuccess
            ? result.message ?? successMessage
            : result.message ?? 'Action failed.',
      );
    } catch (_) {
      if (!mounted) return;
      _refreshPresentation();
      unawaited(_audioManager.playSound(GameSound.reject));
      _showResult('Action failed.');
    }
  }

  void _showResult(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
      snackBarAnimationStyle: _reducedMotion
          ? AnimationStyle.noAnimation
          : null,
    );
  }

  Future<void> _resumeMining() async {
    if (!_initialized) return;
    final summary = await _controller.resume();
    if (!mounted) return;
    _refreshPresentation(announceCargo: false);
    _startRefreshTimer();
    if (summary != null) await _showOfflineReturn(summary);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _refreshTimer?.cancel();
        _refreshTimer = null;
        if (_initialized) {
          _checkpoint();
          _refreshPresentation(announceCargo: false);
        }
        break;
      case AppLifecycleState.resumed:
        unawaited(_resumeMining());
        break;
      default:
        break;
    }
    _audioManager.handleLifecycleChange(state);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _displayNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_initialized) _checkpoint(accrue: false);
    if (_createdAudioManager) unawaited(_audioManager.dispose());
    super.dispose();
  }

  /// Best-effort lifecycle checkpoint. The next load re-accrues if storage
  /// rejects this write.
  void _checkpoint({bool accrue = true}) {
    unawaited(
      _controller.checkpoint(accrue: accrue).catchError((error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Mining lifecycle checkpoint failed: $error\n$stackTrace');
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    final Widget surface;
    if (!_initialized) {
      surface = ColoredBox(
        key: Key('mining-shell-loading'),
        color: Color(0xFF07111E),
        child: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Loading mining operation',
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          ),
        ),
      );
    } else {
      final siteDeck = SiteDeckView.from(
        state: _displayState,
        content: _content,
        isBusy: _controller.isBusy,
      );
      final siteId = _openSiteId;
      if (_selectedDestination == MiningNavigationDestination.stellarMap) {
        surface = StellarMapScreen(
          cash: _displayState.cash,
          cargo: siteDeck.totalCargo,
          capacity: siteDeck.totalCapacity,
          projectedValue: siteDeck.projectedValue,
          view: StellarMapView.from(
            state: _displayState,
            content: _content,
            isBusy: _controller.isBusy,
          ),
          content: _content,
          onUnlock: _unlockPlanet,
          onTravel: _travelToPlanet,
          onDestinationSelected: _handleNavigation,
        );
      } else if (siteId == null) {
        surface = SiteDeckScreen(
          view: siteDeck,
          cash: _displayState.cash,
          onEnterSite: _enterSite,
          onUnlockSite: _unlockSite,
          onSellCargo: _sellCargo,
          onDestinationSelected: _handleNavigation,
        );
      } else {
        final fleetDock = FleetDockView.from(
          state: _displayState,
          content: _content,
          selectedBayId: _selectedBayId,
          isBusy: _controller.isBusy,
        );
        final mineSite = MineSiteView.from(
          state: _displayState,
          content: _content,
          siteId: siteId,
          selectedBayId: _selectedBayId,
          isBusy: _controller.isBusy,
        );
        surface = MineSiteScreen(
          view: mineSite,
          fleetDock: fleetDock,
          cash: _displayState.cash,
          reducedMotion: _reducedMotion,
          impactSequence: _landingBasinImpactSequence,
          onMiningImpact: _playMiningImpact,
          onGridCellTap: _handleSiteGridCellTap,
          onBayTap: _handleDockBayTap,
          onSpawnRig: _spawnRig,
          onSellCargo: _sellCargo,
          onBack: _leaveSite,
          onSettings: openSettings,
          onDestinationSelected: _handleNavigation,
        );
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFF07111E),
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (_initialized) unawaited(_audioManager.maybeStartBgm());
        },
        child: surface,
      ),
    );
  }
}
