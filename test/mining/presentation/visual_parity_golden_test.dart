import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/site_deck_screen.dart';
import 'package:horologium/mining/presentation/stellar_map_screen.dart';
import 'package:horologium/mining/site_deck_view.dart';

final _content = MiningContentRegistry.stellarMining();
final _now = DateTime.utc(2026, 8, 29, 12);

MiningSave _operationalState() {
  final initial = MiningSave.initial(nowUtc: _now);
  return initial.copyWith(
    cash: 2_000,
    sites: {
      ...initial.sites,
      MiningSiteId.landingBasin: SiteProgress(
        unlocked: true,
        commissioned: true,
        storedAmount: 20,
        rigByNode: {
          MiningNodeId.n1: RigTier.t2,
          MiningNodeId.n2: null,
          MiningNodeId.n3: null,
          MiningNodeId.n4: null,
        },
      ),
    },
  );
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
      home: child,
    ),
  );
  final context = tester.element(find.byType(MaterialApp));
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    final fontFile = File('assets/fonts/Orbitron-Variable.ttf');
    if (fontFile.existsSync()) {
      final loader = FontLoader('Orbitron');
      loader.addFont(fontFile.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('Site Deck portrait visual contract', (tester) async {
    final state = _operationalState();
    await _pumpSurface(
      tester,
      size: const Size(430, 932),
      child: SiteDeckScreen(
        cash: state.cash,
        view: SiteDeckView.from(state: state, content: _content, isBusy: false),
        fleetDock: FleetDockView.from(
          state: state,
          content: _content,
          selectedBayId: null,
          isBusy: false,
        ),
        onEnterSite: (_) {},
        onUnlockSite: (_) {},
        onBayTap: (_) {},
        onSpawnRig: () {},
        onDestinationSelected: (_) {},
      ),
    );

    await expectLater(
      find.byType(SiteDeckScreen),
      matchesGoldenFile('goldens/site_deck_430x932.png'),
    );
  }, skip: kIsWeb || Platform.isMacOS);

  for (final size in [const Size(430, 932), const Size(874, 402)]) {
    testWidgets(
      'Mine Site ${size.width.toInt()}x${size.height.toInt()} visual contract',
      (tester) async {
        final state = _operationalState();
        await _pumpSurface(
          tester,
          size: size,
          child: MineSiteScreen(
            view: MineSiteView.from(
              state: state,
              content: _content,
              siteId: MiningSiteId.landingBasin,
              selectedBayId: null,
              isBusy: false,
            ),
            fleetDock: FleetDockView.from(
              state: state,
              content: _content,
              selectedBayId: null,
              isBusy: false,
            ),
            cash: state.cash,
            reducedMotion: true,
            onNodeTap: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
            onDestinationSelected: (_) {},
          ),
        );

        await expectLater(
          find.byType(MineSiteScreen),
          matchesGoldenFile(
            'goldens/mine_site_${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
      },
      skip: kIsWeb || Platform.isMacOS,
    );
  }

  testWidgets('Stellar Map portrait visual contract', (tester) async {
    final state = MiningSave.initial(nowUtc: _now);
    await _pumpSurface(
      tester,
      size: const Size(430, 932),
      child: StellarMapScreen(
        view: StellarMapView.from(state: state, content: _content),
        content: _content,
        onUnlock: (_) {},
        onTravel: (_) {},
      ),
    );

    await expectLater(
      find.byType(StellarMapScreen),
      matchesGoldenFile('goldens/stellar_map_430x932.png'),
    );
  }, skip: kIsWeb || Platform.isMacOS);
}
