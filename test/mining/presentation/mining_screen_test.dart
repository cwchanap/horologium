import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_screen.dart';
import 'package:horologium/mining/world/mining_components.dart';
import 'package:horologium/mining/world/mining_game.dart';
import '../../support/fake_background_music_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedMiningSaveRepository extends MiningSaveRepository {
  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();

  @override
  Future<void> save(MiningSave state) async {
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
      await allowSave.future;
    }
    await super.save(state);
  }
}

class LoadGatedMiningSaveRepository extends MiningSaveRepository {
  final loadStarted = Completer<void>();
  final allowLoad = Completer<void>();

  @override
  Future<MiningLoadResult> load({required DateTime nowUtc}) async {
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
      await allowLoad.future;
    }
    return super.load(nowUtc: nowUtc);
  }
}

class DelayedAudioPrefsManager extends AudioManager {
  DelayedAudioPrefsManager({required super.backgroundMusicPlayer});

  final loadStarted = Completer<void>();
  final allowLoad = Completer<void>();

  @override
  Future<void> loadPrefs() async {
    loadStarted.complete();
    await allowLoad.future;
    await super.loadPrefs();
  }
}

class FailingMiningSaveRepository extends MiningSaveRepository {
  @override
  Future<void> save(MiningSave state) async {
    throw StateError('Mining save was rejected by SharedPreferences.');
  }
}

const _viewports = [Size(360, 640), Size(430, 932)];
final _now = DateTime.utc(2026, 8, 18, 12);

MiningSave _seededLunarActiveSave() => MiningSave(
  cash: 5000,
  lastAccruedAtUtc: _now,
  technology: const TechnologyLevels(surveying: 3),
  unlockedPlanetIds: const {
    MiningPlanetId.homeworld,
    MiningPlanetId.lunarFrontier,
  },
  activePlanetId: MiningPlanetId.lunarFrontier,
  sectors: {
    MiningSectorId.landingBasin: const SectorProgress(
      revealed: true,
      mine: MineState(level: 1, storedAmount: 0),
    ),
    MiningSectorId.carbonRidge: const SectorProgress(revealed: false),
    MiningSectorId.graniteCrater: const SectorProgress(revealed: false),
    MiningSectorId.frozenBasin: const SectorProgress(
      revealed: true,
      mine: MineState(level: 2, storedAmount: 12),
    ),
    MiningSectorId.titaniumHighlands: const SectorProgress(revealed: false),
    MiningSectorId.heliumMare: const SectorProgress(revealed: false),
  },
);

