import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_settings_sheet.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';
import 'package:horologium/mining/presentation/technology_sheet.dart';

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

  Future<void> _runSheetAction(
    Future<MiningActionResult> Function() operation, {
    required String successMessage,
  }) async {
    if (!_initialized || _controller.isBusy) return;
    final pendingOperation = operation();
    _refreshPresentation();
    try {
      final result = await pendingOperation;
      if (!mounted) return;
      _refreshPresentation();
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
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resumeMining() async {
    if (!_initialized) return;
    final summary = await _controller.resume();
    if (!mounted) return;
    _refreshPresentation();
    _startRefreshTimer();
    if (summary != null) await _showOfflineReturn(summary);
  }

  int _commissionedSiteCount() => _activePlanet.sites
      .where(
        (definition) =>
            _displayState.sites[definition.id]?.commissioned ?? false,
      )
      .length;

  int _cargoValue() {
    var value = 0.0;
    for (final definition in _activePlanet.sites) {
      final site = _displayState.sites[definition.id];
      if (site != null) {
        value += site.storedAmount * definition.saleValuePerUnit;
      }
    }
    return value.floor();
  }

  MiningPlanetDefinition get _activePlanet =>
      _content.planet(_displayState.activePlanetId);

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
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (_initialized) unawaited(_audioManager.maybeStartBgm());
        },
        child: SafeArea(
          child: Column(
            children: [
              MiningHud(
                planetName: _activePlanet.name,
                cash: _displayState.cash,
                commissionedSites: _commissionedSiteCount(),
                totalSites: _activePlanet.sites.length,
                cargoValue: _cargoValue(),
              ),
              const Expanded(
                child: Center(
                  key: Key('mining-shell-placeholder'),
                  child: Text('Mining operation ready'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
