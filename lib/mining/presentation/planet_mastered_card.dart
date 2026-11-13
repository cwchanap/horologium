import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// The floating panel starts this far below the live top inset in portrait so
/// its top-mounted close control clears the inline cargo gauge (84px tall at
/// 50px down). Compact portrait fills from this floor; roomy portrait uses it
/// as the minimum panel top while sizing and centering the content.
const double _portraitTopClearance = 168;

const double _portraitMargin = 20;
const double _landscapeMargin = 12;
const double _panelMaxWidth = 440;
const double _landscapeMaxWidth = 560;
const double _panelMaxHeight = 760;
const double _panelRadius = 20;
const double _actionRadius = 12;
const double _closeSize = 48;

/// Transient feedback for a deploy that just mastered a planet. The final
/// variant pays the authored reward on the card and relays Relaunch through
/// the shell; the card itself never mutates or persists state.
class PlanetMasteredCard extends StatelessWidget {
  const PlanetMasteredCard({
    super.key,
    required this.masteredPlanet,
    required this.successorName,
    required this.requirements,
    required this.nextSaleMultiplier,
    required this.onContinue,
    required this.onOpenMap,
    this.isFinal = false,
    this.rewardCash,
    this.onRelaunch,
    this.topSafeArea = 0,
  });

  final MiningPlanetDefinition masteredPlanet;
  final String? successorName;
  final List<StellarMapRequirementView> requirements;

  /// The already-projected next-run sale multiplier from `StellarMapView`.
  final double nextSaleMultiplier;
  final bool isFinal;
  final int? rewardCash;
  final VoidCallback onContinue;
  final VoidCallback onOpenMap;
  final VoidCallback? onRelaunch;

  /// The shell's live top system inset. The retained mastery dialog route
  /// follows rotation and inset changes through this value; the card uses the
  /// larger of it and the route's own top padding.
  final double topSafeArea;

  String get _title => isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final landscape = size.width > size.height;
    final compactPortrait = !landscape && size.height <= 700;
    final topInset = math.max(topSafeArea, padding.top);

    // Portrait keeps the mockup's art-led stack, shrinking the planet on short
    // phones. Landscape shrinks it further; its actions stay stacked so the
    // approved primary-then-secondary hierarchy never changes.
    final Size artSize;
    final double overlap;
    if (landscape) {
      artSize = const Size(40, 40);
      overlap = 20;
    } else if (compactPortrait) {
      artSize = const Size(96, 96);
      overlap = 26;
    } else {
      artSize = const Size(130, 130);
      overlap = 46;
    }

