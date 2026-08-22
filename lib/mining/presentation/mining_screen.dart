import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_sheet_view.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_action_sheet.dart';
import 'package:horologium/mining/presentation/mining_status_bar.dart';
import 'package:horologium/mining/presentation/mining_settings_sheet.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';
import 'package:horologium/mining/world/mining_game.dart';

class MiningScreen extends StatefulWidget {
  const MiningScreen({
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
  State<MiningScreen> createState() => _MiningScreenState();
}

/// Read-only identity handles into the mounted [MiningScreen] state.
///
/// The screen stays the single owner of the controller, audio manager, and
/// projected game; these getters exist so tests can assert that replacing
/// the game on an active-planet switch keeps the long-lived infrastructure
/// (one controller, one audio manager, one lifecycle observer) intact.
abstract class MiningScreenHandles implements State<MiningScreen> {
  MiningController get controller;
  AudioManager get audioManager;
  MiningGame get game;
}

class _MiningScreenState extends State<MiningScreen>
    with WidgetsBindingObserver
    implements MiningScreenHandles {
  late final MiningContentRegistry _content;
  late final MiningController _controller;
  late final AudioManager _audioManager;
  late MiningGame _game;
  late MiningSave _displayState;
  Timer? _refreshTimer;
  MiningSectorId? _selectedSectorId;
  late MiningSheetView _sheetView;
  bool _initialized = false;
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
    _game = _gameFor(
      planetId: _displayState.activePlanetId,
      initialProgress: _displayState.sectors,
    );
    _sheetView = MiningSheetView.from(
      state: _displayState,
      content: _content,
      selectedSectorId: _selectedSectorId,
      isBusy: false,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  MiningGame _gameFor({
    required MiningPlanetId planetId,
    required Map<MiningSectorId, SectorProgress> initialProgress,
  }) {
    return MiningGame(
      planet: _content.planet(planetId),
      initialProgress: initialProgress,
    )..onSelectionChanged = _handleSelectionChanged;
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
  MiningGame get game => _game;

  void _refreshPresentation() {
    if (!_initialized) return;
    _displayState = _controller.state;
    _replaceGameIfPlanetChanged();
    _game.reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _game.applyState(_displayState);
    _sheetView = MiningSheetView.from(
      state: _displayState,
      content: _content,
      selectedSectorId: _selectedSectorId,
      isBusy: _controller.isBusy,
    );
    if (mounted) setState(() {});
  }

  /// Swap the projected game when the active planet changed (a loaded save
  /// that starts elsewhere, a planet unlock, or travel). The replacement is
  /// keyed by planet id in [build] so the old world unmounts entirely, and
  /// selection resets to the sell tab.
  void _replaceGameIfPlanetChanged() {
    final activePlanetId = _displayState.activePlanetId;
    if (_game.planet.id == activePlanetId) return;
    _game.onSelectionChanged = null;
    _game = _gameFor(
      planetId: activePlanetId,
      initialProgress: _controller.state.sectors,
    );
    _selectedSectorId = null;
  }

  void _handleSelectionChanged(MiningSectorId? id) {
    _selectSector(id);
  }

  void _selectSector(MiningSectorId? id) {
    if (!_initialized) return;
    unawaited(_audioManager.maybeStartBgm());
    _selectedSectorId = id;
    _game.selectSector(id);
    if (id != null && _game.hasLoaded) {
      _game.focusOnSelection(sectorId: id, bottomObscuredFraction: 0.44);
    }
    _refreshPresentation();
  }

  Future<void> _onPrimaryAction() async {
    if (!_initialized) return;
    unawaited(_audioManager.maybeStartBgm());
    if (!_sheetView.primaryEnabled) return;

    final action = _sheetView.action;
    final selected = _selectedSectorId;
    late final Future<dynamic> operation;
    switch (action) {
      case MiningSheetAction.sell:
        operation = _controller.sellAllCargo();
        break;
      case MiningSheetAction.reveal:
        if (selected == null) return;
        operation = _controller.revealSector(selected);
        break;
      case MiningSheetAction.build:
        if (selected == null) return;
        operation = _controller.buildMine(selected);
        break;
      case MiningSheetAction.upgrade:
        if (selected == null) return;
        operation = _controller.upgradeMine(selected);
        break;
      case MiningSheetAction.none:
        return;
    }

    _refreshPresentation();
    try {
      final result = await operation;
      if (!mounted) return;
      _refreshPresentation();
      // Pass the sector captured before the await so the reward plays on
      // the sector that initiated the action, even if the player changed
      // tabs while the save was in flight.
      _playRewardAfterSuccess(action, result, sectorId: selected);
      _showResult(_successMessage(action, result));
    } catch (_) {
      if (!mounted) return;
      _refreshPresentation();
      _showResult('Action failed.');
    }
  }

  String _successMessage(MiningSheetAction action, dynamic result) {
    if (result is MiningActionResult) {
      if (!result.isSuccess) return result.message ?? 'Action failed.';
      switch (action) {
        case MiningSheetAction.reveal:
          return 'Sector revealed.';
        case MiningSheetAction.build:
          return 'Mine built.';
        case MiningSheetAction.upgrade:
          return 'Mine upgraded.';
        case MiningSheetAction.sell:
        case MiningSheetAction.none:
          return 'Action complete.';
      }
    }
    if (result is MiningSaleResult) {
      return result.isSuccess
          ? 'Sold cargo for ${result.revenue} cash.'
          : result.message ?? 'Action failed.';
    }
    return 'Action complete.';
  }

  void _showResult(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _playRewardAfterSuccess(
    MiningSheetAction action,
    dynamic result, {
    MiningSectorId? sectorId,
  }) {
    if (result is MiningActionResult && result.isSuccess) {
      unawaited(HapticFeedback.lightImpact());
      final effect = switch (action) {
        MiningSheetAction.reveal => MiningRewardEffect.reveal,
        MiningSheetAction.build => MiningRewardEffect.construction,
        MiningSheetAction.upgrade => MiningRewardEffect.tierUpgrade,
        MiningSheetAction.sell || MiningSheetAction.none => null,
      };
      if (effect != null) _game.playReward(effect, sectorId: sectorId);
    } else if (result is MiningSaleResult && result.isSuccess) {
      unawaited(HapticFeedback.mediumImpact());
      // Sale actions started from the sell tab capture sectorId = null as
      // an explicit "no sector" target — the reward originates from the
      // camera/global position, not any sector. Pass
      // fallbackToCurrentSelection: false so a null sectorId is respected
      // rather than falling back to whatever sector is selected by the
      // time the save completes.
      _game.playReward(
        MiningRewardEffect.sale,
        sectorId: sectorId,
        fallbackToCurrentSelection: false,
      );
    }
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

  Future<void> _resumeMining() async {
    if (!_initialized) return;
    final summary = await _controller.resume();
    if (!mounted) return;
    _refreshPresentation();
    _startRefreshTimer();
    if (summary != null) await _showOfflineReturn(summary);
  }

  Future<void> _showOfflineReturn(OfflineProductionSummary summary) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineReturnSheet(summary: summary, content: _content),
    );
  }

  void _openSettings() {
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

  MiningPlanetDefinition get _activePlanet =>
      _content.planet(_displayState.activePlanetId);

  int _revealedSectorCount() => _displayState.sectors.values
      .where((progress) => progress.revealed)
      .length;

  int _cargoValue() {
    var value = 0.0;
    for (final definition in _activePlanet.sectors) {
      final mine = _displayState.sectors[definition.id]?.mine;
      if (mine != null) {
        value += mine.storedAmount * definition.saleValuePerUnit;
      }
    }
    return value.floor();
  }

  Widget _buildSectorTabs() {
    return SizedBox(
      key: const Key('mining-sector-tabs'),
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _buildTab(
              key: const Key('mining-sell-tab'),
              label: 'SELL ALL CARGO',
              selected: _selectedSectorId == null,
              onPressed: () => _selectSector(null),
            ),
            for (final definition in _activePlanet.sectors)
              _buildTab(
                key: Key('mining-sector-${definition.id.name}'),
                label: definition.name,
                selected: _selectedSectorId == definition.id,
                onPressed: () => _selectSector(definition.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            key: const Key('mining-settings-button'),
            tooltip: 'Settings',
            onPressed: _openSettings,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xCC162133),
              foregroundColor: Colors.cyanAccent,
              side: const BorderSide(color: Colors.cyanAccent),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.settings),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.black : Colors.cyanAccent,
          backgroundColor: selected
              ? Colors.cyanAccent
              : const Color(0xCC162133),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.cyanAccent),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
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

  /// Best-effort lifecycle checkpoint. MiningSaveRepository.save() throws
  /// when SharedPreferences rejects a write; unawaited() does not consume
  /// that error, so a storage failure during pause/dispose would surface as
  /// an uncaught async exception. Swallow it here as a best-effort save
  /// failure — there is no UI to recover from after dispose, and the next
  /// load will re-accrue from the last persisted timestamp.
  void _checkpoint({bool accrue = true}) {
    unawaited(
      _controller.checkpoint(accrue: accrue).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        if (kDebugMode) {
          debugPrint('Mining lifecycle checkpoint failed: $error\n$stackTrace');
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    _game.reducedMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(
            key: ValueKey<MiningPlanetId>(_displayState.activePlanetId),
            game: _game,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: MiningStatusBar(
                      cash: _displayState.cash,
                      revealedSectors: _revealedSectorCount(),
                      totalSectors: _activePlanet.sectors.length,
                      cargoValue: _cargoValue(),
                    ),
                  ),
                  _buildSectorTabs(),
                  _buildSettingsButton(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiningActionSheet(
              view: _sheetView,
              onPrimaryAction: _onPrimaryAction,
            ),
          ),
        ],
      ),
    );
  }
}
