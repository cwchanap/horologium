import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// The portrait sheet's fixed 160px band already clears the Mine Site's
/// 134px top-right HUD by this much. Only a larger status-bar inset pushes
/// that inline cargo gauge under this route's top-mounted close hex.
const double _sceneHudClearance = 26;

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

  /// The top system inset of the screen under this modal route. A modal
  /// bottom sheet removes the top padding from its own MediaQuery, so the
  /// shell passes the inset in to keep this card's close control clear of
  /// the inline scene HUD that did receive it.
  final double topSafeArea;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    // Landscape panels are always short. Portrait compacts whenever the
    // viewport itself is short: at 360x640 the full art-led stack cannot show
    // all three gates even at text scale 1.0, while compact keeps the full
    // name, gates, and both pinned actions on the first frame.
    // shortcut: the 700px breakpoint covers the short-phone target; move to a
    // measured body viewport if more screen classes need it.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactPortrait = !landscape && size.height <= 700;
    // The modal route's own MediaQuery lost the shell's top padding; the
    // inline Mine Site HUD underneath still moved down by it, so move this
    // sheet's top chrome down with the excess.
    final portraitTopShift = (topSafeArea - _sceneHudClearance).clamp(
      0.0,
      double.infinity,
    );
    // The final card's explanation is a long sentence. In the short layouts it
    // runs full width under the summary instead of wrapping inside the narrow
    // details column, which used to push it below the visible body. The art
    // shrinks in those layouts so the reward and the explanation keep their
    // measured first-frame widths.
    final Size artSize;
    if (landscape) {
      artSize = isFinal
          ? (textScale > 1 ? const Size(28, 28) : const Size(40, 40))
          : const Size(104, 104);
    } else if (compactPortrait) {
      artSize = isFinal
          ? (textScale > 1 ? const Size(48, 48) : const Size(112, 112))
          : (textScale > 1 ? const Size(80, 80) : const Size(112, 112));
    } else {
      artSize = const Size(160, 132);
    }
    return MiningSheetFrame(
      key: const Key('planet-mastery-card'),
      portraitTopShift: portraitTopShift,
      title: isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED',
      icon: const Icon(
        Icons.military_tech_rounded,
        color: MiningTheme.highlight,
        size: 28,
      ),
      pinnedFooter: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: _MasteryAction(
              key: isFinal
                  ? const Key('planet-mastery-relaunch')
                  : const Key('planet-mastery-open-map'),
              label: isFinal ? 'RELAUNCH' : 'Open Map',
              emphasized: true,
              onPressed: isFinal ? onRelaunch! : onOpenMap,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _MasteryAction(
              key: const Key('planet-mastery-continue'),
              label: 'Continue',
              emphasized: false,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
      child: _body(
        landscape: landscape,
        compactPortrait: compactPortrait,
        artSize: artSize,
      ),
    );
  }

  Widget _body({
    required bool landscape,
    required bool compactPortrait,
    required Size artSize,
  }) {
    if (isFinal && landscape) {
      // Short landscape cannot stack the summary and the explanation. The
      // status shares the name's line and the reward keeps its caption
      // beside it; sort keys keep the reading order planet, reward, caption,
      // status, explanation instead of the visual packing order.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _art(artSize),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      sortKey: const OrdinalSortKey(1),
                      child: _planetName(
                        textAlign: TextAlign.start,
                        tight: true,
                      ),
                    ),
                    Semantics(
                      sortKey: const OrdinalSortKey(4),
                      child: _runComplete(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: Semantics(
                  sortKey: const OrdinalSortKey(2),
                  child: _reward(textAlign: TextAlign.start),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Semantics(
                  sortKey: const OrdinalSortKey(3),
                  child: _completionReward(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Semantics(sortKey: const OrdinalSortKey(5), child: _explanation()),
        ],
      );
    }
    if (isFinal && compactPortrait) {
      // Portrait has the width for the caption and status on one line; the
      // explanation still spans the body beneath the summary instead of
      // wrapping inside the narrow column beside the art.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _finalSummary(artSize),
          const SizedBox(height: 2),
          _explanation(),
        ],
      );
    }
    // Short landscape has room for a wider composition: the art and
    // milestone summary share a row, and the complete gates sit in one
    // wrapping row underneath instead of a tall stacked column.
    if (landscape && !isFinal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _art(const Size(96, 96)),
              const SizedBox(width: 12),
              Expanded(child: _details(compact: true, includeGates: false)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 2,
            children: [
              for (final (index, requirement) in requirements.indexed)
                _MasteryRequirement(
                  key: Key('planet-mastery-requirement-$index'),
                  requirement: requirement,
                  compact: true,
                  intrinsicWidth: true,
                ),
            ],
          ),
        ],
      );
    }
    if (landscape || compactPortrait) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _art(artSize),
          const SizedBox(width: 12),
          Expanded(child: _details(compact: true)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _art(artSize)),
        const SizedBox(height: 8),
        _details(compact: false),
      ],
    );
  }

  /// The short final card's compact summary. The art shares the name's line so
  /// every line above the explanation stays at its natural height. The caption
  /// and status share a run where the column is wide enough.
  Widget _finalSummary(Size artSize) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _art(artSize),
          const SizedBox(width: 8),
          Expanded(child: _planetName(textAlign: TextAlign.start, tight: true)),
        ],
      ),
      const SizedBox(height: 2),
      _reward(textAlign: TextAlign.start),
      const SizedBox(height: 2),
      Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [_completionReward(), _runComplete()],
      ),
    ],
  );

  /// [tight] trims the inherited 1.4 leading so a short card's single-line
  /// name stays inside the first-frame body budget.
  Widget _planetName({required TextAlign textAlign, bool tight = false}) =>
      Text(
        masteredPlanet.name,
        key: const Key('planet-mastery-planet'),
        textAlign: textAlign,
        style: TextStyle(
          color: MiningTheme.highlight,
          fontFamily: 'Orbitron',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: tight ? 1.1 : null,
        ),
      );

  Widget _reward({TextAlign textAlign = TextAlign.center}) => Text(
    '+${formatMiningCash(rewardCash ?? 0)} cash',
    key: const Key('planet-mastery-reward'),
    textAlign: textAlign,
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

  Widget _details({required bool compact, bool includeGates = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _planetName(textAlign: TextAlign.center),
      if (isFinal) ...[
        const SizedBox(height: 4),
        _reward(),
        const SizedBox(height: 2),
        _completionReward(),
        SizedBox(height: compact ? 10 : 16),
        _runComplete(),
        const SizedBox(height: 4),
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
        SizedBox(height: compact ? 2 : 16),
        Text(
          '${successorName ?? 'The next frontier'} is next',
          key: const Key('planet-mastery-successor'),
          style: const TextStyle(
            color: MiningTheme.accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        if (includeGates) ...[
          const SizedBox(height: 6),
          for (final (index, requirement) in requirements.indexed)
            _MasteryRequirement(
              key: Key('planet-mastery-requirement-$index'),
              requirement: requirement,
              compact: compact,
            ),
        ],
      ],
    ],
  );
}

class _MasteryRequirement extends StatelessWidget {
  const _MasteryRequirement({
    super.key,
    required this.requirement,
    this.compact = false,
    this.intrinsicWidth = false,
  });

  final StellarMapRequirementView requirement;

  /// Tightens the padding for the compact card.
  final bool compact;

  /// The landscape gate Wrap sizes rows to their text so gates can share a
  /// run; every other layout keeps the text flexible and wrapping.
  final bool intrinsicWidth;

  @override
  Widget build(BuildContext context) {
    final color = requirement.isSatisfied
        ? MiningTheme.accent
        : MiningTheme.gate;
    final label = Text(
      requirement.label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    );
    return Semantics(
      label:
          '${requirement.label}, '
          '${requirement.isSatisfied ? 'satisfied' : 'required'}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : 3),
        child: Row(
          mainAxisSize: intrinsicWidth ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(
              requirement.isSatisfied ? Icons.check : Icons.close,
              color: color,
              size: 16,
            ),
            SizedBox(width: compact ? 6 : 8),
            if (intrinsicWidth) label else Expanded(child: label),
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
    const textStyle = TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );
    if (!emphasized) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape: const StadiumBorder(),
          textStyle: textStyle,
        ),
        child: Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: MiningTheme.highlight,
        foregroundColor: const Color(0xFF04121A),
        shape: const StadiumBorder(),
        textStyle: textStyle,
      ),
      child: Text(label),
    );
  }
}