    // The planet paints above the panel. Outside the panel, its top half needs
    // its own space; in portrait the close also needs the fixed HUD clearance.
    final artAbovePanel = artSize.height - overlap;
    final bodyTop =
        overlap +
        (landscape
            ? 2
            : compactPortrait
            ? 6
            : 12);
    final compact = landscape || compactPortrait;
    final panelTop = landscape
        ? topInset + 4 + artAbovePanel
        : topInset + _portraitTopClearance;
    final horizontalInset = landscape
        ? math.max(padding.left, padding.right) + _landscapeMargin
        : math.max(_portraitMargin, math.max(padding.left, padding.right) + 8);
    final bottomLimit = math.max(padding.bottom, landscape ? 8.0 : 12.0);
    final availablePanelHeight = math.min(
      _panelMaxHeight,
      math.max(120.0, size.height - panelTop - bottomLimit),
    );
    final cardWidth = math.min(
      landscape ? _landscapeMaxWidth : _panelMaxWidth,
      size.width - 2 * horizontalInset,
    );
    final roomyPortrait = !landscape && !compactPortrait;
    final panel = roomyPortrait
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availablePanelHeight),
            child: _panel(
              context,
              compact: compact,
              bodyTop: bodyTop,
              contentSized: true,
            ),
          )
        : SizedBox(
            height: availablePanelHeight,
            child: _panel(
              context,
              compact: compact,
              bodyTop: bodyTop,
              contentSized: false,
            ),
          );

    // Only the card-plus-overlap composition is interactive, so taps above or
    // beside it reach the dismissible barrier. The close lives inside these
    // bounds too, keeping its whole visible circle hit-testable. Roomy portrait
    // centers the content-sized card but clamps it to the HUD-safe top floor;
    // compact layouts bottom-anchor the fill-available panel.
    return CustomSingleChildLayout(
      delegate: _MasteryCardLayout(
        roomyPortrait: roomyPortrait,
        topInset: topInset,
        artAbovePanel: artAbovePanel,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomLimit),
        child: SizedBox(
          key: const Key('planet-mastery-card'),
          width: cardWidth,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: artAbovePanel),
                child: DefaultTextStyle(
                  // Replace the MaterialApp fallback wholesale; merging it
                  // would keep Flutter's yellow double-underline decoration
                  // now that this route has no Material ancestor.
                  style: const TextStyle(
                    color: MiningTheme.primaryText,
                    fontFamily: 'IBM Plex Mono',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                  child: panel,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: _art(artSize)),
              ),
              Positioned(
                top: math.max(0, artAbovePanel - 22),
                left: landscape ? 4 : null,
                right: landscape ? null : 4,
                child: _close(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required bool compact,
    required double bodyTop,
    required bool contentSized,
  }) => Container(
    key: const Key('planet-mastery-panel'),
    decoration: BoxDecoration(
      color: MiningTheme.panel,
      borderRadius: BorderRadius.circular(_panelRadius),
      border: Border.all(color: MiningTheme.accent.withAlpha(100)),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: contentSized ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (contentSized)
          Flexible(
            fit: FlexFit.loose,
            child: _scrollBody(context, compact: compact, bodyTop: bodyTop),
          )
        else
          Expanded(
            child: _scrollBody(context, compact: compact, bodyTop: bodyTop),
          ),
        Padding(
          key: const Key('mining-sheet-pinned-footer'),
          padding: EdgeInsets.fromLTRB(
            18,
            compact ? 6 : 8,
            18,
            compact ? 6 : 10,
          ),
          child: _actions(compact: compact),
        ),
      ],
    ),
  );

  Widget _scrollBody(
    BuildContext context, {
    required bool compact,
    required double bodyTop,
  }) => ScrollConfiguration(
    // A desktop scrollbar would inset the body by 12px and push the mockup's
    // centered badge off the card's centre line.
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: SingleChildScrollView(
      key: const Key('mining-sheet-body'),
      padding: EdgeInsets.fromLTRB(18, bodyTop, 18, 4),
      child: _body(compact: compact),
    ),
  );

  Widget _body({required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: _badge(compact: compact)),
      SizedBox(height: compact ? 4 : 8),
      _planetName(),
      if (isFinal) ...[
        const SizedBox(height: 2),
        _reward(),
        _completionReward(),
        SizedBox(height: compact ? 6 : 10),
        Align(alignment: Alignment.centerLeft, child: _runComplete()),
        const SizedBox(height: 2),
        _explanation(),
      ] else ...[
        const SizedBox(height: 2),
        Text(
          'All ${masteredPlanet.sites.length} sites commissioned',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MiningTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'NEXT · ${(successorName ?? 'The next frontier').toUpperCase()}',
            key: const Key('planet-mastery-successor'),
            style: const TextStyle(
              color: MiningTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final (index, requirement) in requirements.indexed)
          _MasteryRequirement(
            key: Key('planet-mastery-requirement-$index'),
            // The first projected successor gate is its mastery requirement.
            // The card uses the mockup's wording; the shared Stellar Map
            // projection keeps its own `sites 3/3` label.
            label: !isFinal && index == 0
                ? '${masteredPlanet.name} mastered'
                : requirement.label,
            requirement: requirement,
            compact: compact,
          ),
      ],
    ],
  );

  Widget _badge({required bool compact}) => Container(
    key: const Key('planet-mastery-badge'),
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 4 : 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: MiningTheme.accent),
    ),
    child: Semantics(
      header: true,
      // The card's dialog route supplies the route scope but no name; this
      // title node is the milestone route name a screen reader announces.
      namesRoute: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: MiningTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _title,
            style: const TextStyle(
              color: MiningTheme.accent,
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _planetName() => Text(
    masteredPlanet.name,
    key: const Key('planet-mastery-planet'),
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: MiningTheme.primaryText,
      fontFamily: 'Orbitron',
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.1,
    ),
  );

  Widget _reward() => Text(
    '+${formatMiningCash(rewardCash ?? 0)}',
    key: const Key('planet-mastery-reward'),
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: MiningTheme.warning,
      fontFamily: 'Orbitron',
      fontSize: 24,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _completionReward() => const Text(
    'completion reward',
    textAlign: TextAlign.center,
    style: TextStyle(color: MiningTheme.secondaryText, fontSize: 11),
  );

  Widget _runComplete() => const Text(
    'RUN COMPLETE',
    style: TextStyle(
      color: MiningTheme.accent,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    ),
  );

  Widget _explanation() => Text(
    'Relaunch to start again with sales '
    '${formatSaleMultiplier(nextSaleMultiplier)}. '
    'Only your relaunch count is kept.',
    key: const Key('planet-mastery-multiplier'),
    style: const TextStyle(color: MiningTheme.secondaryText, height: 1.4),
  );

  Widget _actions({required bool compact}) {
    final primary = _MasteryAction(
      key: isFinal
          ? const Key('planet-mastery-relaunch')
          : const Key('planet-mastery-open-map'),
      label: isFinal ? 'RELAUNCH' : 'OPEN STELLAR MAP',
      emphasized: true,
      onPressed: isFinal ? onRelaunch! : onOpenMap,
    );
    final secondary = _MasteryAction(
      key: const Key('planet-mastery-continue'),
      label: isFinal ? 'LATER' : 'CONTINUE',
      emphasized: false,
      onPressed: onContinue,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: double.infinity, child: primary),
        SizedBox(height: compact ? 6 : 8),
        SizedBox(width: double.infinity, child: secondary),
      ],
    );
  }

  Widget _art(Size size) => Image.asset(
    masteredPlanet.planetAsset,
    key: const Key('planet-mastery-art'),
    width: size.width,
    height: size.height,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => SizedBox(
      width: size.width,
      height: size.height,
      child: const Icon(Icons.public_rounded, color: Colors.white24, size: 96),
    ),
  );

  Widget _close(BuildContext context) => Semantics(
    label: 'Close $_title',
    button: true,
    child: Material(
      color: const Color(0xFF060A10),
      shape: CircleBorder(
        side: BorderSide(color: MiningTheme.accent.withAlpha(100)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: _closeSize,
          height: _closeSize,
          child: Icon(Icons.close, color: Colors.white60, size: 20),
        ),
      ),
    ),
  );
}

