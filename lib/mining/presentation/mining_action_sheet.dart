import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_sheet_view.dart';

class MiningActionSheet extends StatelessWidget {
  const MiningActionSheet({
    super.key,
    required this.view,
    required this.onPrimaryAction,
  });

  final MiningSheetView view;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20E1828),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.title,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  view.body,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (!view.primaryEnabled && view.disabledReason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    view.disabledReason!,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  key: const Key('mining-primary-action'),
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: view.primaryEnabled ? onPrimaryAction : null,
                    child: Text(
                      view.primaryLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
