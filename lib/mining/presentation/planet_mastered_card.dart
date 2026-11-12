import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    // Landscape panels are always short. Portrait only compacts when large
    // text leaves too little height for the art-led stack to reach the
    // successor. Keep the authored art-led column at normal sizes.
    // shortcut: the 700px breakpoint covers the short-phone large-text target;
    // move to a measured body viewport if more screen classes need it.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactPortrait = !landscape && textScale > 1 && size.height <= 700;
    final artSize = landscape
        ? const Size(104, 104)
        : compactPortrait
        ? const Size(80, 80)
        : const Size(160, 132);
    return MiningSheetFrame(
      key: const Key('planet-mastery-card'),
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
      Text(
        masteredPlanet.name,
        key: const Key('planet-mastery-planet'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MiningTheme.highlight,
          fontFamily: 'Orbitron',
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (isFinal) ...[
        const SizedBox(height: 4),
        Text(
          '+${formatMiningCash(rewardCash ?? 0)} cash',
          key: const Key('planet-mastery-reward'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MiningTheme.warning,
            fontFamily: 'Orbitron',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'completion reward',
          textAlign: TextAlign.center,
          style: TextStyle(color: MiningTheme.secondaryText, fontSize: 11),
        ),
        SizedBox(height: compact ? 10 : 16),
        const Text(
          'RUN COMPLETE',
          style: TextStyle(
            color: MiningTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Relaunch to start again with sales '
          '${formatSaleMultiplier(nextSaleMultiplier)}. '
          'Only your relaunch count is kept.',
          key: const Key('planet-mastery-multiplier'),
          style: const TextStyle(color: MiningTheme.secondaryText, height: 1.4),
        ),
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
  });

  final StellarMapRequirementView requirement;

  /// The horizontal compact gate row sizes itself to its text; the stacked
  /// layout stretches and wraps inside the details column.
  final bool compact;

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
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(
              requirement.isSatisfied ? Icons.check : Icons.close,
              color: color,
              size: 16,
            ),
            SizedBox(width: compact ? 6 : 8),
            if (compact) label else Expanded(child: label),
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
