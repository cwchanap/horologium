import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';

class CountingMiningSaveRepository extends MiningSaveRepository {
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    await super.save(state);
  }
}

class DelayedAudioPrefsManager extends AudioManager {
  DelayedAudioPrefsManager({required super.backgroundMusicPlayer});

  final loadStarted = Completer<void>();
  final allowLoad = Completer<void>();

  @override
  Future<void> loadPrefs() async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    await allowLoad.future;
    await super.loadPrefs();
  }
}

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

const _viewport = Size(360, 640);
final _start = DateTime.utc(2026, 8, 26, 12);

MiningSave deployedLandingBasin(DateTime now) {
  final base = MiningSave.initial(nowUtc: now);
  final landing = base.sites[MiningSiteId.landingBasin]!;
  final sites = <MiningSiteId, SiteProgress>{...base.sites};
  sites[MiningSiteId.landingBasin] = landing.copyWith(
    commissioned: true,
    rigByNode: {...landing.rigByNode, MiningNodeId.n1: RigTier.t1},
  );
  return base.copyWith(sites: sites);
}

Future<void> pumpShell(
  WidgetTester tester, {
  MiningSaveRepository? repository,
  TestClock? clock,
  AudioManager? audioManager,
  bool disableAnimations = false,
  Key? shellKey,
  int pumpCycles = 6,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  final testClock = clock ?? TestClock(_start);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MiningShell(
          key: shellKey,
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: testClock.call,
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

MiningShellHandles shellHandles(WidgetTester tester) =>
    tester.state(find.byType(MiningShell)) as MiningShellHandles;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the Site Deck and active-planet HUD', (tester) async {
    await pumpShell(tester);

    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(find.byKey(const Key('fleet-dock')), findsOneWidget);
    expect(find.byKey(const Key('mining-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mining-hud')), findsOneWidget);
    expect(find.text('Homeworld'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing save attempts initial persistence', (tester) async {
    final repository = CountingMiningSaveRepository();

    await pumpShell(tester, repository: repository);

    expect(repository.saveCount, 1);
    expect(shellHandles(tester).controller.state.cash, 100);
  });

  testWidgets('Site Deck wires bay selection, merge, spawn, and site entry', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    await pumpShell(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.pump(const Duration(milliseconds: 300));

    final controller = shellHandles(tester).controller;
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
      isNull,
    );
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
      RigTier.t2,
    );

    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
      RigTier.t1,
    );
    expect(controller.state.cash, 75);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    expect(find.text('Landing Basin selected.'), findsOneWidget);
  });

  testWidgets('Site Deck unlocks an eligible site through the controller', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        cash: 300,
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
              .copyWith(unlocked: true),
        },
      ),
    );
    await pumpShell(tester, repository: repository);

    await tester.ensureVisible(
      find.byKey(const Key('site-card-carbonRidge-unlock')),
    );
    await tester.tap(find.byKey(const Key('site-card-carbonRidge-unlock')));
    await tester.pump(const Duration(milliseconds: 300));

    final controller = shellHandles(tester).controller;
    expect(controller.state.sites[MiningSiteId.carbonRidge]!.unlocked, isTrue);
    expect(controller.state.cash, 50);
  });

  testWidgets(
    'recovered save attempts initial persistence and explains reset',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: '{ malformed mining json',
      });
      final repository = CountingMiningSaveRepository();

      await pumpShell(tester, repository: repository, pumpCycles: 12);

      expect(repository.saveCount, 1);
      expect(
        find.text(
          'Mining progress could not be loaded, so a fresh mining save was '
          'started.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timer refresh accrues cargo without persisting', (tester) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(_start));
    final savesBeforeTicks = repository.saveCount;

    await pumpShell(tester, repository: repository, clock: clock);
    clock.now = _start.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    final hud = find.byKey(const Key('mining-hud'));
    expect(find.descendant(of: hud, matching: find.text('4')), findsOneWidget);
    expect(repository.saveCount, savesBeforeTicks);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      1.0,
    );
  });

  testWidgets('controller and audio identities survive rebuild and rotation', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);
    const shellKey = ValueKey('stable-mining-shell');

    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audioManager,
      shellKey: shellKey,
    );
    final before = shellHandles(tester);

    final portraitSize = tester.view.physicalSize;
    try {
      tester.view.physicalSize = const Size(640, 360);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(),
            child: MiningShell(
              key: shellKey,
              content: MiningContentRegistry.stellarMining(),
              repository: repository,
              nowUtc: clock.call,
              audioManager: audioManager,
            ),
          ),
        ),
      );
      await tester.pump();

      final after = shellHandles(tester);
      expect(after.controller, same(before.controller));
      expect(after.audioManager, same(before.audioManager));
    } finally {
      tester.view.physicalSize = portraitSize;
      await tester.pump();
    }
  });

  testWidgets('first gesture starts BGM through the injected manager', (
    tester,
  ) async {
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(backgroundMusicPlayer: player);
    await pumpShell(tester, audioManager: audioManager);

    await tester.tap(find.byKey(const Key('site-deck-scroll')));
    await tester.pump();

    expect(player.playedAssets, <String>['audio/background.mp3']);
  });

  testWidgets('audio gestures wait for preferences to finish loading', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'audio.musicEnabled': false});
    final player = FakeBackgroundMusicPlayer();
    final audioManager = DelayedAudioPrefsManager(
      backgroundMusicPlayer: player,
    );

    await pumpShell(tester, audioManager: audioManager, pumpCycles: 1);
    await audioManager.loadStarted.future;
    await tester.tap(find.byKey(const Key('mining-shell-loading')));
    await tester.pump();
    expect(player.playedAssets, isEmpty);

    audioManager.allowLoad.complete();
    await tester.pump();
    await tester.pump();
    expect(audioManager.musicEnabled, isFalse);
  });

  testWidgets('pre-initialization renders no enabled mining actions', (
    tester,
  ) async {
    final audioManager = DelayedAudioPrefsManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
    );

    await pumpShell(tester, audioManager: audioManager, pumpCycles: 1);
    await audioManager.loadStarted.future;

    expect(find.byKey(const Key('mining-shell-loading')), findsOneWidget);
    expect(find.byKey(const Key('site-deck-scroll')), findsNothing);
    expect(find.byKey(const Key('fleet-dock-spawn')), findsNothing);
    expect(find.byKey(const Key('mining-bottom-navigation')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    audioManager.allowLoad.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(shellHandles(tester).controller.state.cash, 100);
  });

  testWidgets('settings keeps the injected AudioManager preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio.musicEnabled': false,
      'audio.musicVolume': 0.75,
    });
    final audioManager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
    );
    await pumpShell(tester, audioManager: audioManager);

    shellHandles(tester).openSettings();
    await tester.pump(const Duration(milliseconds: 300));

    final sheet = find.byKey(const Key('mining-settings-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.descendant(of: sheet, matching: find.byType(SwitchListTile)),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<Slider>(
            find.descendant(of: sheet, matching: find.byType(Slider)),
          )
          .value,
      0.75,
    );
  });

  testWidgets('reduced motion follows MediaQuery at the shell owner', (
    tester,
  ) async {
    await pumpShell(tester, disableAnimations: true);

    expect(shellHandles(tester).reducedMotion, isTrue);
  });

  testWidgets(
    'pause stops the timer, checkpoints, and resume shows Offline Return',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingBasin(_start));
      await pumpShell(tester, repository: repository, clock: clock);

      clock.now = _start.add(const Duration(seconds: 4));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.saveCount, 2);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        2.0,
      );

      clock.now = _start.add(const Duration(seconds: 14));
      await tester.pump(const Duration(seconds: 2));
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        2.0,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.textContaining('Gold'), findsWidgets);
    },
  );
}
