import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
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
  late MiningSave _displayState;
  Timer? _refreshTimer;
  bool _initialized = false;
  bool _reducedMotion = false;
  bool _recoverySnackBarScheduled = false;
  DockBayId? _selectedBayId;
  MiningSiteId? _openSiteId;
  MiningNavigationDestination _selectedDestination =
      MiningNavigationDestination.siteDeck;

  @override
  void initState() {
    super.initState();
    _audioManager = widget.audioManager ?? AudioManager();
    _content = widget.content ?? MiningContentRegistry.stellarMining();
    final nowUtc = widget.nowUtc ?? () => DateTime.now().toUtc();
    _controller = MiningController(
      content: _content,
      repository: widget.repository ?? MiningSaveRepository(content: _content),
      nowUtc: nowUtc,
    );
    _displayState = MiningSave.initial(nowUtc: nowUtc());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _audioManager.loadPrefs();
    await _controller.initialize();
    final pendingReturnSummary = _controller.takePendingReturnSummary();
    if (!mounted) return;
    _initialized = true;
    _refreshPresentation();
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_controller.isBusy) {
        _controller.refresh();
        _refreshPresentation();
      }
    });
  }

  @override
  MiningController get controller => _controller;

  @override
  AudioManager get audioManager => _audioManager;

  @override
  bool get reducedMotion => _reducedMotion;

  void _refreshPresentation() {
    if (!_initialized) return;
    _displayState = _controller.state;
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineReturnSheet(summary: summary, content: _content),
    );
  }

  @override
  void openSettings() {
    if (!_initialized) return;
    unawaited(_audioManager.maybeStartBgm());
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MiningSettingsSheet(audioManager: _audioManager),
      ),
    );
  }

  @override
  void openTechnology() {
    if (!_initialized) return;
    unawaited(_audioManager.maybeStartBgm());
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TechnologySheet(
          view: TechnologySheetView.from(
            state: _controller.state,
            content: _content,
          ),
          onPurchase: _purchaseTechnology,
        ),
      ),
    );
  }

  void _purchaseTechnology(TechnologyTrack track) {
    _runSheetAction(
      () => _controller.purchaseTechnology(track),
      successMessage: 'Technology upgraded.',
    );
  }

  void _unlockPlanet(MiningPlanetId id) {
    _runSheetAction(
      () => _controller.unlockPlanet(id),
      successMessage: '${_content.planet(id).name} unlocked.',
    );
  }

  void _travelToPlanet(MiningPlanetId id) {
    _runSheetAction(
      () => _controller.switchPlanet(id),
      successMessage: 'Traveled to ${_content.planet(id).name}.',
    );
  }

  void _unlockSite(MiningSiteId id) {
    _runSheetAction(
      () => _controller.unlockSite(id),
      successMessage: 'Site unlocked.',
    );
  }

  void _spawnRig() {
    _runSheetAction(_controller.spawnRig, successMessage: 'T1 rig spawned.');
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
      _showResult('Select an occupied rig bay.');
      return;
    }

    final selectedBayId = _selectedBayId;
    if (selectedBayId == null || selectedBayId == bayId) {
      setState(() => _selectedBayId = selectedBayId == bayId ? null : bayId);
      return;
    }

    if (tappedBay.canMergeWithSelection) {
      setState(() => _selectedBayId = null);
      _runSheetAction(
        () => _controller.mergeDockRigs(selectedBayId, bayId),
        successMessage: 'Rigs merged.',
      );
      return;
    }

    setState(() => _selectedBayId = bayId);
  }

  void _enterSite(MiningSiteId id) {
    if (!_initialized || _controller.isBusy) return;
    unawaited(_audioManager.maybeStartBgm());
    setState(() => _openSiteId = id);
  }

  void _leaveSite() {
    if (!mounted) return;
    setState(() => _openSiteId = null);
  }

  void _handleSiteNodeTap(MiningNodeId nodeId) {
    final siteId = _openSiteId;
    if (!_initialized || _controller.isBusy || siteId == null) return;
    final view = MineSiteView.from(
      state: _controller.state,
      content: _content,
      siteId: siteId,
      selectedBayId: _selectedBayId,
      isBusy: false,
    );
    final node = view.node(nodeId);
    final selectedBayId = _selectedBayId;
    if (node.canDeploy && selectedBayId != null) {
      _runSheetAction(
        () => _controller.deployRig(selectedBayId, siteId, nodeId),
        successMessage: 'Rig deployed.',
      );
    } else if (node.canRecall) {
      _runSheetAction(
        () => _controller.recallRig(siteId, nodeId),
        successMessage: 'Rig recalled.',
      );
    } else if (node.disabledReason != null) {
      _showResult(node.disabledReason!);
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
    setState(() {
      _selectedDestination = destination;
      _openSiteId = null;
    });
  }

  Future<void> _runSheetAction(
    Future<MiningActionResult> Function() operation, {
    required String successMessage,
  }) async {
    if (!_initialized || _controller.isBusy) return;
    final activePlanetBefore = _controller.state.activePlanetId;
    final pendingOperation = operation();
    _refreshPresentation();
    try {
      final result = await pendingOperation;
      if (!mounted) return;
      if (result.isSuccess &&
          _controller.state.activePlanetId != activePlanetBefore) {
        _selectedBayId = null;
      } else {
        _preserveDockSelection();
      }
      _refreshPresentation();
      if (result.isSuccess) {
        unawaited(HapticFeedback.lightImpact());
      }
      _showResult(
        result.isSuccess
            ? result.message ?? successMessage
            : result.message ?? 'Action failed.',
      );
    } catch (_) {
      if (!mounted) return;
      _refreshPresentation();
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
    _refreshPresentation();
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
          _refreshPresentation();
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
    WidgetsBinding.instance.removeObserver(this);
    if (_initialized) _checkpoint(accrue: false);
    unawaited(_audioManager.dispose());
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
      final fleetDock = FleetDockView.from(
        state: _displayState,
        content: _content,
        selectedBayId: _selectedBayId,
        isBusy: _controller.isBusy,
      );
      final siteId = _openSiteId;
      if (_selectedDestination == MiningNavigationDestination.stellarMap) {
        surface = StellarMapScreen(
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
          fleetDock: fleetDock,
          cash: _displayState.cash,
          onEnterSite: _enterSite,
          onUnlockSite: _unlockSite,
          onBayTap: _handleDockBayTap,
          onSpawnRig: _spawnRig,
          onDestinationSelected: _handleNavigation,
        );
      } else {
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
          onNodeTap: _handleSiteNodeTap,
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
