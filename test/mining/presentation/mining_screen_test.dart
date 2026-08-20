import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_screen.dart';
import 'package:horologium/mining/world/mining_components.dart';
import 'package:horologium/mining/world/mining_game.dart';
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

class FailingMiningSaveRepository extends MiningSaveRepository {
  @override
  Future<void> save(MiningSave state) async {
    throw StateError('Mining save was rejected by SharedPreferences.');
  }
}

const _viewports = [Size(360, 640), Size(430, 932)];
final _now = DateTime.utc(2026, 8, 18, 12);

Future<void> pumpMiningScreen(
  WidgetTester tester,
  Size viewport, {
  MiningSaveRepository? repository,
  DateTime Function()? nowUtc,
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
          content: MiningContentRegistry.phaseOne(),
          repository: repository,
          nowUtc: nowUtc ?? () => _now,
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
            content: MiningContentRegistry.phaseOne(),
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

  testWidgets('disables the primary action while a mutation is saving', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
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
      content: MiningContentRegistry.phaseOne(),
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
      content: MiningContentRegistry.phaseOne(),
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
      content: MiningContentRegistry.phaseOne(),
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
        content: MiningContentRegistry.phaseOne(),
      );
      await repository.save(
        MiningSave(
          cash: 1000,
          lastAccruedAtUtc: _now,
          sectors: {
            MiningSectorId.landingBasin: const SectorProgress(
              revealed: true,
              mine: MineState(level: 1, storedAmount: 10),
            ),
            MiningSectorId.carbonRidge: const SectorProgress(revealed: false),
            MiningSectorId.graniteCrater: const SectorProgress(revealed: false),
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
    'pause checkpoint swallows storage failure as a best-effort save',
    (tester) async {
      final repository = FailingMiningSaveRepository();
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
}