class _MasteryCardLayout extends SingleChildLayoutDelegate {
  const _MasteryCardLayout({
    required this.roomyPortrait,
    required this.topInset,
    required this.artAbovePanel,
  });

  final bool roomyPortrait;
  final double topInset;
  final double artAbovePanel;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (size.width - childSize.width) / 2;
    if (!roomyPortrait) {
      return Offset(x, size.height - childSize.height);
    }
    // Center the content-sized card, but never above the floor that keeps the
    // close control below the inline cargo gauge.
    final centered = (size.height - childSize.height) / 2;
    final hudSafeFloor = topInset + _portraitTopClearance - artAbovePanel;
    return Offset(x, math.max(centered, hudSafeFloor));
  }

  @override
  bool shouldRelayout(_MasteryCardLayout oldDelegate) =>
      roomyPortrait != oldDelegate.roomyPortrait ||
      topInset != oldDelegate.topInset ||
      artAbovePanel != oldDelegate.artAbovePanel;
}

class _MasteryRequirement extends StatelessWidget {
  const _MasteryRequirement({
    super.key,
    required this.label,
    required this.requirement,
    this.compact = false,
  });

  /// The card-facing wording for the projected gate; the model's own label is
  /// untouched so the Stellar Map keeps its existing copy.
  final String label;
  final StellarMapRequirementView requirement;

  /// Tightens the row for the short landscape card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = requirement.isSatisfied
        ? MiningTheme.accent
        : MiningTheme.gate;
    return Semantics(
      label: [
        label,
        requirement.isSatisfied ? 'satisfied' : 'required',
        if (requirement.currentValue != null) requirement.currentValue!,
      ].join(', '),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              requirement.isSatisfied ? Icons.check : Icons.close,
              color: statusColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 4,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: MiningTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (requirement.currentValue != null)
                    Text(
                      '· ${requirement.currentValue}',
                      style: const TextStyle(
                        color: MiningTheme.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasteryAction extends StatelessWidget {
  const _MasteryAction({
    super.key,
    required this.label,
    required this.emphasized,
    required this.onPressed,
  });

  final String label;
  final bool emphasized;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: .8,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_actionRadius),
    );
    if (!emphasized) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          foregroundColor: Colors.white,
          side: BorderSide(color: MiningTheme.accent.withAlpha(120)),
          shape: shape,
          textStyle: textStyle,
        ),
        child: Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        backgroundColor: MiningTheme.highlight,
        foregroundColor: const Color(0xFF04121A),
        shape: shape,
        textStyle: textStyle,
      ),
      child: Text(label),
    );
  }
}