Future<void> pumpMiningScreen(
  WidgetTester tester,
  Size viewport, {
  MiningSaveRepository? repository,
  DateTime Function()? nowUtc,
  AudioManager? audioManager,
  bool disableAnimations = false,
  int pumpCycles = 80,
  Key? screenKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MiningScreen(
          key: screenKey,
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: nowUtc ?? () => _now,
          audioManager: audioManager,
        ),
      ),
    ),
  );

  for (var i = 0; i < pumpCycles; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> pushMiningScreen(
  WidgetTester tester,
  Size viewport, {
  required MiningSaveRepository repository,
  required DateTime Function() nowUtc,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  late BuildContext navigatorContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          navigatorContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  unawaited(
    Navigator.of(navigatorContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaQuery(
          data: const MediaQueryData(),
          child: MiningScreen(
            content: MiningContentRegistry.stellarMining(),
            repository: repository,
            nowUtc: nowUtc,
          ),
        ),
      ),
    ),
  );

  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

void expectMiningStatusToStayFocused(WidgetTester tester) {
  for (final label in const [
    'Population',
    'Workers',
    'Happiness',
    'Research',
  ]) {
    expect(find.text(label), findsNothing);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final viewport in _viewports) {
    testWidgets('renders without overflow at $viewport', (tester) async {
      await pumpMiningScreen(tester, viewport);

      expect(find.text('Landing Basin'), findsWidgets);
      expect(find.text('SELL ALL CARGO'), findsOneWidget);
      expectMiningStatusToStayFocused(tester);
      expect(tester.takeException(), isNull);

      final buttonSize = tester.getSize(
        find.byKey(const Key('mining-primary-action')),
      );
      expect(buttonSize.height, greaterThanOrEqualTo(56));

      final settingsButton = tester.getRect(
        find.byKey(const Key('mining-settings-button')),
      );
      expect(
        settingsButton.overlaps(
          tester.getRect(find.byKey(const Key('mining-status-bar'))),
        ),
        isFalse,
      );
      expect(
        settingsButton.overlaps(
          tester.getRect(find.byKey(const Key('mining-sector-tabs'))),
        ),
        isFalse,
      );
    });

    testWidgets(
      'builds Landing Basin and exposes its upgrade state at $viewport',
      (tester) async {
        await pumpMiningScreen(tester, viewport);

        await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
        await tester.pump();
        expect(find.textContaining('Build'), findsWidgets);

        await tester.tap(find.byKey(const Key('mining-primary-action')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('Level 1'), findsOneWidget);
        expect(find.textContaining('Upgrade'), findsWidgets);
        expect(find.text('Mine built.'), findsOneWidget);
        expectMiningStatusToStayFocused(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('loads saved audio prefs without autoplaying at initialization', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio.musicEnabled': false,
      'audio.musicVolume': 0.8,
    });
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      audioManager: audioManager,
    );

    expect(audioManager.musicEnabled, isFalse);
    expect(audioManager.musicVolume, 0.8);
    expect(player.playedAssets, isEmpty);
  });

  testWidgets(
    'gates sector and Settings gestures until saved audio prefs finish loading',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'audio.musicEnabled': false,
      });
      final player = FakeBackgroundMusicPlayer();
      final audioManager = DelayedAudioPrefsManager(
        backgroundMusicPlayer: player,
      );

      await pumpMiningScreen(
        tester,
        _viewports.first,
        audioManager: audioManager,
        pumpCycles: 1,
      );
      await audioManager.loadStarted.future;

      await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
      await tester.pump();
      expect(player.playedAssets, isEmpty);

      await tester.tap(find.byKey(const Key('mining-settings-button')));
      await tester.pump();
      expect(find.byKey(const Key('mining-settings-sheet')), findsNothing);

      audioManager.allowLoad.complete();
      await tester.pump();
      await tester.pump();
      expect(audioManager.musicEnabled, isFalse);

      await tester.tap(find.byKey(const Key('mining-settings-button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.descendant(
                of: find.byKey(const Key('mining-settings-sheet')),
                matching: find.byType(SwitchListTile),
              ),
            )
            .value,
        isFalse,
      );
      expect(player.playedAssets, isEmpty);
    },
  );

  testWidgets('a sector gesture starts BGM through the injected manager', (
    tester,
  ) async {
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      audioManager: audioManager,
    );

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();

    expect(player.playedAssets, <String>['audio/background.mp3']);
  });

  testWidgets('the primary action starts BGM through the injected manager', (
    tester,
  ) async {
    final repository = MiningSaveRepository(
      content: MiningContentRegistry.stellarMining(),
    );
    await repository.save(
      MiningSave(
        cash: 1000,
        lastAccruedAtUtc: _now,
        technology: const TechnologyLevels(),
        unlockedPlanetIds: const {MiningPlanetId.homeworld},
        activePlanetId: MiningPlanetId.homeworld,
        sectors: {
          MiningSectorId.landingBasin: const SectorProgress(
            revealed: true,
            mine: MineState(level: 1, storedAmount: 10),
          ),
          MiningSectorId.carbonRidge: const SectorProgress(revealed: false),
          MiningSectorId.graniteCrater: const SectorProgress(revealed: false),
          MiningSectorId.frozenBasin: const SectorProgress(revealed: false),
          MiningSectorId.titaniumHighlands: const SectorProgress(
            revealed: false,
          ),
          MiningSectorId.heliumMare: const SectorProgress(revealed: false),
        },
      ),
    );
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      audioManager: audioManager,
    );
    player.playedAssets.clear();

    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(player.playedAssets, <String>['audio/background.mp3']);
  });

  testWidgets('opening Settings starts BGM through the injected manager', (
    tester,
  ) async {
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      audioManager: audioManager,
    );

    await tester.tap(find.byKey(const Key('mining-settings-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);
    expect(player.playedAssets, <String>['audio/background.mp3']);
  });

  testWidgets('settings reflect and delegate the AudioManager state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio.musicEnabled': false,
      'audio.musicVolume': 0.75,
    });
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      audioManager: audioManager,
    );
    await tester.tap(find.byKey(const Key('mining-settings-button')));
    await tester.pump(const Duration(milliseconds: 300));

    final sheet = find.byKey(const Key('mining-settings-sheet'));
    final switchTile = find.descendant(
      of: sheet,
      matching: find.byType(SwitchListTile),
    );
    final slider = find.descendant(of: sheet, matching: find.byType(Slider));
    expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
    expect(tester.widget<Slider>(slider).value, 0.75);

    tester.widget<SwitchListTile>(switchTile).onChanged!.call(true);
    await tester.pump();
    expect(audioManager.musicEnabled, isTrue);

    final initialVolume = audioManager.musicVolume;
    tester.widget<Slider>(slider).onChanged!.call(initialVolume / 2);
    await tester.pump();
    expect(audioManager.musicVolume, lessThan(initialVolume));

    Navigator.of(tester.element(sheet)).pop();
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-settings-button')));
    await tester.pump(const Duration(milliseconds: 300));

    final reopenedSheet = find.byKey(const Key('mining-settings-sheet'));
    expect(
      tester
          .widget<SwitchListTile>(
            find.descendant(
              of: reopenedSheet,
              matching: find.byType(SwitchListTile),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Slider>(
            find.descendant(of: reopenedSheet, matching: find.byType(Slider)),
          )
          .value,
      audioManager.musicVolume,
    );
  });

  testWidgets('disables the primary action while a mutation is saving', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    // Seed so initialize() loads an existing key and does not persist; the
    // first repository.save() must be the build mutation, which gates on
    // allowSave.
    await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
    await pumpMiningScreen(tester, _viewports.first, repository: repository);

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await repository.saveStarted.future;
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-primary-action')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);

    repository.allowSave.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('does not use context after a delayed action route is popped', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    // Seed so initialize() loads an existing key and does not persist; the
    // first repository.save() must be the build mutation, which gates on
    // allowSave.
    await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
    await pushMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => _now,
    );

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await repository.saveStarted.future;
    await tester.pump();

    final screenContext = tester.element(find.byType(MiningScreen));
    expect(Navigator.of(screenContext).canPop(), isTrue);
    Navigator.of(screenContext).pop();
    await tester.pump();
    repository.allowSave.complete();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('route exit checkpoints the latest published mining state', (
    tester,
  ) async {
    var now = _now;
    final repository = MiningSaveRepository(
      content: MiningContentRegistry.stellarMining(),
    );
    await pushMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
    );

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    now = _now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));

    final screenContext = tester.element(find.byType(MiningScreen));
    expect(Navigator.of(screenContext).canPop(), isTrue);
    Navigator.of(screenContext).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MiningScreen), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final raw =
        jsonDecode(prefs.getString(MiningSaveRepository.saveKey)!)
            as Map<String, Object?>;
    final sectors = raw['sectors']! as Map<String, Object?>;
    final landing = sectors['landingBasin']! as Map<String, Object?>;
    final mine = landing['mine']! as Map<String, Object?>;
    expect(mine['storedAmount'], 3.0);
  });

  testWidgets('pause checkpoint persists an active gold mine for recreation', (
    tester,
  ) async {
    var now = _now;
    final repository = MiningSaveRepository(
      content: MiningContentRegistry.stellarMining(),
    );
    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
    );

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    now = _now.add(const Duration(seconds: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));

    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
      screenKey: const Key('recreated-mining-screen'),
    );
    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();

    expect(find.textContaining('Level 1'), findsOneWidget);
    expect(find.textContaining('stored 3.0'), findsOneWidget);
  });

  testWidgets('resume presents offline gold production once', (tester) async {
    var now = _now;
    final repository = MiningSaveRepository(
      content: MiningContentRegistry.stellarMining(),
    );
    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
    );

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    now = _now.add(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
    expect(find.textContaining('Gold'), findsWidgets);

    await tester.tap(find.byKey(const Key('offline-return-dismiss')));
    await tester.pump(const Duration(milliseconds: 300));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('offline-return-sheet')), findsNothing);

    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
      screenKey: const Key('cold-recreated-mining-screen'),
    );
    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
    expect(find.textContaining('Gold'), findsWidgets);

    await tester.tap(find.byKey(const Key('offline-return-dismiss')));
    await tester.pump(const Duration(milliseconds: 300));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));

    await pumpMiningScreen(
      tester,
      _viewports.first,
      repository: repository,
      nowUtc: () => now,
      screenKey: const Key('cold-recreated-mining-screen-again'),
    );
    expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
  });

  testWidgets('malformed mining save shows one non-blocking recovery message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      MiningSaveRepository.saveKey: '{ malformed mining json',
    });

    await pumpMiningScreen(tester, _viewports.first, pumpCycles: 5);

    expect(
      find.text(
        'Mining progress could not be loaded, so a fresh mining save was '
        'started.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mining-primary-action')), findsOneWidget);
  });

  testWidgets(
    'reduced motion keeps reveal build upgrade and sale confirmations',
    (tester) async {
      final repository = MiningSaveRepository(
        content: MiningContentRegistry.stellarMining(),
      );
      await repository.save(
        MiningSave(
          cash: 1000,
          lastAccruedAtUtc: _now,
          technology: const TechnologyLevels(),
          unlockedPlanetIds: const {MiningPlanetId.homeworld},
          activePlanetId: MiningPlanetId.homeworld,
          sectors: {
            MiningSectorId.landingBasin: const SectorProgress(
              revealed: true,
              mine: MineState(level: 1, storedAmount: 10),
            ),
            MiningSectorId.carbonRidge: const SectorProgress(revealed: false),
            MiningSectorId.graniteCrater: const SectorProgress(revealed: false),
            MiningSectorId.frozenBasin: const SectorProgress(revealed: false),
            MiningSectorId.titaniumHighlands: const SectorProgress(
              revealed: false,
            ),
            MiningSectorId.heliumMare: const SectorProgress(revealed: false),
          },
        ),
      );
      await pumpMiningScreen(
        tester,
        _viewports[1],
        repository: repository,
        disableAnimations: true,
      );

      Future<void> tapAction(String message) async {
        await tester.tap(find.byKey(const Key('mining-primary-action')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(message), findsOneWidget);
      }

      final carbonTab = find.byKey(const Key('mining-sector-carbonRidge'));
      await tester.ensureVisible(carbonTab);
      await tester.tap(carbonTab);
      await tester.pump();
      await tapAction('Sector revealed.');
      expect(find.text('Build for 100 cash'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: find.byKey(const Key('mining-primary-action')),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tapAction('Mine built.');
      await tapAction('Mine upgraded.');

      final sellTab = find.byKey(const Key('mining-sell-tab'));
      await tester.ensureVisible(sellTab);
      await tester.tap(sellTab);
      await tester.pump();
      await tapAction('Sold cargo for 40 cash.');
    },
  );

  testWidgets(
    'construction reward targets the sector that started the action when '
    'tabs change during the save',
    (tester) async {
      final repository = DelayedMiningSaveRepository();
      // Seed so initialize() loads an existing key and does not persist;
      // the first repository.save() must be the build mutation, which
      // gates on allowSave.
      await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
      await pumpMiningScreen(
        tester,
        _viewports.first,
        repository: repository,
        // Reduced motion shortens the reward visual lifetime, but we
        // inspect children immediately after the save completes, before
        // the fade-out removes the component.
        disableAnimations: true,
      );

      // Start "Build Landing Basin" — the save gates on repository.allowSave.
      await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mining-primary-action')));
      await repository.saveStarted.future;
      await tester.pump();

      // While the save is in flight, switch to Carbon Ridge. The sector
      // tabs stay enabled during a save, so this changes _selectedSectorId
      // before the reward plays.
      final carbonTab = find.byKey(const Key('mining-sector-carbonRidge'));
      await tester.ensureVisible(carbonTab);
      await tester.tap(carbonTab);
      await tester.pump();

      // Complete the save — the reward should now play on Landing Basin
      // (the sector captured when the action started), not Carbon Ridge.
      repository.allowSave.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final game =
          (tester.widget(find.byWidgetPredicate((w) => w is GameWidget))
                      as GameWidget)
                  .game
              as MiningGame;
      final landing = game.sector(MiningSectorId.landingBasin);
      final carbon = game.sector(MiningSectorId.carbonRidge);

      expect(
        landing.children.whereType<MiningRewardVisualComponent>(),
        isNotEmpty,
        reason:
            'Construction reward should play on Landing Basin, the '
            'sector that started the build action.',
      );
      expect(
        carbon.children.whereType<MiningRewardVisualComponent>(),
        isEmpty,
        reason:
            'Construction reward must not leak to Carbon Ridge just '
            'because the player switched tabs during the save.',
      );

      expect(find.text('Mine built.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sell reward originates from the camera position when tabs change '
    'during the save',
    (tester) async {
      // Seed cargo so Sell All has something to sell. Use a separate
      // delayed repository with its allowSave pre-completed so the seed
      // write finishes immediately; then use a fresh delayed repository
      // for the screen so the Sell All save still gates on allowSave.
      final seed = DelayedMiningSaveRepository()..allowSave.complete();
      await seed.save(
        MiningSave(
          cash: 1000,
          lastAccruedAtUtc: _now,
          technology: const TechnologyLevels(),
          unlockedPlanetIds: const {MiningPlanetId.homeworld},
          activePlanetId: MiningPlanetId.homeworld,
          sectors: {
            MiningSectorId.landingBasin: const SectorProgress(
              revealed: true,
              mine: MineState(level: 1, storedAmount: 10),
            ),
            MiningSectorId.carbonRidge: const SectorProgress(revealed: false),
            MiningSectorId.graniteCrater: const SectorProgress(revealed: false),
            MiningSectorId.frozenBasin: const SectorProgress(revealed: false),
            MiningSectorId.titaniumHighlands: const SectorProgress(
              revealed: false,
            ),
            MiningSectorId.heliumMare: const SectorProgress(revealed: false),
          },
        ),
      );

      final repository = DelayedMiningSaveRepository();
      await pumpMiningScreen(
        tester,
        _viewports.first,
        repository: repository,
        disableAnimations: true,
      );

      // Start Sell All from the sell tab — the save gates on
      // repository.allowSave. The sell tab has no sector selected, so the
      // captured sectorId is intentionally null.
      final sellTab = find.byKey(const Key('mining-sell-tab'));
      await tester.ensureVisible(sellTab);
      await tester.tap(sellTab);
      await tester.pump();
      await tester.tap(find.byKey(const Key('mining-primary-action')));
      await repository.saveStarted.future;
      await tester.pump();

      // While the save is in flight, switch to Carbon Ridge. The sector
      // tabs stay enabled during a save, so this changes _selectedSectorId
      // before the reward plays.
      final carbonTab = find.byKey(const Key('mining-sector-carbonRidge'));
      await tester.ensureVisible(carbonTab);
      await tester.tap(carbonTab);
      await tester.pump();

      // Complete the save — the sale reward should originate from the
      // camera/global position (the sell tab had no sector), not from
      // Carbon Ridge just because the player switched tabs.
      repository.allowSave.complete();
      await tester.pump();
      await tester.pump();

      final game =
          (tester.widget(find.byWidgetPredicate((w) => w is GameWidget))
                      as GameWidget)
                  .game
              as MiningGame;
      final carbon = game.sector(MiningSectorId.carbonRidge);

      // The sale particle is added to the world, whose pending additions
      // are not always visible through world.children in the test
      // environment. Instead, verify via lastSaleRewardSource, which
      // records the world-space source position the particle was created
      // at.
      expect(
        game.lastSaleRewardSource,
        isNotNull,
        reason: 'Sale reward should play after Sell All completes.',
      );

      final distanceToCamera = game.lastSaleRewardSource!.distanceTo(
        game.camera.viewfinder.position,
      );
      final distanceToCarbon = game.lastSaleRewardSource!.distanceTo(
        carbon.position,
      );
      expect(
        distanceToCamera,
        lessThan(distanceToCarbon),
        reason:
            'Sale reward must originate from the camera/global sale '
            'position for actions started from the sell tab, not from '
            'Carbon Ridge just because the player switched tabs during '
            'the save.',
      );

      expect(find.text('Sold cargo for 40 cash.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pause checkpoint swallows storage failure as a best-effort save',
    (tester) async {
      final repository = FailingMiningSaveRepository();
      // Seed so initialize() loads an existing key and does not persist
      // through the failing repository; only the lifecycle checkpoint
      // exercises the failing save path.
      await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
      await pumpMiningScreen(tester, _viewports.first, repository: repository);

      // Trigger a lifecycle pause — checkpoint() calls save(), which the
      // failing repository rejects. The screen must consume that error
      // rather than letting it surface as an uncaught async exception.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dispose checkpoint swallows storage failure as a best-effort save',
    (tester) async {
      final repository = FailingMiningSaveRepository();
      // Seed so initialize() loads an existing key and does not persist
      // through the failing repository; only the dispose checkpoint
      // exercises the failing save path.
      await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
      await pumpMiningScreen(tester, _viewports.first, repository: repository);

      // Unmount the MiningScreen to trigger dispose(), which checkpoints
      // with accrue: false. The failing repository rejects the save; the
      // screen must consume that error rather than surfacing it after
      // dispose when there is no UI to recover.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initializes even when the initial-save write fails on a fresh install',
    (tester) async {
      final repository = FailingMiningSaveRepository();
      // No seed — initialize() must persist the freshly constructed initial
      // state, and that write fails. The screen must still initialize so the
      // playable surface is not permanently gated.
      await pumpMiningScreen(tester, _viewports.first, repository: repository);

      expect(
        find.byKey(const Key('mining-sector-landingBasin')),
        findsOneWidget,
        reason: 'Sector tabs must render after a failed initial save.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initState builds the initial game before controller initialization',
    (tester) async {
      // Seed so initialize() loads an existing save; gate that load so the
      // controller state cannot exist while the first frames build.
      await MiningSaveRepository().save(MiningSave.initial(nowUtc: _now));
      final repository = LoadGatedMiningSaveRepository();

      await pumpMiningScreen(
        tester,
        _viewports.first,
        repository: repository,
        pumpCycles: 2,
      );
      await repository.loadStarted.future;
      await tester.pump();

      final handles =
          tester.state(find.byType(MiningScreen)) as MiningScreenHandles;
      final initialGame = handles.game;
      expect(initialGame.planet.id, MiningPlanetId.homeworld);
      expect(
        initialGame.initialProgress,
        MiningSave.initial(nowUtc: _now).sectors,
        reason:
            'Cold start must project the initial display sectors; '
            'controller state does not exist yet.',
      );
      expect(
        find.byKey(const ValueKey(MiningPlanetId.homeworld)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Releasing the load finishes initialization on the same Homeworld
      // projection; no replacement happens when the planet did not change.
      repository.allowLoad.complete();
      await tester.pump(const Duration(milliseconds: 500));
      expect(handles.game, same(initialGame));
    },
  );

  testWidgets(
    'switching the active planet replaces the projected game safely',
    (tester) async {
      // Seed an unlocked save that is already active on Lunar Frontier, then
      // gate the load so the cold-start Homeworld projection can be captured
      // before the controller state arrives.
      final seed = MiningSaveRepository(
        content: MiningContentRegistry.stellarMining(),
      );
      await seed.save(_seededLunarActiveSave());

      final repository = LoadGatedMiningSaveRepository();
      var now = _now;
      final player = FakeBackgroundMusicPlayer();
      final audioManager = AudioManager(backgroundMusicPlayer: player);

      await pumpMiningScreen(
        tester,
        _viewports.first,
        repository: repository,
        nowUtc: () => now,
        audioManager: audioManager,
        disableAnimations: true,
        pumpCycles: 2,
      );
      await repository.loadStarted.future;
      await tester.pump();

      MiningGame currentGame() =>
          (tester.widget(find.byWidgetPredicate((w) => w is GameWidget))
                      as GameWidget)
                  .game
              as MiningGame;
      final handles =
          tester.state(find.byType(MiningScreen)) as MiningScreenHandles;
      final originalController = handles.controller;
      final oldGame = currentGame();
      expect(oldGame.planet.id, MiningPlanetId.homeworld);
      final oldSelections = <MiningSectorId>[];
      oldGame.onSelectionChanged = (id) =>
          oldSelections.add(id as MiningSectorId);

      // Deliver the Lunar-active controller state.
      repository.allowLoad.complete();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final newGame = currentGame();
      expect(
        find.byKey(const ValueKey(MiningPlanetId.lunarFrontier)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(MiningPlanetId.homeworld)),
        findsNothing,
      );
      expect(newGame, isNot(same(oldGame)));
      expect(newGame.planet.id, MiningPlanetId.lunarFrontier);
      expect(handles.controller, same(originalController));
      expect(handles.audioManager, same(audioManager));

      // The replacement projects the controller's Lunar sectors.
      expect(newGame.hasLoaded, isTrue);
      expect(
        newGame.sector(MiningSectorId.frozenBasin).mine,
        const MineState(level: 2, storedAmount: 12),
      );

      // Later selection and reward actions route to the new game only.
      await tester.tap(find.byKey(const Key('mining-sector-frozenBasin')));
      await tester.pump();
      expect(oldSelections, isEmpty);

      // Selection reset to Sell: the primary action sells Lunar cargo
      // straight from the replacement.
      await tester.ensureVisible(find.byKey(const Key('mining-sell-tab')));
      await tester.tap(find.byKey(const Key('mining-sell-tab')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mining-primary-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Sold cargo for 72 cash.'), findsOneWidget);
      expect(newGame.lastSaleRewardSource, isNotNull);
      expect(oldGame.lastSaleRewardSource, isNull);
      expect(oldSelections, isEmpty);

      // The single refresh timer and lifecycle observer survive the swap:
      // a pause checkpoint plus offline resume still flows through the
      // original controller exactly once.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 500));
      now = _now.add(const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
