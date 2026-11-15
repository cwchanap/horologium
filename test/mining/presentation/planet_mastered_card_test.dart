import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const _actionRadius = 12.0;

EdgeInsets _insetsFor(Size size) => size.width > size.height
    ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
    : const EdgeInsets.fromLTRB(0, 24, 0, 24);

Rect _safeRect(Size size, EdgeInsets insets) => Rect.fromLTRB(
  insets.left,
  insets.top,
  size.width - insets.right,
  size.height - insets.bottom,
);

PlanetMasteredCard _nonfinalCard({
  VoidCallback? onContinue,
  VoidCallback? onOpenMap,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final sites = <MiningSiteId, SiteProgress>{...initial.sites};
  for (final site in _content.planet(MiningPlanetId.homeworld).sites) {
    sites[site.id] = SiteProgress(
      unlocked: true,
      commissioned: true,
      storedAmount: 0,
      rigPlacements: const [],
    );
  }
  final view = StellarMapView.from(
    state: initial.copyWith(sites: sites),
    content: _content,
  );
  final successor = view.planet(MiningPlanetId.lunarFrontier);
  return PlanetMasteredCard(
    masteredPlanet: _content.planet(MiningPlanetId.homeworld),
    successorName: successor.name,
    requirements: successor.requirements,
    nextSaleMultiplier: view.nextSaleMultiplier,
    onContinue: onContinue ?? () {},
    onOpenMap: onOpenMap ?? () {},
  );
}

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

/// The longest authored successor gates: mastering Ceres projects Io's
/// `Ceres Frontier sites 3/3`, `Surveying 5`, and `90.00M cash` rows.
PlanetMasteredCard _projectedCeresCard({
  VoidCallback? onContinue,
  VoidCallback? onOpenMap,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final sites = <MiningSiteId, SiteProgress>{...initial.sites};
  for (final planet in const [
    MiningPlanetId.homeworld,
    MiningPlanetId.lunarFrontier,
    MiningPlanetId.marsFrontier,
    MiningPlanetId.ceresFrontier,
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
      cash: 12350000,
      technology: const TechnologyLevels(surveying: 4),
      unlockedPlanetIds: const {
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
        MiningPlanetId.marsFrontier,
        MiningPlanetId.ceresFrontier,
      },
      activePlanetId: MiningPlanetId.ceresFrontier,
      sites: sites,
    ),
    content: _content,
  );
  final successor = view.planet(MiningPlanetId.ioFrontier);
  return PlanetMasteredCard(
    masteredPlanet: _content.planet(MiningPlanetId.ceresFrontier),
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

/// Labels in accessibility traversal order: the order assistive technologies
/// follow, which differs from paint order when `OrdinalSortKey`s reorder a
/// packed summary.
List<String> _traversalLabels(WidgetTester tester) => [
  for (final node in tester.semantics.simulatedAccessibilityTraversal())
    if (node.getSemanticsData().label.isNotEmpty) node.getSemanticsData().label,
];

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
        // The shell hosts this card in a full-screen dialog; the card positions
        // its own content-sized composition (centered roomy, bottom compact).
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

void _expectRoundedShape<T extends ButtonStyleButton>(
  WidgetTester tester,
  Finder finder,
) {
  final button = tester.widget<T>(finder);
  final shape = button.style!.shape!.resolve(const <WidgetState>{});
  expect(shape, isA<RoundedRectangleBorder>(), reason: '$finder');
  expect(
    (shape! as RoundedRectangleBorder).borderRadius,
    BorderRadius.circular(_actionRadius),
    reason: '$finder',
  );
}

/// The mockup's rounded-rectangle action hierarchy: one filled cyan primary
/// and one outlined secondary, both with the mockup copy and immediately
/// tappable inside the safe area.
void _expectActionHierarchy(
  WidgetTester tester, {
  required Finder primary,
  required Finder secondary,
  required Size size,
  required String primaryLabel,
  required String secondaryLabel,
  EdgeInsets? insets,
}) {
  final primaryButton = find.descendant(
    of: primary,
    matching: find.byType(ElevatedButton),
  );
  final secondaryButton = find.descendant(
    of: secondary,
    matching: find.byType(OutlinedButton),
  );
  expect(primaryButton, findsOneWidget);
  expect(secondaryButton, findsOneWidget);
  expect(
    find.descendant(of: primary, matching: find.text(primaryLabel)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: secondary, matching: find.text(secondaryLabel)),
    findsOneWidget,
  );
  _expectRoundedShape<ElevatedButton>(tester, primaryButton);
  _expectRoundedShape<OutlinedButton>(tester, secondaryButton);
  expect(
    tester
        .widget<ElevatedButton>(primaryButton)
        .style!
        .backgroundColor!
        .resolve(const <WidgetState>{}),
    masteryPrimaryFill,
  );

  final safe = _safeRect(size, insets ?? _insetsFor(size));
  final panel = tester.getRect(find.byKey(const Key('planet-mastery-panel')));
  for (final finder in [primary, secondary]) {
    final rect = tester.getRect(finder);
    expect(safe.contains(rect.topLeft), isTrue, reason: '$finder $rect');
    expect(
      safe.contains(rect.bottomRight - const Offset(1, 1)),
      isTrue,
      reason: '$finder $rect',
    );
    expect(_inside(panel, rect), isTrue, reason: '$finder $rect vs $panel');
    expect(finder.hitTestable(), findsOneWidget);
    expect(rect.height, greaterThanOrEqualTo(48));
  }
  // The mockup's primary action is taller than the secondary one.
  expect(
    tester.getRect(primary).height,
    greaterThanOrEqualTo(52),
    reason: 'the mockup primary action is a 52px tall fill',
  );

  final primaryRect = tester.getRect(primary);
  final secondaryRect = tester.getRect(secondary);
  // The approved mockup hierarchy stays a stack at every target size,
  // including short landscape: primary first, secondary directly below.
  expect(primaryRect.top, lessThan(secondaryRect.top));
  expect(primaryRect.left, closeTo(secondaryRect.left, .5));
  expect(primaryRect.right, closeTo(secondaryRect.right, .5));
}

/// The floating mockup composition: a centered rounded panel, planet art
/// straddling its top edge, and a close control straddling the same edge while
/// staying inside the live safe area.
void _expectFloatingComposition(
  WidgetTester tester,
  Size size, {
  required bool isFinal,
  EdgeInsets? insets,
}) {
  insets ??= _insetsFor(size);
  final safe = _safeRect(size, insets);
  final panel = tester.getRect(find.byKey(const Key('planet-mastery-panel')));
  final art = tester.getRect(find.byKey(const Key('planet-mastery-art')));
  final landscape = size.width > size.height;
  final roomy = !landscape && size.height > 700;

  expect((panel.center.dx - size.width / 2).abs(), lessThanOrEqualTo(1));
  expect(panel.left, greaterThanOrEqualTo(safe.left + 12));
  expect(panel.right, lessThanOrEqualTo(safe.right - 12 + .5));
  expect(panel.top, greaterThanOrEqualTo(safe.top));
  expect(panel.bottom, lessThanOrEqualTo(safe.bottom + .5));
  if (roomy) {
    // Roomy portrait floats the content-sized card vertically centered.
    expect(panel.top, greaterThan(safe.top));
    expect(panel.bottom, lessThan(safe.bottom));
  } else {
    expect(panel.bottom, greaterThan(safe.bottom - 24));
  }
  if (landscape) {
    expect(panel.width, lessThanOrEqualTo(560));
  } else {
    expect(panel.width, lessThanOrEqualTo(440));
  }

  expect(art.top, lessThan(panel.top), reason: 'the planet must overlap');
  expect(art.bottom, greaterThan(panel.top + 2));
  expect((art.center.dx - panel.center.dx).abs(), lessThanOrEqualTo(1));
  expect(
    art.height,
    greaterThanOrEqualTo(
      roomy
          ? 110
          : landscape
          ? 40
          : 96,
    ),
    reason: 'the 1.0 compact card keeps at least the previous 96px planet',
  );

  final card = tester.getRect(find.byKey(const Key('planet-mastery-card')));
  expect(card.top, greaterThan(safe.top));
  expect(card.top, lessThan(panel.top));
  expect(card.height, lessThan(size.height));

  final close = find.bySemanticsLabel(
    'Close ${isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED'}',
  );
  expect(close, findsOneWidget);
  expect(close.hitTestable(), findsOneWidget);
  final closeRect = tester.getRect(close);
  expect(closeRect.top, greaterThanOrEqualTo(safe.top));
  expect(closeRect.top, greaterThanOrEqualTo(card.top));
  expect(_inside(card, closeRect), isTrue, reason: '$closeRect vs $card');
  expect(closeRect.top, lessThan(panel.top));
  expect(closeRect.bottom, greaterThan(panel.top));
  expect(closeRect.right, lessThanOrEqualTo(safe.right));

  final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
  final footer = tester.getRect(
    find.byKey(const Key('mining-sheet-pinned-footer')),
  );
  expect(_inside(panel, body), isTrue, reason: '$body vs $panel');
  expect(_inside(panel, footer), isTrue, reason: '$footer vs $panel');
  expect(body.bottom, lessThanOrEqualTo(footer.top + .5));
}

void _expectOutlinedBadge(
  WidgetTester tester,
  Size size, {
  required bool isFinal,
}) {
  final title = isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED';
  final badge = find.byKey(const Key('planet-mastery-badge'));
  expect(badge, findsOneWidget);
  final container = tester.widget<Container>(badge);
  final decoration = container.decoration! as BoxDecoration;
  final border = decoration.border! as Border;
  expect(border.top.color, MiningTheme.accent);
  final radius = decoration.borderRadius! as BorderRadius;
  expect(radius.topLeft.x, greaterThanOrEqualTo(999));

  final panel = tester.getRect(find.byKey(const Key('planet-mastery-panel')));
  final badgeRect = tester.getRect(badge);
  final titleRect = tester.getRect(find.text(title));
  expect((badgeRect.center.dx - panel.center.dx).abs(), lessThanOrEqualTo(1));
  // The leading dot offsets the title inside the pill; both must stay inside it.
  expect(titleRect.left, greaterThan(badgeRect.left));
  expect(titleRect.right, lessThan(badgeRect.right));
  expect(badgeRect.width, lessThan(panel.width - 24));
  expect(
    tester
        .getSemantics(find.text(title))
        .getSemanticsData()
        .flagsCollection
        .isHeader,
    isTrue,
  );
}

void _expectGate(
  WidgetTester tester, {
  required int index,
  required String label,
  required bool satisfied,
  String? currentValue,
  double? fontSize,
  double? textScale,
}) {
  final gate = find.byKey(Key('planet-mastery-requirement-$index'));
  expect(gate, findsOneWidget, reason: 'gate $index');
  _expectVisibleInBody(tester, gate);
  if (satisfied) {
    final check = find.descendant(of: gate, matching: find.byIcon(Icons.check));
    expect(check, findsOneWidget, reason: 'gate $index');
    expect(tester.widget<Icon>(check).color, MiningTheme.accent);
    expect(
      find.descendant(of: gate, matching: find.byIcon(Icons.close)),
      findsNothing,
      reason: 'a satisfied gate never shows the unmet circle',
    );
  } else {
    // The approved mockup marks an unmet gate with a small hollow orange
    // circle instead of the previous orange cross.
    expect(
      find.descendant(of: gate, matching: find.byIcon(Icons.close)),
      findsNothing,
      reason: 'gate $index must use the mockup circle, not a cross',
    );
    final indicator = find.descendant(
      of: gate,
      matching: find.byKey(const Key('planet-mastery-gate-unmet')),
    );
    expect(indicator, findsOneWidget, reason: 'gate $index');
    final decoration =
        tester.widget<Container>(indicator).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle, reason: 'gate $index');
    expect(
      (decoration.border! as Border).top.color,
      MiningTheme.gate,
      reason: 'gate $index',
    );
    final indicatorRect = tester.getRect(indicator);
    expect(indicatorRect.width, lessThanOrEqualTo(12), reason: 'gate $index');
    expect(indicatorRect.height, lessThanOrEqualTo(12), reason: 'gate $index');
    expect(
      indicatorRect.width,
      closeTo(indicatorRect.height, .5),
      reason: 'gate $index',
    );
  }

  final labelText = find.descendant(of: gate, matching: find.text(label));
  expect(labelText, findsOneWidget, reason: 'gate $index: $label');
  _expectVisibleInBody(tester, labelText);
  final labelWidget = tester.widget<Text>(labelText);
  expect(labelWidget.style?.color, MiningTheme.primaryText);
  expect(labelWidget.maxLines, isNull);
  expect(labelWidget.overflow, isNot(TextOverflow.ellipsis));
  final rowRect = tester.getRect(gate);
  final labelRect = tester.getRect(labelText);
  expect(
    rowRect.contains(labelRect.topLeft),
    isTrue,
    reason: 'gate $index label starts outside its row',
  );
  expect(
    rowRect.contains(labelRect.bottomRight - const Offset(1, 1)),
    isTrue,
    reason: 'gate $index label escapes its row',
  );
  final paragraph = tester.renderObject<RenderParagraph>(labelText);
  expect(paragraph.text.style?.fontFamily, 'IBM Plex Mono');
  if (fontSize != null) {
    expect(
      labelWidget.style?.fontSize,
      fontSize,
      reason: 'gate $index "$label" body size',
    );
    expect(
      paragraph.textScaler.scale(fontSize),
      closeTo(fontSize * (textScale ?? 1), .01),
      reason: 'gate $index must honor the requested text scale',
    );
  }
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - .5),
    reason: 'gate $index "$label" must not wrap or clip',
  );
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(
      paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
    ),
    reason: 'gate $index "$label" loses wrapped lines',
  );

  if (currentValue != null) {
    final value = find.descendant(
      of: gate,
      matching: find.text('· $currentValue'),
    );
    expect(value, findsOneWidget, reason: 'gate $index current value');
    _expectVisibleInBody(tester, value);
    final valueWidget = tester.widget<Text>(value);
    expect(valueWidget.maxLines, isNull);
    expect(valueWidget.overflow, isNot(TextOverflow.ellipsis));
    if (fontSize != null) {
      expect(
        valueWidget.style?.fontSize,
        fontSize,
        reason: 'gate $index current value body size',
      );
    }
    final valueRect = tester.getRect(value);
    expect(
      rowRect.contains(valueRect.topLeft),
      isTrue,
      reason: 'gate $index current value starts outside its row',
    );
    expect(
      rowRect.contains(valueRect.bottomRight - const Offset(1, 1)),
      isTrue,
      reason: 'gate $index current value escapes its row',
    );
  }
}

