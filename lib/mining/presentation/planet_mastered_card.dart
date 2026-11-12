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
    required this.onContinue,
    required this.onOpenMap,
    this.isFinal = false,
    this.rewardCash,
    this.onRelaunch,
  });

  final MiningPlanetDefinition masteredPlanet;
  final String? successorName;
  final List<StellarMapRequirementView> requirements;
  final bool isFinal;
  final int? rewardCash;
  final VoidCallback onContinue;
  final VoidCallback onOpenMap;
  final VoidCallback? onRelaunch;

  @override
  Widget build(BuildContext context) {
    return MiningSheetFrame(
      key: const Key('planet-mastery-card'),
      title: isFinal ? 'FINAL PLANET MASTERED' : 'PLANET MASTERED',
      icon: const Icon(
        Icons.military_tech_rounded,
        color: MiningTheme.highlight,
        size: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(
              masteredPlanet.planetAsset,
              key: const Key('planet-mastery-art'),
              height: 88,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 88,
                child: Icon(
                  Icons.public_rounded,
                  color: Colors.white24,
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            masteredPlanet.name,
            key: const Key('planet-mastery-planet'),
            style: const TextStyle(
              color: MiningTheme.highlight,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (isFinal) ...[
            Text(
              '+${formatMiningCash(rewardCash ?? 0)} cash',
              key: const Key('planet-mastery-reward'),
              style: const TextStyle(
                color: MiningTheme.warning,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mastery reward credited. Relaunch to begin the next run.',
              style: TextStyle(color: MiningTheme.secondaryText),
            ),
          ] else ...[
            Text(
              '${successorName ?? 'The next frontier'} is next',
              key: const Key('planet-mastery-successor'),
              style: const TextStyle(
                color: MiningTheme.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final (index, requirement) in requirements.indexed)
              _MasteryRequirement(
                key: Key('planet-mastery-requirement-$index'),
                requirement: requirement,
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MasteryAction(
                  key: const Key('planet-mastery-continue'),
                  label: 'Continue',
                  emphasized: false,
                  onPressed: onContinue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MasteryAction(
                  key: isFinal
                      ? const Key('planet-mastery-relaunch')
                      : const Key('planet-mastery-open-map'),
                  label: isFinal ? 'RELAUNCH' : 'Open Map',
                  emphasized: true,
                  onPressed: isFinal ? onRelaunch! : onOpenMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasteryRequirement extends StatelessWidget {
  const _MasteryRequirement({super.key, required this.requirement});

  final StellarMapRequirementView requirement;

  @override
  Widget build(BuildContext context) {
    final color = requirement.isSatisfied
        ? MiningTheme.accent
        : MiningTheme.gate;
    return Semantics(
      label:
          '${requirement.label}, '
          '${requirement.isSatisfied ? 'satisfied' : 'required'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              requirement.isSatisfied ? Icons.check : Icons.close,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                requirement.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
    final foreground = emphasized ? MiningTheme.highlight : Colors.white70;
    final textStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    if (!emphasized) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: foreground,
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
        foregroundColor: foreground,
        side: BorderSide(color: MiningTheme.highlight.withAlpha(160)),
        shape: const StadiumBorder(),
        textStyle: textStyle,
      ),
      child: Text(label),
    );
  }
}
