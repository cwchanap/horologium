import 'package:flutter/material.dart';

class MiningStatusBar extends StatelessWidget {
  const MiningStatusBar({
    super.key,
    required this.planetName,
    required this.cash,
    required this.revealedSectors,
    required this.totalSectors,
    required this.cargoValue,
  });

  final String planetName;
  final int cash;
  final int revealedSectors;
  final int totalSectors;
  final int cargoValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mining-status-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6162133),
        border: Border.all(color: Colors.cyanAccent.withAlpha(150)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Metric(label: planetName, value: '$revealedSectors/$totalSectors'),
          _Metric(label: 'CASH', value: '$cash'),
          _Metric(label: 'CARGO VALUE', value: '$cargoValue'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