/// The first action must sit near the last detail in roomy portrait, not at
/// the bottom of a stretched panel.
void _expectPrimaryNearLastDetail(
  WidgetTester tester, {
  required Finder primary,
  required Finder lastDetail,
}) {
  final primaryRect = tester.getRect(primary);
  final detailRect = tester.getRect(lastDetail);
  final gap = primaryRect.top - detailRect.bottom;
  expect(
    gap,
    greaterThanOrEqualTo(0),
    reason: 'primary $primaryRect overlaps last detail $detailRect',
  );
  expect(
    gap,
    lessThanOrEqualTo(32),
    reason:
        'primary $primaryRect must start within 32px of the last detail '
        '$detailRect, not after stretched blank space',
  );
}

/// The approved mockup follow-up grows the planet and the milestone type in
/// roomy portrait while every string still renders in full at the requested
/// text scale.
void _expectMockupScale(
  WidgetTester tester, {
  required double textScale,
  required bool isFinal,
}) {
  final panel = tester.getRect(find.byKey(const Key('planet-mastery-panel')));
  final art = tester.getRect(find.byKey(const Key('planet-mastery-art')));
  expect(
    art.height,
    greaterThanOrEqualTo(150),
    reason: 'the roomy mockup planet is larger than the compact 96px planet',
  );
  expect((art.center.dx - panel.center.dx).abs(), lessThanOrEqualTo(1));

  void expectEnlarged(Finder finder, double minimum) {
    final fontSize = tester.widget<Text>(finder).style!.fontSize!;
    expect(fontSize, greaterThanOrEqualTo(minimum), reason: '$finder');
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '$finder must render every line',
    );
    // `didExceedMaxLines` is blind to a height-clipped paragraph; compare the
    // rendered height against the intrinsic height at the rendered width.
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
      ),
      reason: '$finder loses rendered lines to a height clip',
    );
    expect(
      paragraph.textScaler.scale(fontSize),
      closeTo(fontSize * textScale, .01),
      reason: '$finder must honor the requested text scale',
    );
    _expectVisibleInBody(tester, finder);
  }

  expectEnlarged(
    find.text(isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED'),
    13,
  );
  expectEnlarged(find.byKey(const Key('planet-mastery-planet')), 30);
  if (isFinal) {
    expectEnlarged(find.byKey(const Key('planet-mastery-reward')), 30);
  }
}

