import 'package:flutter/material.dart';
import '../../game/quests/quest.dart';
import '../../game/quests/quest_objective.dart';
import '../../game/resources/resource_type.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final VoidCallback? onClaim;

  const QuestCard({super.key, required this.quest, this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor.withAlpha((255 * 0.3).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quest.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...quest.objectives.map(_buildObjectiveRow),
          const SizedBox(height: 8),
          _buildRewardRow(),
          if (quest.status == QuestStatus.completed && onClaim != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Claim Reward'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (quest.status) {
      case QuestStatus.completed:
        return Colors.green;
      case QuestStatus.claimed:
        return Colors.grey;
      default:
        return Colors.cyanAccent;
    }
  }

  Widget _buildObjectiveRow(QuestObjective objective) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: objective.progress,
              backgroundColor: Colors.grey.withAlpha((255 * 0.3).round()),
              valueColor: AlwaysStoppedAnimation<Color>(
                objective.isComplete ? Colors.green : Colors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${objective.currentAmount} / ${objective.targetAmount}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRow() {
    final rewards = <Widget>[];
    for (final entry in quest.reward.resources.entries) {
      rewards.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_resourceIcon(entry.key), color: Colors.white70, size: 14),
            const SizedBox(width: 2),
            Text(
              '${entry.value.toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (quest.reward.researchPoints > 0) {
      rewards.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, color: Colors.purple, size: 14),
            const SizedBox(width: 2),
            Text(
              '${quest.reward.researchPoints}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return Wrap(spacing: 12, children: rewards);
  }

  IconData _resourceIcon(ResourceType type) {
    switch (type) {
      case ResourceType.cash:
        return Icons.attach_money;
      case ResourceType.gold:
        return Icons.star;
      case ResourceType.wood:
        return Icons.park;
      case ResourceType.electricity:
        return Icons.bolt;
      case ResourceType.research:
        return Icons.science;
      case ResourceType.water:
        return Icons.water_drop;
      default:
        return Icons.inventory;
    }
  }
}
