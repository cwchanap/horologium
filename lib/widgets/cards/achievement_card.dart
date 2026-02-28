import 'package:flutter/material.dart';
import '../../game/achievements/achievement.dart';

class AchievementCard extends StatefulWidget {
  final Achievement achievement;

  const AchievementCard({super.key, required this.achievement});

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ach = widget.achievement;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.withAlpha((255 * 0.8).round())
              : Colors.grey.withAlpha((255 * 0.1).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ach.isUnlocked
                ? Colors.cyanAccent.withAlpha((255 * 0.5).round())
                : Colors.grey.withAlpha((255 * 0.3).round()),
            width: 1,
          ),
          boxShadow: ach.isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.25),
                    spreadRadius: 1,
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ach.isUnlocked ? Icons.check_circle : Icons.lock,
                  color: ach.isUnlocked ? Colors.cyanAccent : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ach.name,
                    style: TextStyle(
                      color: ach.isUnlocked ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!ach.isUnlocked)
                  Text(
                    '${ach.currentAmount} / ${ach.targetAmount}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
            if (!ach.isUnlocked) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ach.progress,
                backgroundColor: Colors.grey.withAlpha((255 * 0.3).round()),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                ach.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