void main() {
  setUpAll(loadProductionTestFonts);
  tearDownAll(restoreProductionFontsInWebTests);

  for (final size in _sizes) {
    for (final textScale in const [1.0, 1.3]) {
      final label =
          '${size.width.toInt()}x${size.height.toInt()} text $textScale';

      testWidgets('nonfinal card keeps both actions tappable at $label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        var continues = 0;
        var opens = 0;
        final card = _nonfinalCard(
          onContinue: () => continues++,
          onOpenMap: () => opens++,
        );
        await _pumpCard(tester, size: size, textScale: textScale, card: card);

        _expectFloatingComposition(tester, size, isFinal: false);
        _expectOutlinedBadge(tester, size, isFinal: false);

        final openMap = find.byKey(const Key('planet-mastery-open-map'));
        final continueButton = find.byKey(const Key('planet-mastery-continue'));
        _expectActionHierarchy(
          tester,
          primary: openMap,
          secondary: continueButton,
          size: size,
          primaryLabel: 'OPEN STELLAR MAP',
          secondaryLabel: 'CONTINUE',
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
        expect(
          tester
              .widget<Text>(find.byKey(const Key('planet-mastery-successor')))
              .data,
          'NEXT · LUNAR FRONTIER',
        );

        // The card's mastery wording is presentation-only: the shared Stellar
        // Map projection keeps its authored `Homeworld sites 3/3` label.
        expect(card.requirements.first.label, 'Homeworld sites 3/3');
        expect(find.text('Homeworld sites 3/3'), findsNothing);
        _expectGate(
          tester,
          index: 0,
          label: 'Homeworld mastered',
          satisfied: true,
        );
        _expectGate(
          tester,
          index: 1,
          label: 'Surveying 3',
          satisfied: false,
          currentValue: 'now LV 0',
        );
        _expectGate(
          tester,
          index: 2,
          label: '200,000 cash',
          satisfied: false,
          currentValue: '100',
        );

        // Only the body scrolls; the pinned actions above were tapped first.
        await tester.ensureVisible(
          find.byKey(const Key('planet-mastery-requirement-1')),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel(RegExp('^Surveying 3, required')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('^Homeworld mastered, satisfied')),
          findsOneWidget,
        );
        await tester.tap(openMap);
        await tester.tap(continueButton);
        expect(opens, 1);
        expect(continues, 1);
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
          textScale: textScale,
          card: _finalCard(
            onContinue: () => continues++,
            onRelaunch: () => relaunches++,
          ),
        );

        _expectFloatingComposition(tester, size, isFinal: true);
        _expectOutlinedBadge(tester, size, isFinal: true);

        final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
        final continueButton = find.byKey(const Key('planet-mastery-continue'));
        _expectActionHierarchy(
          tester,
          primary: relaunch,
          secondary: continueButton,
          size: size,
          primaryLabel: 'RELAUNCH',
          secondaryLabel: 'LATER',
        );

        final reward = _content
            .planet(_content.finalPlanetId)
            .masteryRewardCash;
        final multiplier = find.byKey(const Key('planet-mastery-multiplier'));
        for (final finder in [
          find.byKey(const Key('planet-mastery-planet')),
          find.byKey(const Key('planet-mastery-reward')),
          find.text('completion reward'),
          find.text('RUN COMPLETE'),
          multiplier,
        ]) {
          _expectVisibleInBody(tester, finder);
        }
        expect(
          tester
              .widget<Text>(find.byKey(const Key('planet-mastery-reward')))
              .data,
          '+${formatMiningCash(reward)}',
        );
        expect(
          tester.widget<Text>(multiplier).data,
          'Relaunch to start again with sales ×1.5. '
          'Only your relaunch count is kept.',
        );
        final explanation = tester.renderObject<RenderParagraph>(multiplier);
        expect(explanation.didExceedMaxLines, isFalse);
        expect(
          explanation.size.height,
          greaterThanOrEqualTo(
            explanation.getMaxIntrinsicHeight(explanation.size.width) - .5,
          ),
        );

        // The heading stays a single production-font line, never clipped.
        final heading = tester.renderObject<RenderParagraph>(
          find.text('FINAL PLANET MASTERED'),
        );
        expect(
          heading.size.width,
          greaterThanOrEqualTo(
            heading.getMaxIntrinsicWidth(double.infinity) - .5,
          ),
        );
        expect(
          heading.size.height,
          greaterThanOrEqualTo(
            heading.getMaxIntrinsicHeight(heading.size.width) - .5,
          ),
        );

        await tester.tap(relaunch);
        await tester.tap(continueButton);
        expect(relaunches, 1);
        expect(continues, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'roomy 390x844 floats a centered card with overlapping planet, outlined '
    'badge, white name, and rounded mockup actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var continues = 0;
      var opens = 0;
      await _pumpCard(
        tester,
        size: const Size(390, 844),
        textScale: 1.0,
        card: _nonfinalCard(
          onContinue: () => continues++,
          onOpenMap: () => opens++,
        ),
      );

      _expectFloatingComposition(tester, const Size(390, 844), isFinal: false);
      _expectOutlinedBadge(tester, const Size(390, 844), isFinal: false);

      final panel = tester.getRect(
        find.byKey(const Key('planet-mastery-panel')),
      );
      expect(panel.top, greaterThan(_insetsFor(const Size(390, 844)).top + 80));
      expect(panel.top, lessThan(844 / 2));

      final name = tester.widget<Text>(
        find.byKey(const Key('planet-mastery-planet')),
      );
      expect(name.data, 'Homeworld');
      expect(name.textAlign, TextAlign.center);
      expect(name.style?.color, Colors.white);
      expect(name.style?.fontFamily, 'Orbitron');
      expect(
        (tester
                    .getRect(find.byKey(const Key('planet-mastery-planet')))
                    .center
                    .dx -
                panel.center.dx)
            .abs(),
        lessThanOrEqualTo(1),
      );

      _expectActionHierarchy(
        tester,
        primary: find.byKey(const Key('planet-mastery-open-map')),
        secondary: find.byKey(const Key('planet-mastery-continue')),
        size: const Size(390, 844),
        primaryLabel: 'OPEN STELLAR MAP',
        secondaryLabel: 'CONTINUE',
      );

      await tester.tap(find.byKey(const Key('planet-mastery-open-map')));
      await tester.tap(find.byKey(const Key('planet-mastery-continue')));
      expect(opens, 1);
      expect(continues, 1);

      // The final variant uses the same composition with the Relaunch copy.
      await _pumpCard(
        tester,
        size: const Size(390, 844),
        textScale: 1.0,
        card: _finalCard(),
      );
      _expectFloatingComposition(tester, const Size(390, 844), isFinal: true);
      _expectOutlinedBadge(tester, const Size(390, 844), isFinal: true);
      _expectActionHierarchy(
        tester,
        primary: find.byKey(const Key('planet-mastery-relaunch')),
        secondary: find.byKey(const Key('planet-mastery-continue')),
        size: const Size(390, 844),
        primaryLabel: 'RELAUNCH',
        secondaryLabel: 'LATER',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

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
      'opens with the planet, successor, and every full gate and current '
      'value above the actions at $label',
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
        _expectGate(
          tester,
          index: 0,
          label: 'Homeworld mastered',
          satisfied: true,
        );
        _expectGate(
          tester,
          index: 1,
          label: 'Surveying 3',
          satisfied: false,
          currentValue: 'now LV 0',
        );
        _expectGate(
          tester,
          index: 2,
          label: '200,000 cash',
          satisfied: false,
          currentValue: '100',
        );

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
            final panel = tester.getRect(
              find.byKey(const Key('planet-mastery-panel')),
            );
            final art = tester.getRect(
              find.byKey(const Key('planet-mastery-art')),
            );
            expect(
              art.height,
              greaterThanOrEqualTo(96),
              reason: 'the compact 1.0 card keeps the previous 96px planet',
            );
            expect(
              (art.center.dx - panel.center.dx).abs(),
              lessThanOrEqualTo(1),
            );
          }
          _expectVisibleInBody(tester, find.text('All 3 sites commissioned'));
          _expectVisibleInBody(
            tester,
            find.byKey(const Key('planet-mastery-successor')),
          );
          _expectGate(
            tester,
            index: 0,
            label: 'Homeworld mastered',
            satisfied: true,
          );
          _expectGate(
            tester,
            index: 1,
            label: 'Surveying 3',
            satisfied: false,
            currentValue: 'now LV 0',
          );
          _expectGate(
            tester,
            index: 2,
            label: '200,000 cash',
            satisfied: false,
            currentValue: '100',
          );

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

  // The final card carries the long next-run explanation. It must open complete
  // next to the still-visible reward and pinned actions, with no text-size
  // reduction, ellipsis, or removed copy.
  for (final size in const [Size(360, 640), Size(874, 402)]) {
    for (final textScale in const [1.0, 1.3]) {
      for (final withInsets in const [false, true]) {
        testWidgets(
          'final card opens with the whole multiplier explanation inside the '
          'visible body at ${size.width.toInt()}x${size.height.toInt()} '
          'text $textScale ${withInsets ? 'with' : 'without'} safe insets',
          (tester) async {
            var continues = 0;
            var relaunches = 0;
            await _pumpCard(
              tester,
              size: size,
              textScale: textScale,
              insets: withInsets ? _insetsFor(size) : EdgeInsets.zero,
              card: _finalCard(
                onContinue: () => continues++,
                onRelaunch: () => relaunches++,
              ),
            );

            for (final finder in [
              find.byKey(const Key('planet-mastery-planet')),
              find.byKey(const Key('planet-mastery-reward')),
              find.text('completion reward'),
              find.text('RUN COMPLETE'),
            ]) {
              _expectVisibleInBody(tester, finder);
            }

            final multiplier = find.byKey(
              const Key('planet-mastery-multiplier'),
            );
            _expectVisibleInBody(tester, multiplier);
            final paragraph = tester.renderObject<RenderParagraph>(multiplier);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              paragraph.text.style?.fontFamily,
              'IBM Plex Mono',
              reason: 'the explanation must render in the production body font',
            );
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(
                paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
              ),
              reason: 'the explanation must render every wrapped line',
            );
            final explanation = tester.widget<Text>(multiplier);
            expect(explanation.maxLines, isNull);
            expect(explanation.overflow, isNot(TextOverflow.ellipsis));
            // No forced text scale and no reduced font size: the sentence
            // renders at the card's 12px body size times the requested scale.
            final richText = tester.widget<RichText>(
              find.descendant(of: multiplier, matching: find.byType(RichText)),
            );
            expect(richText.text.style?.fontSize, 12);
            expect(
              richText.textScaler.scale(12),
              closeTo(12 * textScale, .01),
              reason: 'the explanation must honor the requested text scale',
            );
            expect(
              explanation.data,
              'Relaunch to start again with sales ×1.5. '
              'Only your relaunch count is kept.',
            );

            final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
            final continueButton = find.byKey(
              const Key('planet-mastery-continue'),
            );
            expect(relaunch.hitTestable(), findsOneWidget);
            expect(continueButton.hitTestable(), findsOneWidget);
            await tester.tap(relaunch);
            await tester.tap(continueButton);
            expect(relaunches, 1);
            expect(continues, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final size in const [Size(360, 640), Size(874, 402)]) {
    testWidgets(
      'final card reads planet, reward, caption, status, explanation in '
      'accessibility order at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpCard(tester, size: size, card: _finalCard());

        final labels = _traversalLabels(tester);
        int indexOf(String label) =>
            labels.indexWhere((candidate) => candidate == label);
        final planet = indexOf('Io Frontier');
        final reward = indexOf('+90.00M');
        final caption = indexOf('completion reward');
        final status = indexOf('RUN COMPLETE');
        final explanation = labels.indexWhere(
          (candidate) =>
              candidate.contains('Relaunch to start again with sales ×1.5.'),
        );
        for (final (name, index) in [
          ('planet', planet),
          ('reward', reward),
          ('caption', caption),
          ('status', status),
          ('explanation', explanation),
        ]) {
          expect(index, isNonNegative, reason: '$name missing in $labels');
        }
        expect(planet, lessThan(reward), reason: 'in $labels');
        expect(reward, lessThan(caption), reason: 'in $labels');
        expect(caption, lessThan(status), reason: 'in $labels');
        expect(status, lessThan(explanation), reason: 'in $labels');

        // Keep the caption visually attached below the reward amount it
        // describes instead of parking it beside the planet name.
        final rewardRect = tester.getRect(
          find.byKey(const Key('planet-mastery-reward')),
        );
        final captionRect = tester.getRect(find.text('completion reward'));
        expect(
          (captionRect.center.dx - rewardRect.center.dx).abs(),
          lessThanOrEqualTo(1),
        );
        expect(captionRect.top, greaterThanOrEqualTo(rewardRect.bottom - .5));

        semantics.dispose();
      },
    );
  }

  for (final (multiplier, formatted) in const [(1.5, '×1.5'), (2.0, '×2')]) {
    testWidgets('final card projects next sales as $formatted', (tester) async {
      await _pumpCard(
        tester,
        size: const Size(360, 640),
        card: _finalCard(nextSaleMultiplier: multiplier),
      );

      final multiplierFinder = find.byKey(
        const Key('planet-mastery-multiplier'),
      );
      for (final finder in [
        find.byKey(const Key('planet-mastery-planet')),
        find.byKey(const Key('planet-mastery-reward')),
        find.text('completion reward'),
        find.text('RUN COMPLETE'),
        multiplierFinder,
      ]) {
        _expectVisibleInBody(tester, finder);
      }
      final text = tester.widget<Text>(multiplierFinder);
      expect(text.data, contains(formatted));
      final paragraph = tester.renderObject<RenderParagraph>(multiplierFinder);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
        ),
      );
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

      _expectGate(
        tester,
        index: 0,
        label: 'Lunar Frontier mastered',
        satisfied: true,
      );
      _expectGate(
        tester,
        index: 1,
        label: 'Surveying 5',
        satisfied: false,
        currentValue: 'now LV 3',
      );
      _expectGate(
        tester,
        index: 2,
        label: '16.00M cash',
        satisfied: false,
        currentValue: '100',
      );

      for (var index = 0; index < card.requirements.length; index++) {
        final gate = find.byKey(Key('planet-mastery-requirement-$index'));
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

  for (final size in const [Size(360, 640), Size(874, 402)]) {
    testWidgets(
      'Ceres mastery shows its full long Io gates and actual current values at '
      '${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final card = _projectedCeresCard();
        await _pumpCard(tester, size: size, card: card);

        expect(card.requirements.map((requirement) => requirement.label), [
          'Ceres Frontier sites 3/3',
          'Surveying 5',
          '90.00M cash',
        ]);
        expect(find.text('Ceres Frontier sites 3/3'), findsNothing);
        _expectGate(
          tester,
          index: 0,
          label: 'Ceres Frontier mastered',
          satisfied: true,
        );
        _expectGate(
          tester,
          index: 1,
          label: 'Surveying 5',
          satisfied: false,
          currentValue: 'now LV 4',
        );
        _expectGate(
          tester,
          index: 2,
          label: '90.00M cash',
          satisfied: false,
          currentValue: '12.35M',
        );

        final openMap = find.byKey(const Key('planet-mastery-open-map'));
        final continueButton = find.byKey(const Key('planet-mastery-continue'));
        expect(openMap.hitTestable(), findsOneWidget);
        expect(continueButton.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // Plan-mandated roomy first frame at 1.0: both variants must show their full
  // key content and both stacked actions without scrolling.
  for (final size in const [Size(390, 844), Size(430, 932)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('roomy $label opens the full home card at 1.0', (tester) async {
      var continues = 0;
      var opens = 0;
      await _pumpCard(
        tester,
        size: size,
        textScale: 1.0,
        card: _nonfinalCard(
          onContinue: () => continues++,
          onOpenMap: () => opens++,
        ),
      );

      _expectFloatingComposition(tester, size, isFinal: false);
      _expectVisibleInBody(
        tester,
        find.byKey(const Key('planet-mastery-planet')),
      );
      _expectVisibleInBody(tester, find.text('All 3 sites commissioned'));
      _expectVisibleInBody(
        tester,
        find.byKey(const Key('planet-mastery-successor')),
      );
      _expectGate(
        tester,
        index: 0,
        label: 'Homeworld mastered',
        satisfied: true,
      );
      _expectGate(
        tester,
        index: 1,
        label: 'Surveying 3',
        satisfied: false,
        currentValue: 'now LV 0',
      );
      _expectGate(
        tester,
        index: 2,
        label: '200,000 cash',
        satisfied: false,
        currentValue: '100',
      );

      final openMap = find.byKey(const Key('planet-mastery-open-map'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      _expectActionHierarchy(
        tester,
        primary: openMap,
        secondary: continueButton,
        size: size,
        primaryLabel: 'OPEN STELLAR MAP',
        secondaryLabel: 'CONTINUE',
      );
      await tester.tap(openMap);
      await tester.tap(continueButton);
      expect(opens, 1);
      expect(continues, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('roomy $label opens the full Io card with ×2 at 1.0', (
      tester,
    ) async {
      var continues = 0;
      var relaunches = 0;
      await _pumpCard(
        tester,
        size: size,
        textScale: 1.0,
        card: _finalCard(
          nextSaleMultiplier: 2.0,
          onContinue: () => continues++,
          onRelaunch: () => relaunches++,
        ),
      );

      _expectFloatingComposition(tester, size, isFinal: true);
      for (final finder in [
        find.byKey(const Key('planet-mastery-planet')),
        find.byKey(const Key('planet-mastery-reward')),
        find.text('completion reward'),
        find.text('RUN COMPLETE'),
        find.byKey(const Key('planet-mastery-multiplier')),
      ]) {
        _expectVisibleInBody(tester, finder);
      }
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-multiplier')))
            .data,
        contains('×2'),
      );

      final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      _expectActionHierarchy(
        tester,
        primary: relaunch,
        secondary: continueButton,
        size: size,
        primaryLabel: 'RELAUNCH',
        secondaryLabel: 'LATER',
      );
      await tester.tap(relaunch);
      await tester.tap(continueButton);
      expect(relaunches, 1);
      expect(continues, 1);
      expect(tester.takeException(), isNull);
    });
  }

  // Approved mockup follow-up: roomy portrait grows the planet, milestone
  // badge, planet name, and Io reward toward the mockup's scale.
  for (final size in const [Size(390, 844), Size(430, 932)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('roomy $label text $textScale uses the mockup planet and '
          'milestone type scale', (tester) async {
        await _pumpCard(
          tester,
          size: size,
          textScale: textScale,
          card: _nonfinalCard(),
        );
        _expectMockupScale(tester, textScale: textScale, isFinal: false);

        await _pumpCard(
          tester,
          size: size,
          textScale: textScale,
          card: _finalCard(nextSaleMultiplier: 2),
        );
        _expectMockupScale(tester, textScale: textScale, isFinal: true);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // The enlarged roomy type must also hold for the real later-planet names and
  // their projected gates, not only Homeworld and Io. These fixtures use the
  // authored Lunar Frontier / Ceres Frontier mastery cards with real current
  // values, opened without scrolling at the focus sizes.
  for (final size in const [Size(390, 844), Size(430, 932)]) {
    final insets = size.width == 430
        ? const EdgeInsets.fromLTRB(0, 59, 0, 34)
        : const EdgeInsets.fromLTRB(0, 24, 0, 24);
    for (final textScale in const [1.0, 1.3]) {
      for (final fixture in const ['Lunar Frontier', 'Ceres Frontier']) {
        testWidgets('roomy ${size.width.toInt()}x${size.height.toInt()} text '
            '$textScale keeps the real $fixture name, gates, and actions '
            'complete on the first frame', (tester) async {
          var continues = 0;
          var opens = 0;
          final lunar = fixture == 'Lunar Frontier';
          final card = lunar
              ? _projectedLaterCard(
                  onContinue: () => continues++,
                  onOpenMap: () => opens++,
                )
              : _projectedCeresCard(
                  onContinue: () => continues++,
                  onOpenMap: () => opens++,
                );
          await _pumpCard(
            tester,
            size: size,
            textScale: textScale,
            insets: insets,
            card: card,
          );

          _expectMockupScale(tester, textScale: textScale, isFinal: false);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('planet-mastery-planet')))
                .data,
            fixture,
          );

          if (lunar) {
            _expectGate(
              tester,
              index: 0,
              label: 'Lunar Frontier mastered',
              satisfied: true,
            );
            _expectGate(
              tester,
              index: 1,
              label: 'Surveying 5',
              satisfied: false,
              currentValue: 'now LV 3',
            );
            _expectGate(
              tester,
              index: 2,
              label: '16.00M cash',
              satisfied: false,
              currentValue: '100',
            );
          } else {
            _expectGate(
              tester,
              index: 0,
              label: 'Ceres Frontier mastered',
              satisfied: true,
            );
            _expectGate(
              tester,
              index: 1,
              label: 'Surveying 5',
              satisfied: false,
              currentValue: 'now LV 4',
            );
            _expectGate(
              tester,
              index: 2,
              label: '90.00M cash',
              satisfied: false,
              currentValue: '12.35M',
            );
          }

          final openMap = find.byKey(const Key('planet-mastery-open-map'));
          final continueButton = find.byKey(
            const Key('planet-mastery-continue'),
          );
          _expectActionHierarchy(
            tester,
            primary: openMap,
            secondary: continueButton,
            size: size,
            primaryLabel: 'OPEN STELLAR MAP',
            secondaryLabel: 'CONTINUE',
          );
          await tester.tap(openMap);
          await tester.tap(continueButton);
          expect(opens, 1);
          expect(continues, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('panel carries the mockup cyan border and glow', (tester) async {
    await _pumpCard(
      tester,
      size: const Size(390, 844),
      textScale: 1.0,
      card: _nonfinalCard(),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('planet-mastery-panel')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = (decoration.border! as Border).top;
    expect(
      border.color.a,
      greaterThan(0.5),
      reason: 'the mockup border is stronger than the previous 39% cyan',
    );
    expect(border.width, greaterThanOrEqualTo(1));
    expect(
      decoration.boxShadow!.any(
        (shadow) =>
            shadow.blurRadius >= 16 &&
            shadow.color.a > 0 &&
            shadow.color.g > shadow.color.r &&
            shadow.color.b > shadow.color.r,
      ),
      isTrue,
      reason: 'the mockup panel carries a cyan glow behind its dark shadow',
    );
  });

  testWidgets('primary action uses the mockup fill and height', (tester) async {
    await _pumpCard(
      tester,
      size: const Size(390, 844),
      textScale: 1.0,
      card: _nonfinalCard(),
    );

    final primary = find.byKey(const Key('planet-mastery-open-map'));
    final button = tester.widget<ElevatedButton>(
      find.descendant(of: primary, matching: find.byType(ElevatedButton)),
    );
    final fill = button.style!.backgroundColor!.resolve(const <WidgetState>{});
    expect(fill, masteryPrimaryFill);
    expect(
      fill,
      isNot(MiningTheme.highlight),
      reason: 'the mockup fill is softer than the neon game highlight',
    );
    expect(tester.getRect(primary).height, greaterThanOrEqualTo(52));
  });

  // Roomy portrait is content-sized: the primary action must sit directly
  // below the last detail, not at the bottom of a stretched panel.
  for (final size in const [Size(390, 844), Size(430, 932)]) {
    final insets = size.width == 430
        ? const EdgeInsets.fromLTRB(0, 59, 0, 34)
        : const EdgeInsets.fromLTRB(0, 24, 0, 24);
    for (final textScale in const [1.0, 1.3]) {
      final label =
          '${size.width.toInt()}x${size.height.toInt()} text $textScale';

      testWidgets(
        'roomy $label keeps Homeworld actions within 32px of the last gate',
        (tester) async {
          final card = _nonfinalCard();
          await _pumpCard(
            tester,
            size: size,
            textScale: textScale,
            insets: insets,
            card: card,
          );

          final lastGate = find.byKey(
            const Key('planet-mastery-requirement-2'),
          );
          final primary = find.byKey(const Key('planet-mastery-open-map'));
          _expectVisibleInBody(tester, lastGate);
          _expectPrimaryNearLastDetail(
            tester,
            primary: primary,
            lastDetail: lastGate,
          );
          expect(primary.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'roomy $label keeps Io actions within 32px of the explanation',
        (tester) async {
          await _pumpCard(
            tester,
            size: size,
            textScale: textScale,
            insets: insets,
            card: _finalCard(nextSaleMultiplier: 2.0),
          );

          final lastDetail = find.byKey(const Key('planet-mastery-multiplier'));
          final primary = find.byKey(const Key('planet-mastery-relaunch'));
          _expectVisibleInBody(tester, lastDetail);
          _expectPrimaryNearLastDetail(
            tester,
            primary: primary,
            lastDetail: lastDetail,
          );
          expect(primary.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'roomy 390x844 text 1.3 keeps the long Ceres gates complete and the '
    'primary action near the last gate',
    (tester) async {
      const size = Size(390, 844);
      await _pumpCard(
        tester,
        size: size,
        textScale: 1.3,
        insets: const EdgeInsets.fromLTRB(0, 24, 0, 24),
        card: _projectedCeresCard(),
      );

      _expectGate(
        tester,
        index: 0,
        label: 'Ceres Frontier mastered',
        satisfied: true,
      );
      _expectGate(
        tester,
        index: 1,
        label: 'Surveying 5',
        satisfied: false,
        currentValue: 'now LV 4',
      );
      _expectGate(
        tester,
        index: 2,
        label: '90.00M cash',
        satisfied: false,
        currentValue: '12.35M',
      );
      final primary = find.byKey(const Key('planet-mastery-open-map'));
      _expectPrimaryNearLastDetail(
        tester,
        primary: primary,
        lastDetail: find.byKey(const Key('planet-mastery-requirement-2')),
      );
      expect(primary.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Compact portrait and short landscape size the panel to its content so the
  // pinned actions sit next to the details instead of at the bottom of a
  // fill-height body, at both text scales and with/without safe insets.
  for (final size in const [Size(360, 640), Size(874, 402)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    for (final textScale in const [1.0, 1.3]) {
      for (final withInsets in const [false, true]) {
        final insets = withInsets ? _insetsFor(size) : EdgeInsets.zero;
        for (final isFinal in const [false, true]) {
          testWidgets(
            '${isFinal ? 'Io' : 'Home'} panel hugs its content at $label '
            'text $textScale ${withInsets ? 'with' : 'without'} insets',
            (tester) async {
              var continues = 0;
              var primaryTaps = 0;
              final card = isFinal
                  ? _finalCard(
                      onContinue: () => continues++,
                      onRelaunch: () => primaryTaps++,
                    )
                  : _nonfinalCard(
                      onContinue: () => continues++,
                      onOpenMap: () => primaryTaps++,
                    );
              await _pumpCard(
                tester,
                size: size,
                textScale: textScale,
                insets: insets,
                card: card,
              );

              _expectFloatingComposition(
                tester,
                size,
                isFinal: isFinal,
                insets: insets,
              );
              final primary = find.byKey(
                isFinal
                    ? const Key('planet-mastery-relaunch')
                    : const Key('planet-mastery-open-map'),
              );
              final secondary = find.byKey(
                const Key('planet-mastery-continue'),
              );
              _expectActionHierarchy(
                tester,
                primary: primary,
                secondary: secondary,
                size: size,
                insets: insets,
                primaryLabel: isFinal ? 'RELAUNCH' : 'OPEN STELLAR MAP',
                secondaryLabel: isFinal ? 'LATER' : 'CONTINUE',
              );

              final lastDetail = isFinal
                  ? find.byKey(const Key('planet-mastery-multiplier'))
                  : find.byKey(const Key('planet-mastery-requirement-2'));
              _expectVisibleInBody(tester, lastDetail);
              _expectPrimaryNearLastDetail(
                tester,
                primary: primary,
                lastDetail: lastDetail,
              );

              final panel = tester.getRect(
                find.byKey(const Key('planet-mastery-panel')),
              );
              final bottomLimit = math.max(
                insets.bottom,
                size.width > size.height ? 8.0 : 12.0,
              );
              final fillFloor = size.width > size.height
                  ? insets.top + 4 + 20
                  : insets.top + 168;
              final fillHeight = size.height - fillFloor - bottomLimit;
              expect(
                panel.height,
                lessThan(fillHeight),
                reason:
                    'the panel must shrink to its content, not fill '
                    '$fillHeight',
              );
              expect(
                panel.top,
                greaterThan(fillFloor),
                reason: 'content sizing must close the empty top gap',
              );
              expect(panel.bottom, closeTo(size.height - bottomLimit, .5));

              await tester.tap(primary);
              await tester.tap(secondary);
              expect(primaryTaps, 1);
              expect(continues, 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  // Approved mockup follow-up: roomy portrait gains the mockup's more generous
  // vertical rhythm and larger gate/explanation type where the first frame has
  // room. The tight 390x720 breakpoint keeps its existing spacing below.
  for (final size in const [Size(390, 844), Size(430, 932)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    final insets = size.width == 430
        ? const EdgeInsets.fromLTRB(0, 59, 0, 34)
        : const EdgeInsets.fromLTRB(0, 24, 0, 24);
    for (final textScale in const [1.0, 1.3]) {
      testWidgets(
        'roomy $label text $textScale frames the card toward the mockup and '
        'enlarges gate rows and the Io explanation',
        (tester) async {
          final maxTop = size.width == 390
              ? (textScale == 1.0 ? 250.0 : 235.0)
              : (textScale == 1.0 ? 290.0 : 270.0);
          final minHeight = textScale == 1.0 ? 415.0 : 460.0;
          final fixtures =
              <(String, PlanetMasteredCard, List<(String, String?)>)>[
                (
                  'Homeworld',
                  _nonfinalCard(),
                  [
                    ('Homeworld mastered', null),
                    ('Surveying 3', 'now LV 0'),
                    ('200,000 cash', '100'),
                  ],
                ),
                (
                  'Lunar Frontier',
                  _projectedLaterCard(),
                  [
                    ('Lunar Frontier mastered', null),
                    ('Surveying 5', 'now LV 3'),
                    ('16.00M cash', '100'),
                  ],
                ),
                (
                  'Ceres Frontier',
                  _projectedCeresCard(),
                  [
                    ('Ceres Frontier mastered', null),
                    ('Surveying 5', 'now LV 4'),
                    ('90.00M cash', '12.35M'),
                  ],
                ),
              ];
          for (final (name, card, gates) in fixtures) {
            await _pumpCard(
              tester,
              size: size,
              textScale: textScale,
              insets: insets,
              card: card,
            );
            final panel = tester.getRect(
              find.byKey(const Key('planet-mastery-panel')),
            );
            expect(
              panel.top,
              lessThanOrEqualTo(maxTop),
              reason: '$name panel $panel sits lower than the mockup framing',
            );
            expect(
              panel.height,
              greaterThanOrEqualTo(minHeight),
              reason: '$name panel $panel is shorter than the mockup framing',
            );
            for (var index = 0; index < gates.length; index++) {
              final (gateLabel, currentValue) = gates[index];
              _expectGate(
                tester,
                index: index,
                label: gateLabel,
                satisfied: index == 0,
                currentValue: currentValue,
                fontSize: 13,
                textScale: textScale,
              );
            }
            _expectPrimaryNearLastDetail(
              tester,
              primary: find.byKey(const Key('planet-mastery-open-map')),
              lastDetail: find.byKey(
                Key('planet-mastery-requirement-${gates.length - 1}'),
              ),
            );
          }

          await _pumpCard(
            tester,
            size: size,
            textScale: textScale,
            insets: insets,
            card: _finalCard(nextSaleMultiplier: 2),
          );
          final panel = tester.getRect(
            find.byKey(const Key('planet-mastery-panel')),
          );
          expect(
            panel.top,
            lessThanOrEqualTo(maxTop),
            reason: 'Io panel $panel sits lower than the mockup framing',
          );
          expect(
            panel.height,
            greaterThanOrEqualTo(minHeight),
            reason: 'Io panel $panel is shorter than the mockup framing',
          );
          final explanation = find.byKey(
            const Key('planet-mastery-multiplier'),
          );
          _expectVisibleInBody(tester, explanation);
          final richText = tester.widget<RichText>(
            find.descendant(of: explanation, matching: find.byType(RichText)),
          );
          expect(
            richText.text.style?.fontSize,
            13,
            reason: 'the Io explanation must gain the mockup body size',
          );
          expect(richText.textScaler.scale(13), closeTo(13 * textScale, .01));
          final paragraph = tester.renderObject<RenderParagraph>(explanation);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
            ),
            reason: 'the enlarged explanation must render every line',
          );
          _expectPrimaryNearLastDetail(
            tester,
            primary: find.byKey(const Key('planet-mastery-relaunch')),
            lastDetail: explanation,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'roomy 390x720 text 1.3 keeps the compact roomy spacing so the full Io '
    'card still opens without scrolling',
    (tester) async {
      await _pumpCard(
        tester,
        size: const Size(390, 720),
        textScale: 1.3,
        insets: const EdgeInsets.fromLTRB(0, 47, 0, 34),
        card: _finalCard(nextSaleMultiplier: 2),
      );

      final panel = tester.getRect(
        find.byKey(const Key('planet-mastery-panel')),
      );
      expect(panel.height, lessThanOrEqualTo(471));
      final explanation = find.byKey(const Key('planet-mastery-multiplier'));
      _expectVisibleInBody(tester, explanation);
      final richText = tester.widget<RichText>(
        find.descendant(of: explanation, matching: find.byType(RichText)),
      );
      expect(richText.text.style?.fontSize, 12);
      _expectPrimaryNearLastDetail(
        tester,
        primary: find.byKey(const Key('planet-mastery-relaunch')),
        lastDetail: explanation,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('primary action is reached by Tab and activates', (tester) async {
    var opens = 0;
    await _pumpCard(
      tester,
      size: const Size(390, 844),
      textScale: 1.0,
      card: _nonfinalCard(onOpenMap: () => opens++),
    );

    final openMap = find.byKey(const Key('planet-mastery-open-map'));
    final focusNode = Focus.of(
      tester.element(
        find.descendant(of: openMap, matching: find.byType(GestureDetector)),
      ),
    );
    expect(focusNode.canRequestFocus, isTrue);

    var focused = false;
    for (var tab = 0; tab < 6 && !focused; tab++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      focused = focusNode.hasFocus;
    }
    expect(
      focused,
      isTrue,
      reason: 'Tab traversal must reach OPEN STELLAR MAP',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opens, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(opens, 2);
    expect(tester.takeException(), isNull);
  });
}
