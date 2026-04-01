import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/main_game.dart';
import 'package:horologium/game/terrain/parallax_terrain_component.dart';
import 'package:horologium/game/terrain/terrain_generator.dart';
import 'package:horologium/widgets/game/terrain_debug_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TerrainDebugSheet.show', () {
    testWidgets(
      'returns without opening the sheet when the game is not loaded',
      (tester) async {
        final game = FakeMainGame(
          hasLoadedOverride: false,
          gridOverride: Grid(),
          terrainOverride: FakeTerrainComponent(),
        );

        await tester.pumpWidget(_TerrainDebugSheetHarness(game: game));

        await tester.tap(find.text('Open Terrain Debug'));
        await tester.pumpAndSettle();

        expect(find.text('Developer Tools'), findsNothing);
      },
    );

    testWidgets('uses default values when terrain data is unavailable', (
      tester,
    ) async {
      final game = FakeMainGame(
        hasLoadedOverride: true,
        gridOverride: Grid(),
        terrainOverride: null,
      );

      await tester.pumpWidget(_TerrainDebugSheetHarness(game: game));

      await tester.tap(find.text('Open Terrain Debug'));
      await tester.pumpAndSettle();

      expect(find.text('Developer Tools'), findsOneWidget);
      expect(find.text('Patch Size'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Patch Jitter'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Primary Weight'), findsOneWidget);
      expect(find.text('0.85'), findsOneWidget);
    });

    testWidgets('toggle controls update terrain/grid flags and persist prefs', (
      tester,
    ) async {
      final terrain = FakeTerrainComponent();
      final grid = Grid();
      final game = FakeMainGame(
        hasLoadedOverride: true,
        gridOverride: grid,
        terrainOverride: terrain,
      );

      await tester.pumpWidget(_TerrainDebugSheetHarness(game: game));
      await tester.tap(find.text('Open Terrain Debug'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terrain debug overlays'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show patch centers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show edge zones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grid debug overlays'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();

      expect(terrain.showDebug, isTrue);
      expect(terrain.showPatchCentersDebug, isTrue);
      expect(terrain.showEdgeZonesDebug, isTrue);
      expect(grid.showDebug, isTrue);
      expect(prefs.getBool('terrain.debug'), isTrue);
      expect(prefs.getBool('terrain.showCenters'), isTrue);
      expect(prefs.getBool('terrain.showEdges'), isTrue);
      expect(prefs.getBool('grid.debug'), isTrue);
    });

    testWidgets(
      'apply params and shuffle seed delegate to the terrain component',
      (tester) async {
        final terrain = FakeTerrainComponent();
        final game = FakeMainGame(
          hasLoadedOverride: true,
          gridOverride: Grid(),
          terrainOverride: terrain,
        );

        await tester.pumpWidget(_TerrainDebugSheetHarness(game: game));
        await tester.tap(find.text('Open Terrain Debug'));
        await tester.pumpAndSettle();

        final ruggedButton = find.text('Rugged');
        final applyParamsButton = find.text('Apply Params');
        final shuffleSeedButton = find.text('Shuffle Seed');
        final scrollable = find.byType(Scrollable).last;

        await tester.tap(ruggedButton);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          applyParamsButton,
          200,
          scrollable: scrollable,
        );
        await tester.tap(applyParamsButton);
        await tester.pumpAndSettle();

        expect(terrain.updateCalls, hasLength(1));
        expect(terrain.updateCalls.single, <String, Object?>{
          'patchSizeBase': 8,
          'patchJitter': 2,
          'primaryWeight': 0.8,
          'warpAmplitude': 2.0,
          'warpFrequency': 0.22,
          'edgeWidth': 1.4,
          'edgeGamma': 1.8,
        });

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('terrain.patchSizeBase'), 8);
        expect(prefs.getInt('terrain.patchJitter'), 2);
        expect(prefs.getDouble('terrain.primaryWeight'), 0.8);
        expect(prefs.getDouble('terrain.warpAmplitude'), 2.0);
        expect(prefs.getDouble('terrain.warpFrequency'), 0.22);
        expect(prefs.getDouble('terrain.edgeWidth'), 1.4);
        expect(prefs.getDouble('terrain.edgeGamma'), 1.8);

        await tester.scrollUntilVisible(
          shuffleSeedButton,
          200,
          scrollable: scrollable,
        );
        await tester.tap(shuffleSeedButton);
        await tester.pumpAndSettle();

        expect(terrain.shuffleSeedCalls, 1);
      },
    );
  });
}

class _TerrainDebugSheetHarness extends StatelessWidget {
  const _TerrainDebugSheetHarness({required this.game});

  final MainGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(TerrainDebugSheet.show(context, game));
              },
              child: const Text('Open Terrain Debug'),
            );
          },
        ),
      ),
    );
  }
}

class FakeMainGame extends MainGame {
  FakeMainGame({
    required bool hasLoadedOverride,
    required Grid gridOverride,
    required ParallaxTerrainComponent? terrainOverride,
  }) : _hasLoadedOverride = hasLoadedOverride,
       _gridOverride = gridOverride,
       _terrainOverride = terrainOverride;

  final bool _hasLoadedOverride;
  final Grid _gridOverride;
  final ParallaxTerrainComponent? _terrainOverride;

  @override
  Grid get grid => _gridOverride;

  @override
  ParallaxTerrainComponent? get terrain => _terrainOverride;

  @override
  bool get hasLoaded => _hasLoadedOverride;
}

class FakeTerrainComponent extends ParallaxTerrainComponent {
  FakeTerrainComponent() : super(gridSize: 50) {
    generator = TerrainGenerator(gridSize: 50);
  }

  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];
  int shuffleSeedCalls = 0;

  @override
  void setDebugOverlays(bool enabled) {
    showDebug = enabled;
  }

  @override
  void setPatchDebugOverlays({bool? showCenters, bool? showEdges}) {
    if (showCenters != null) {
      showPatchCentersDebug = showCenters;
    }
    if (showEdges != null) {
      showEdgeZonesDebug = showEdges;
    }
  }

  @override
  Future<void> shuffleSeed() async {
    shuffleSeedCalls++;
  }

  @override
  Future<void> updateTerrainParams({
    int? patchSizeBase,
    int? patchJitter,
    double? primaryWeight,
    double? warpAmplitude,
    double? warpFrequency,
    double? edgeWidth,
    double? edgeGamma,
  }) async {
    updateCalls.add(<String, Object?>{
      'patchSizeBase': patchSizeBase,
      'patchJitter': patchJitter,
      'primaryWeight': primaryWeight,
      'warpAmplitude': warpAmplitude,
      'warpFrequency': warpFrequency,
      'edgeWidth': edgeWidth,
      'edgeGamma': edgeGamma,
    });
  }
}
