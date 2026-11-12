import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/planet_mastered_card.dart';

final _content = MiningContentRegistry.stellarMining();

/// The mockup review sizes: three portrait phones and one short landscape.
const _sizes = [Size(360, 640), Size(390, 844), Size(430, 932), Size(874, 402)];

EdgeInsets _insetsFor(Size size) => size.width > size.height
    ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
    : const EdgeInsets.fromLTRB(0, 24, 0, 24);

PlanetMasteredCard _nonfinalCard({
  VoidCallback? onContinue,
  VoidCallback? onOpenMap,
  double nextSaleMultiplier = 1.5,
}) => PlanetMasteredCard(
  masteredPlanet: _content.planet(MiningPlanetId.homeworld),
  successorName: 'Lunar Frontier',
  requirements: const [
    StellarMapRequirementView(label: 'Homeworld mastered', isSatisfied: true),
    StellarMapRequirementView(label: 'Surveying 3', isSatisfied: false),
    StellarMapRequirementView(label: '200,000 cash', isSatisfied: false),
  ],
  nextSaleMultiplier: nextSaleMultiplier,
  onContinue: onContinue ?? () {},
  onOpenMap: onOpenMap ?? () {},
);

PlanetMasteredCard _finalCard({
  VoidCallback? onContinue,
  VoidCallback? onRelaunch,
  double nextSaleMultiplier = 1.5,
}) => PlanetMasteredCard(
  masteredPlanet: _content.planet(_content.finalPlanetId),
  successorName: null,
  requirements: const [],
  isFinal: true,
  rewardCash: _content.planet(_content.finalPlanetId).masteryRewardCash,
  nextSaleMultiplier: nextSaleMultiplier,
  onContinue: onContinue ?? () {},
  onOpenMap: () {},
  onRelaunch: onRelaunch ?? () {},
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required Size size,
  required PlanetMasteredCard card,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: _insetsFor(size),
        textScaler: const TextScaler.linear(1.3),
        disableAnimations: true,
      ),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        home: Scaffold(body: card),
      ),
    ),
  );
  await tester.pump();
}

/// The mockup's action stack: a filled cyan primary above the outlined
/// secondary, both already inside the safe area without scrolling.
void _expectStackedActions(
  WidgetTester tester, {
  required Finder primary,
  required Finder secondary,
  required Size size,
}) {
  final primaryButton = find.descendant(
    of: primary,
    matching: find.byType(ElevatedButton),
  );
  expect(primaryButton, findsOneWidget);
  expect(
    find.descendant(of: secondary, matching: find.byType(OutlinedButton)),
    findsOneWidget,
  );
  expect(
    tester
        .widget<ElevatedButton>(primaryButton)
        .style!
        .backgroundColor!
        .resolve(const <WidgetState>{}),
    MiningTheme.highlight,
  );
  expect(tester.getRect(primary).top, lessThan(tester.getRect(secondary).top));

  final insets = _insetsFor(size);
  final safe = Rect.fromLTRB(
    insets.left,
    insets.top,
    size.width - insets.right,
    size.height - insets.bottom,
  );
  for (final finder in [primary, secondary]) {
    final rect = tester.getRect(finder);
    expect(safe.contains(rect.topLeft), isTrue, reason: '$finder $rect');
    expect(
      safe.contains(rect.bottomRight - const Offset(1, 1)),
      isTrue,
      reason: '$finder $rect',
    );
  }
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

  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('nonfinal card keeps both actions tappable at $label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var continues = 0;
      var opens = 0;
      await _pumpCard(
        tester,
        size: size,
        card: _nonfinalCard(
          onContinue: () => continues++,
          onOpenMap: () => opens++,
        ),
      );

      final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
      final art = tester.getRect(find.byKey(const Key('planet-mastery-art')));
      expect((art.center.dx - body.center.dx).abs(), lessThanOrEqualTo(8));
      expect(art.width, greaterThanOrEqualTo(120));
      expect(art.height, greaterThanOrEqualTo(120));

      final openMap = find.byKey(const Key('planet-mastery-open-map'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      _expectStackedActions(
        tester,
        primary: openMap,
        secondary: continueButton,
        size: size,
      );

      expect(find.text('All 3 sites commissioned'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-successor')))
            .data,
        'Lunar Frontier is next',
      );
      expect(find.text('Homeworld mastered'), findsOneWidget);
      expect(find.text('Surveying 3'), findsOneWidget);
      expect(find.text('200,000 cash'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('planet-mastery-requirement-0')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      for (final index in const [1, 2]) {
        expect(
          find.descendant(
            of: find.byKey(Key('planet-mastery-requirement-$index')),
            matching: find.byIcon(Icons.close),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(openMap);
      await tester.tap(continueButton);
      expect(opens, 1);
      expect(continues, 1);

      // Only the body scrolls; the actions above were tapped before this.
      await tester.ensureVisible(
        find.byKey(const Key('planet-mastery-requirement-1')),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('^Surveying 3, required')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.text('PLANET MASTERED'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('final card keeps both actions tappable at $label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var continues = 0;
      var relaunches = 0;
      await _pumpCard(
        tester,
        size: size,
        card: _finalCard(
          onContinue: () => continues++,
          onRelaunch: () => relaunches++,
        ),
      );

      final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
      final art = tester.getRect(find.byKey(const Key('planet-mastery-art')));
      expect((art.center.dx - body.center.dx).abs(), lessThanOrEqualTo(8));
      expect(art.width, greaterThanOrEqualTo(120));
      expect(art.height, greaterThanOrEqualTo(120));

      final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      _expectStackedActions(
        tester,
        primary: relaunch,
        secondary: continueButton,
        size: size,
      );

      final reward = _content.planet(_content.finalPlanetId).masteryRewardCash;
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-reward')))
            .data,
        '+${formatMiningCash(reward)} cash',
      );
      expect(find.text('completion reward'), findsOneWidget);
      expect(find.text('RUN COMPLETE'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('FINAL PLANET MASTERED'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );

      await tester.tap(relaunch);
      await tester.tap(continueButton);
      expect(relaunches, 1);
      expect(continues, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final (multiplier, formatted) in const [(1.5, '×1.5'), (2.0, '×2')]) {
    testWidgets('final card projects next sales as $formatted', (tester) async {
      await _pumpCard(
        tester,
        size: const Size(360, 640),
        card: _finalCard(nextSaleMultiplier: multiplier),
      );

      final text = tester.widget<Text>(
        find.byKey(const Key('planet-mastery-multiplier')),
      );
      expect(text.data, contains(formatted));
      expect(tester.takeException(), isNull);
    });
  }
}
