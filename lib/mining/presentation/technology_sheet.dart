import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// Render surface for [TechnologySheetView]. It renders the pre-computed
/// affordances and forwards purchase taps; it never calculates eligibility.
class TechnologySheet extends StatelessWidget {
  const TechnologySheet({
    super.key,
    required this.view,
    required this.onPurchase,
  });

  final TechnologySheetView view;
  final ValueChanged<TechnologyTrack> onPurchase;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: Material(
          key: const Key('mining-technology-sheet'),
          color: const Color(0xF20E1828),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withAlpha(180),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Technology',
                  style: TextStyle(
                    color: MiningTheme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upgrade the operation. Each level needs its gate mine and '
                  'cash.',
                  style: TextStyle(color: MiningTheme.secondaryText),
                ),
                const SizedBox(height: 10),
                for (final track in view.tracks)
                  _TechnologyTrackRow(track: track, onPurchase: onPurchase),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechnologyTrackRow extends StatelessWidget {
  const _TechnologyTrackRow({required this.track, required this.onPurchase});

  final TechnologyTrackView track;
  final ValueChanged<TechnologyTrack> onPurchase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${track.name} · Level ${track.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (track.cost != null)
                Text(
                  '${track.cost} cash',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            track.currentEffect,
            style: const TextStyle(
              color: MiningTheme.secondaryText,
              fontSize: 13,
            ),
          ),
          if (track.nextEffect != null)
            Text(
              'Next: ${track.nextEffect}',
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 13,
              ),
            ),
          if (track.gateSiteName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    track.isGateSatisfied
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: track.isGateSatisfied
                        ? MiningTheme.accent
                        : MiningTheme.warning,
                    size: 16,
                    semanticLabel: track.isGateSatisfied
                        ? 'Gate satisfied'
                        : 'Gate required',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Gate: ${track.gateSiteName} commissioned',
                      style: const TextStyle(
                        color: MiningTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!track.canPurchase && track.disabledReason != null) ...[
            const SizedBox(height: 4),
            Text(
              track.disabledReason!,
              style: const TextStyle(color: MiningTheme.warning, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            key: Key('mining-technology-buy-${track.track.name}'),
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: track.canPurchase
                  ? () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) navigator.pop();
                      onPurchase(track.track);
                    }
                  : null,
              child: Text(
                track.isMaxLevel
                    ? 'Max Level'
                    : 'Upgrade for ${track.cost} cash',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
