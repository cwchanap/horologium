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
        // The shell hosts this card in a bottom sheet: loose height, bottom
        // aligned. Mirror that so the card's bounded composition is measured
        // instead of being stretched to the scaffold.
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: card),
        ),
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
    MiningTheme.highlight,
  );

  final safe = _safeRect(size, _insetsFor(size));
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
}) {
  final insets = _insetsFor(size);
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
  expect(panel.bottom, greaterThan(safe.bottom - 24));
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
}) {
  final gate = find.byKey(Key('planet-mastery-requirement-$index'));
  expect(gate, findsOneWidget, reason: 'gate $index');
  _expectVisibleInBody(tester, gate);
  expect(
    find.descendant(
      of: gate,
      matching: find.byIcon(satisfied ? Icons.check : Icons.close),
    ),
    findsOneWidget,
    reason: 'gate $index',
  );
  expect(
    tester
        .widget<Icon>(
          find.descendant(
            of: gate,
            matching: find.byIcon(satisfied ? Icons.check : Icons.close),
          ),
        )
        .color,
    satisfied ? MiningTheme.accent : MiningTheme.gate,
  );

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
      final card = _nonfinalCard(
        onContinue: () => continues++,
        onOpenMap: () => opens++,
      );
      await _pumpCard(tester, size: size, card: card);

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

      expect(find.text('All 3 sites commissioned'), findsOneWidget);
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

      final reward = _content.planet(_content.finalPlanetId).masteryRewardCash;
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-reward')))
            .data,
        '+${formatMiningCash(reward)}',
      );
      expect(find.text('completion reward'), findsOneWidget);
      expect(find.text('RUN COMPLETE'), findsOneWidget);

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
