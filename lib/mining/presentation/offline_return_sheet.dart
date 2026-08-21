import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';

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
    final production = summary.produced.entries
        .where((entry) => entry.value > 0)
        .toList();

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
                  color: Colors.cyanAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mining continued for ${_formatDuration(summary.elapsedUsed)}.',
                style: const TextStyle(color: Colors.white70),
              ),
              if (production.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Cargo added',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final entry in production)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _resourceColor(entry.key),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _resourceName(entry.key),
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
              ],
              if (summary.fullSectors.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final id
                    in content.sectors
                        .map((definition) => definition.id)
                        .where(summary.fullSectors.contains))
                  Text(
                    'Storage full: ${content.sector(id).name}.',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
              ],
              if (summary.wasOfflineCapped) ...[
                const SizedBox(height: 8),
                const Text(
                  'Offline production was capped at 8 hours.',
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

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  static String _resourceName(ResourceType type) {
    switch (type) {
      case ResourceType.gold:
        return 'Gold';
      case ResourceType.coal:
        return 'Coal';
      case ResourceType.stone:
        return 'Stone';
    }
  }

  static Color _resourceColor(ResourceType type) {
    switch (type) {
      case ResourceType.gold:
        return Colors.amberAccent;
      case ResourceType.coal:
        return Colors.blueGrey;
      case ResourceType.stone:
        return Colors.grey;
    }
  }
}
