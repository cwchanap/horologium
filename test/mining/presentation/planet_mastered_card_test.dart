import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/planet_mastered_card.dart';

import '../../support/test_fonts.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 27, 12);

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

/// The real projected successor gates after mastering Lunar Frontier:
/// `StellarMapView` supplies `Lunar Frontier sites 3/3`, `Surveying 5`, and
/// `16.00M cash` for the Mars card. No invented short labels.
PlanetMasteredCard _projectedLaterCard({
  VoidCallback? onContinue,
  VoidCallback? onOpenMap,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final sites = <MiningSiteId, SiteProgress>{...initial.sites};
  for (final planet in const [
    MiningPlanetId.homeworld,
    MiningPlanetId.lunarFrontier,
  ]) {
    for (final site in _content.planet(planet).sites) {
      sites[site.id] = SiteProgress(
        unlocked: true,
        commissioned: true,
        storedAmount: 0,
        rigPlacements: const [],
      );
    }
  }
  final view = StellarMapView.from(
    state: initial.copyWith(
      technology: const TechnologyLevels(surveying: 3),
      unlockedPlanetIds: const {
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
      },
      sites: sites,
    ),
    content: _content,
  );
  final successor = view.planet(MiningPlanetId.marsFrontier);
  return PlanetMasteredCard(
    masteredPlanet: _content.planet(MiningPlanetId.lunarFrontier),
    successorName: successor.name,
    requirements: successor.requirements,
    nextSaleMultiplier: view.nextSaleMultiplier,
    onContinue: onContinue ?? () {},
    onOpenMap: onOpenMap ?? () {},
  );
}

bool _inside(Rect outer, Rect inner) =>
    outer.contains(inner.topLeft) &&
    outer.contains(inner.bottomRight - const Offset(1, 1));

Future<void> _pumpCard(
  WidgetTester tester, {
  required Size size,
  required PlanetMasteredCard card,
  double textScale = 1.3,
  EdgeInsets? insets,
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
        padding: insets ?? _insetsFor(size),
        textScaler: TextScaler.linear(textScale),
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

/// A text/art rectangle must sit entirely inside the scrolling body viewport
/// (the only clipped region) and above the pinned action footer.
void _expectVisibleInBody(WidgetTester tester, Finder finder) {
  final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
  final footer = tester.getRect(
    find.byKey(const Key('mining-sheet-pinned-footer')),
  );
  final rect = tester.getRect(finder);
  expect(body.contains(rect.topLeft), isTrue, reason: '$finder $rect vs $body');
  expect(
    body.contains(rect.bottomRight - const Offset(1, 1)),
    isTrue,
    reason: '$finder $rect vs $body',
  );
  expect(rect.bottom, lessThanOrEqualTo(footer.top), reason: '$finder $rect');
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

/// Normal widths keep the centered, art-led composition. The short landscape
/// and narrow large-text cards compact the art beside the milestone details.
void _expectArtLayout(WidgetTester tester, Size size) {
  final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
  final art = tester.getRect(find.byKey(const Key('planet-mastery-art')));
  if (size == const Size(874, 402)) {
    expect(art.left, lessThan(body.center.dx));
    expect(art.height, greaterThanOrEqualTo(96));
  } else if (size == const Size(360, 640)) {
    expect(art.left, lessThan(body.center.dx));
    expect(art.height, greaterThanOrEqualTo(72));
  } else {
    expect((art.center.dx - body.center.dx).abs(), lessThanOrEqualTo(8));
    expect(art.width, greaterThanOrEqualTo(120));
    expect(art.height, greaterThanOrEqualTo(120));
  }
}

void main() {
  setUpAll(loadProductionTestFonts);
  tearDownAll(restoreProductionFontsInWebTests);

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

      _expectArtLayout(tester, size);

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

      _expectArtLayout(tester, size);

      final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      _expectStackedActions(
        tester,
        primary: relaunch,
        secondary: continueButton,
        size: size,
      );
      // Both pinned actions stay tappable without scrolling the body.
      expect(relaunch.hitTestable(), findsOneWidget);
      expect(continueButton.hitTestable(), findsOneWidget);

      // The heading wraps at this size and text scale; its box must grow with
      // the wrapped lines instead of clipping the second one.
      final heading = tester.renderObject<RenderParagraph>(
        find.text('FINAL PLANET MASTERED'),
      );
      expect(
        heading.size.height,
        greaterThanOrEqualTo(heading.getMaxIntrinsicHeight(heading.size.width)),
        reason: 'the milestone heading must render both wrapped lines',
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

  for (final size in const [Size(874, 402), Size(360, 640)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets(
      'opens with the final name and reward above the actions at $label',
      (tester) async {
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

        _expectVisibleInBody(
          tester,
          find.byKey(const Key('planet-mastery-planet')),
        );
        _expectVisibleInBody(
          tester,
          find.byKey(const Key('planet-mastery-reward')),
        );
        _expectVisibleInBody(tester, find.text('completion reward'));

        final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
        final continueButton = find.byKey(const Key('planet-mastery-continue'));
        expect(relaunch.hitTestable(), findsOneWidget);
        expect(continueButton.hitTestable(), findsOneWidget);
        await tester.tap(relaunch);
        await tester.tap(continueButton);
        expect(relaunches, 1);
        expect(continues, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'opens with the planet, successor, and all gates above the actions '
      'at $label',
      (tester) async {
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

        _expectVisibleInBody(
          tester,
          find.byKey(const Key('planet-mastery-planet')),
        );
        _expectVisibleInBody(tester, find.text('All 3 sites commissioned'));
        _expectVisibleInBody(
          tester,
          find.byKey(const Key('planet-mastery-successor')),
        );
        for (var index = 0; index < 3; index++) {
          final gate = find.byKey(Key('planet-mastery-requirement-$index'));
          expect(gate, findsOneWidget);
          _expectVisibleInBody(tester, gate);
          final text = find.descendant(of: gate, matching: find.byType(Text));
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(
            paragraph.text.style?.fontFamily,
            'IBM Plex Mono',
            reason: 'the gate must render in the production body font',
          );
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicWidth(double.infinity) - .5,
            ),
            reason: 'gate $index must not wrap or clip',
          );
        }

        final openMap = find.byKey(const Key('planet-mastery-open-map'));
        final continueButton = find.byKey(const Key('planet-mastery-continue'));
        expect(openMap.hitTestable(), findsOneWidget);
        expect(continueButton.hitTestable(), findsOneWidget);
        await tester.tap(openMap);
        await tester.tap(continueButton);
        expect(opens, 1);
        expect(continues, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final textScale in const [1.0, 1.3]) {
    for (final withInsets in const [false, true]) {
      testWidgets(
        'short 360x640 shows the full home card at text scale $textScale '
        '${withInsets ? 'with' : 'without'} safe insets',
        (tester) async {
          var continues = 0;
          var opens = 0;
          const size = Size(360, 640);
          await _pumpCard(
            tester,
            size: size,
            textScale: textScale,
            insets: withInsets ? _insetsFor(size) : EdgeInsets.zero,
            card: _nonfinalCard(
              onContinue: () => continues++,
              onOpenMap: () => opens++,
            ),
          );

          _expectVisibleInBody(
            tester,
            find.byKey(const Key('planet-mastery-planet')),
          );
          if (textScale == 1.0) {
            final body = tester.getRect(
              find.byKey(const Key('mining-sheet-body')),
            );
            final art = tester.getRect(
              find.byKey(const Key('planet-mastery-art')),
            );
            expect(
              art.height,
              greaterThanOrEqualTo(96),
              reason: 'the compact 1.0 card keeps a substantial planet',
            );
            expect(art.left, lessThan(body.center.dx));
          }
          _expectVisibleInBody(tester, find.text('All 3 sites commissioned'));
          _expectVisibleInBody(
            tester,
            find.byKey(const Key('planet-mastery-successor')),
          );
          for (var index = 0; index < 3; index++) {
            final gate = find.byKey(Key('planet-mastery-requirement-$index'));
            expect(gate, findsOneWidget);
            _expectVisibleInBody(tester, gate);

            final rowRect = tester.getRect(gate);
            final text = find.descendant(of: gate, matching: find.byType(Text));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final textWidget = tester.widget<Text>(text);
            final textRect = tester.getRect(text);
            expect(
              rowRect.contains(textRect.topLeft),
              isTrue,
              reason: 'gate $index text starts outside its row',
            );
            expect(
              rowRect.contains(textRect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: 'gate $index text escapes its row',
            );
            _expectVisibleInBody(tester, text);
            expect(textWidget.maxLines, isNull);
            expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(
                paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
              ),
              reason: 'gate $index loses wrapped lines',
            );
          }

          final openMap = find.byKey(const Key('planet-mastery-open-map'));
          final continueButton = find.byKey(
            const Key('planet-mastery-continue'),
          );
          expect(openMap.hitTestable(), findsOneWidget);
          expect(continueButton.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(openMap).top,
            lessThan(tester.getRect(continueButton).top),
          );
          await tester.tap(openMap);
          await tester.tap(continueButton);
          expect(opens, 1);
          expect(continues, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
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

  for (final size in const [Size(360, 640), Size(874, 402)]) {
    testWidgets('real projected later-planet gates stay complete at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      var continues = 0;
      var opens = 0;
      final card = _projectedLaterCard(
        onContinue: () => continues++,
        onOpenMap: () => opens++,
      );
      await _pumpCard(tester, size: size, card: card);

      expect(
        card.requirements.map((requirement) => requirement.label),
        contains('Lunar Frontier sites 3/3'),
      );
      final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
      final openMap = find.byKey(const Key('planet-mastery-open-map'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      expect(openMap.hitTestable(), findsOneWidget);
      expect(continueButton.hitTestable(), findsOneWidget);

      for (var index = 0; index < card.requirements.length; index++) {
        final gate = find.byKey(Key('planet-mastery-requirement-$index'));
        expect(gate, findsOneWidget);
        final rowRect = tester.getRect(gate);
        expect(
          rowRect.left,
          greaterThanOrEqualTo(body.left - .5),
          reason: 'gate $index starts outside the body',
        );
        expect(
          rowRect.right,
          lessThanOrEqualTo(body.right + .5),
          reason: 'gate $index overflows the body horizontally',
        );

        final text = find.descendant(of: gate, matching: find.byType(Text));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final textWidget = tester.widget<Text>(text);
        final textRect = tester.getRect(text);
        expect(textRect.left, greaterThanOrEqualTo(rowRect.left - .5));
        expect(textRect.right, lessThanOrEqualTo(rowRect.right + .5));
        expect(textWidget.maxLines, isNull);
        expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
          ),
          reason: 'gate $index loses wrapped lines',
        );

        if (!_inside(body, rowRect)) {
          await tester.ensureVisible(gate);
          await tester.pump();
          _expectVisibleInBody(tester, gate);
          expect(openMap.hitTestable(), findsOneWidget);
          expect(continueButton.hitTestable(), findsOneWidget);
        }
      }

      await tester.tap(openMap);
      await tester.tap(continueButton);
      expect(opens, 1);
      expect(continues, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
