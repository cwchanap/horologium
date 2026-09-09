import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class OfflineReturnSheet extends StatelessWidget {
  const OfflineReturnSheet({
    super.key,
    required this.summary,
    required this.content,
    this.logisticsLevel,
    this.cash = 0,
  });

  final OfflineProductionSummary summary;
  final MiningContentRegistry content;
  final int? logisticsLevel;
  final int cash;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('offline-return-sheet'),
    color: const Color(0xFF060A10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final pad = MediaQuery.paddingOf(context);
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: landscape ? constraints.maxHeight : 400,
              child: Image.asset(
                MiningVisuals.offlineHero,
                key: const Key('offline-return-hero'),
                fit: BoxFit.cover,
                alignment: landscape
                    ? const Alignment(-.24, -.08)
                    : const Alignment(.12, -.08),
                semanticLabel: 'Mining fleet returning from offline work',
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: MiningTheme.hudPanel),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: landscape
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: landscape
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: landscape
                        ? const [
                            Color(0xB8060A10),
                            Color(0x2E060A10),
                            Color(0x99060A10),
                            Color(0xE6060A10),
                          ]
                        : const [
                            Color(0x80060A10),
                            Color(0x1A060A10),
                            Color(0xDB060A10),
                            Color(0xFF060A10),
                            Color(0xFF060A10),
                          ],
                    stops: landscape
                        ? const [0, .2, .4, .56]
                        : [
                            0,
                            (160 / constraints.maxHeight).clamp(0, 1),
                            (328 / constraints.maxHeight).clamp(0, 1),
                            (400 / constraints.maxHeight).clamp(0, 1),
                            1,
                          ],
                  ),
                ),
              ),
            ),
            if (landscape) ...[
              Positioned(
                left: 16 + pad.left,
                bottom: 20 + pad.bottom,
                width: constraints.maxWidth * .46 - 32 - pad.left,
                child: _summaryHeading(compact: true),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: constraints.maxWidth * 470 / 874,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    52 + pad.top,
                    16 + pad.right,
                    16 + pad.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xF50E1828),
                    border: Border(left: BorderSide(color: Color(0x6653D4E8))),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: _reports(framed: false),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _continueAction(context),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    (constraints.maxHeight * .286).clamp(140, 250) + pad.top,
                    14,
                    180 + pad.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryHeading(compact: false),
                      const SizedBox(height: 46),
                      _reports(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 0,
                height: 152 + pad.bottom,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00060A10), Color(0xFF060A10)],
                      stops: [0, .28],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32 + pad.bottom),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Next: sell cargo, or fill a free cell.',
                            key: Key('offline-return-next-action'),
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _continueAction(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              top: (landscape ? 52 : 54) + pad.top,
              left: pad.left,
              child: MiningCashChip(cash: cash, compact: landscape),
            ),
          ],
        );
      },
    ),
  );

  Widget _summaryHeading({required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xCC060A10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MiningTheme.highlight.withAlpha(128)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: MiningTheme.highlight),
            SizedBox(width: 9),
            Text(
              'FLEET RETURNED',
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: MiningTheme.highlight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Mining ran\n${_formatDuration(summary.elapsedUsed)}',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 26 : 30,
          height: 1.08,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (summary.wasOfflineCapped) ...[
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              MiningVisuals.logisticsIcon,
              width: 17,
              height: 17,
              errorBuilder: (_, _, _) => const Icon(
                Icons.inventory_2,
                size: 17,
                color: MiningTheme.gate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Capped at ${_formatDuration(summary.elapsedUsed)}${logisticsLevel == null ? '' : ' — Logistics LV $logisticsLevel'}',
                key: const Key('offline-return-cap'),
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: MiningTheme.gate,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _continueAction(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 52
              : 56,
          child: OutlinedButton(
            key: const Key('offline-return-dismiss'),
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: MiningTheme.highlight,
              backgroundColor: MiningTheme.highlight.withAlpha(36),
              side: const BorderSide(color: MiningTheme.highlight, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'CONTINUE MINING',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: MediaQuery.orientationOf(context) == Orientation.landscape
            ? 52
            : 56,
        height: MediaQuery.orientationOf(context) == Orientation.landscape
            ? 58
            : 62,
        child: MiningHex(
          fill: MiningTheme.highlight,
          border: MiningTheme.highlight,
          semanticLabel: 'Continue mining',
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.play_arrow,
            size: 28,
            color: Color(0xFF04121A),
          ),
        ),
      ),
    ],
  );

  Widget _reports({bool framed = true}) => Column(
    children: [
      for (final entry in summary.productionByPlanet.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _planetSection(entry.key, entry.value, framed: framed),
        ),
    ],
  );

  Widget _planetSection(
    MiningPlanetId id,
    Map<ResourceType, double> production, {
    required bool framed,
  }) {
    final planet = content.planet(id);
    return Container(
      key: Key('offline-return-planet-${id.name}'),
      padding: framed ? const EdgeInsets.all(14) : EdgeInsets.zero,
      decoration: framed
          ? BoxDecoration(
              color: const Color(0xE60E1828),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MiningTheme.accent.withAlpha(72)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                planet.planetAsset,
                width: 30,
                height: 30,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.public, color: MiningTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  planet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${planet.sites.length} SITES',
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in production.entries.where(
            (entry) => entry.value > 0,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  _resourceIcon(entry.key),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      MiningContentRegistry
                          .resourceSilhouettes[entry.key]!
                          .name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${entry.value.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: MiningTheme.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          for (final site in planet.sites.where(
            (site) => summary.fullSites.contains(site.id),
          ))
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: MiningTheme.gate.withAlpha(26),
                border: Border.all(color: MiningTheme.gate.withAlpha(102)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2,
                    size: 17,
                    color: MiningTheme.gate,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Storage full: ${site.name}.',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: MiningTheme.gate,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resourceIcon(ResourceType resource) {
    final silhouette = MiningContentRegistry.resourceSilhouettes[resource]!;
    final icon = Icon(silhouette.icon, color: silhouette.color, size: 26);
    final site = switch (resource) {
      ResourceType.gold => MiningSiteId.landingBasin,
      ResourceType.coal => MiningSiteId.carbonRidge,
      ResourceType.stone => MiningSiteId.graniteCrater,
      ResourceType.waterIce ||
      ResourceType.titaniumOre ||
      ResourceType.helium3 ||
      ResourceType.ironOre ||
      ResourceType.silica ||
      ResourceType.cobaltOre => null,
    };
    return SizedBox(
      key: Key('offline-resource-${resource.name}'),
      width: 26,
      height: 26,
      child: site == null
          ? icon
          : Image.asset(
              content.site(site).depositAsset,
              errorBuilder: (_, _, _) => icon,
            ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}
