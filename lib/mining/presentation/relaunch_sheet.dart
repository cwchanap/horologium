import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// Relaunch confirmation: what the reset discards, what carries over, and
/// the sale multiplier the next run starts with.
class RelaunchSheet extends StatelessWidget {
  const RelaunchSheet({
    super.key,
    required this.relaunchCount,
    required this.onConfirm,
  });

  final int relaunchCount;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return MiningSheetFrame(
      key: const Key('mining-relaunch-sheet'),
      title: 'Relaunch',
      icon: const Icon(
        Icons.restart_alt_rounded,
        color: MiningTheme.highlight,
        size: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _itemList('RESETS', const [
            'Cash',
            'Technology',
            'Rigs',
            'Planets',
            'Cargo',
          ], keep: false),
          const SizedBox(height: 14),
          _itemList('STAYS', const [
            'Relaunch count',
            'Sale multiplier',
          ], keep: true),
          const SizedBox(height: 16),
          Text(
            'NEXT SALES '
            '${formatSaleMultiplier(MiningContentRegistry.saleMultiplier(relaunchCount + 1))}',
            style: const TextStyle(
              color: MiningTheme.highlight,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('relaunch-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('relaunch-confirm'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: MiningTheme.highlight,
                    side: BorderSide(
                      color: MiningTheme.highlight.withAlpha(160),
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Relaunch'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemList(String heading, List<String> items, {required bool keep}) {
    final color = keep ? MiningTheme.accent : Colors.white38;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  keep ? Icons.check_rounded : Icons.close_rounded,
                  color: color,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(item, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
      ],
    );
  }
}
