import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class OfflineReturnSheet extends StatelessWidget {
  const OfflineReturnSheet({
    super.key,
    required this.summary,
    required this.content,
  });

  final OfflineProductionSummary summary;
  final MiningContentRegistry content;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        key: const Key('offline-return-sheet'),
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
                'Offline return',
                style: TextStyle(
                  color: MiningTheme.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  MiningVisuals.offlineHero,
                  key: const Key('offline-return-hero'),
                  width: double.infinity,
                  height: 128,
                  fit: BoxFit.cover,
                  semanticLabel: 'Mining fleet returning from offline work',
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 128,
                    child: ColoredBox(
                      color: MiningTheme.hudPanel,
                      child: Center(
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: MiningTheme.accent,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mining continued for ${_formatDuration(summary.elapsedUsed)}.',
                style: const TextStyle(color: Colors.white70),
              ),
              for (final planetEntry in summary.productionByPlanet.entries)
                _planetSection(planetEntry.key, planetEntry.value),
              if (summary.wasOfflineCapped) ...[
                const SizedBox(height: 8),
                Text(
                  'Offline production was capped at '
                  '${_formatDuration(summary.elapsedUsed)}.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Next: sell cargo or upgrade a mine to keep the operation moving.',
                key: Key('offline-return-next-action'),
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('offline-return-dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('CONTINUE MINING'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One section per producing planet. The flat [OfflineProductionSummary
  /// .fullSites] set resolves to per-planet names by filtering the catalog.
  Widget _planetSection(
    MiningPlanetId planetId,
    Map<ResourceType, double> production,
  ) {
    final planet = content.planet(planetId);
    final fullSiteNames = planet.sites
        .map((definition) => definition.id)
        .where(summary.fullSites.contains)
        .map((id) => content.site(id).name);

    return Container(
      key: Key('offline-return-planet-${planetId.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planet.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in production.entries.where(
            (entry) => entry.value > 0,
          ))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    MiningContentRegistry.resourceSilhouettes[entry.key]!.icon,
                    size: 14,
                    color: MiningContentRegistry
                        .resourceSilhouettes[entry.key]!
                        .color,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      MiningContentRegistry
                          .resourceSilhouettes[entry.key]!
                          .name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '+${entry.value.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          for (final name in fullSiteNames)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Storage full: $name.',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
