import 'package:flutter/material.dart';
import '../game/quests/quest.dart';
import '../game/quests/quest_manager.dart';
import '../game/achievements/achievement_manager.dart';
import '../widgets/cards/quest_card.dart';
import '../widgets/cards/achievement_card.dart';

class QuestLogPage extends StatefulWidget {
  final QuestManager questManager;
  final AchievementManager achievementManager;
  final void Function(Quest quest)? onClaimReward;

  const QuestLogPage({
    super.key,
    required this.questManager,
    required this.achievementManager,
    this.onClaimReward,
  });

  @override
  State<QuestLogPage> createState() => _QuestLogPageState();
}

class _QuestLogPageState extends State<QuestLogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Quest Log', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Achievements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveQuests(),
          _buildCompletedQuests(),
          _buildAchievements(),
        ],
      ),
    );
  }

  Widget _buildActiveQuests() {
    final allActive = widget.questManager.quests
        .where(
          (q) =>
              q.status == QuestStatus.active ||
              q.status == QuestStatus.completed ||
              q.status == QuestStatus.available,
        )
        .toList();

    // Separate into story, daily, weekly
    final story = allActive
        .where((q) => !q.id.startsWith('daily_') && !q.id.startsWith('weekly_'))
        .toList();
    final daily = allActive.where((q) => q.id.startsWith('daily_')).toList();
    final weekly = allActive.where((q) => q.id.startsWith('weekly_')).toList();

    if (allActive.isEmpty) {
      return const Center(
        child: Text(
          'No active quests',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (story.isNotEmpty) ...[
          _sectionHeader('Story Quests'),
          ...story.map(_buildQuestCard),
        ],
        if (daily.isNotEmpty) ...[
          _sectionHeader('Daily Quests'),
          ...daily.map(_buildQuestCard),
        ],
        if (weekly.isNotEmpty) ...[
          _sectionHeader('Weekly Quests'),
          ...weekly.map(_buildQuestCard),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuestCard(Quest quest) {
    return QuestCard(
      quest: quest,
      onClaim: quest.status == QuestStatus.completed
          ? () {
              widget.onClaimReward?.call(quest);
              setState(() {});
            }
          : null,
    );
  }

  Widget _buildCompletedQuests() {
    final quests = widget.questManager.quests
        .where((q) => q.status == QuestStatus.claimed)
        .toList();

    if (quests.isEmpty) {
      return const Center(
        child: Text(
          'No completed quests yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) => QuestCard(quest: quests[index]),
    );
  }

  Widget _buildAchievements() {
    final achievements = widget.achievementManager.achievements;

    if (achievements.isEmpty) {
      return const Center(
        child: Text('No achievements', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) =>
          AchievementCard(achievement: achievements[index]),
    );
  }
}
