import 'package:flutter/material.dart';
import '../game/achievements/achievement.dart';
import '../game/achievements/achievement_manager.dart';
import '../game/quests/quest.dart';
import '../game/quests/quest_manager.dart';
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

  // Callback references for cleanup
  void Function(Quest, QuestStatus, QuestStatus)? _questStatusCallback;
  void Function(Achievement)? _achievementUnlockedCallback;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupListeners();
  }

  @override
  void didUpdateWidget(covariant QuestLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-setup listeners if the managers change
    if (oldWidget.questManager != widget.questManager ||
        oldWidget.achievementManager != widget.achievementManager) {
      _removeListeners(oldWidget);
      _setupListeners();
    }
  }

  void _setupListeners() {
    // Listen for quest status changes (activation, completion, claiming)
    _questStatusCallback = (quest, oldStatus, newStatus) {
      if (mounted) setState(() {});
    };
    widget.questManager.onQuestStatusChanged = _questStatusCallback;

    // Also listen for quest completion and availability notifications
    widget.questManager.onQuestCompleted = (quest) {
      if (mounted) setState(() {});
    };
    widget.questManager.onQuestAvailable = (quest) {
      if (mounted) setState(() {});
    };

    // Listen for achievement unlocks
    _achievementUnlockedCallback = (achievement) {
      if (mounted) setState(() {});
    };
    widget.achievementManager.onAchievementUnlocked =
        _achievementUnlockedCallback;
  }

  void _removeListeners([QuestLogPage? oldWidget]) {
    final qm = oldWidget?.questManager ?? widget.questManager;
    final am = oldWidget?.achievementManager ?? widget.achievementManager;

    // Remove our specific callbacks if they match
    if (qm.onQuestStatusChanged == _questStatusCallback) {
      qm.onQuestStatusChanged = null;
    }
    // Note: onQuestCompleted and onQuestAvailable are replaced, not appended,
    // so we just set them to null to clear
    qm.onQuestCompleted = null;
    qm.onQuestAvailable = null;

    if (am.onAchievementUnlocked == _achievementUnlockedCallback) {
      am.onAchievementUnlocked = null;
    }
  }

  @override
  void dispose() {
    _removeListeners();
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
            Tab(text: 'Claimed'),
            Tab(text: 'Achievements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveQuests(),
          _buildClaimedQuests(),
          _buildAchievements(),
        ],
      ),
    );
  }

  Widget _buildActiveQuests() {
    // Use getAvailableQuests() to exclude prerequisite-locked quests
    // Combine with active and completed quests for the full Active tab view
    final available = widget.questManager.getAvailableQuests();
    final active = widget.questManager.getActiveQuests();
    final completed = widget.questManager.getCompletedQuests();

    // Merge and deduplicate by quest ID
    final allActive = <String, Quest>{};
    for (final q in [...available, ...active, ...completed]) {
      allActive[q.id] = q;
    }
    final questList = allActive.values.toList();

    // Separate into story, daily, weekly
    final story = questList
        .where((q) => !q.id.startsWith('daily_') && !q.id.startsWith('weekly_'))
        .toList();
    final daily = questList.where((q) => q.id.startsWith('daily_')).toList();
    final weekly = questList.where((q) => q.id.startsWith('weekly_')).toList();

    if (questList.isEmpty) {
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
      onClaim:
          quest.status == QuestStatus.completed && widget.onClaimReward != null
          ? () {
              widget.onClaimReward!(quest);
              setState(() {});
            }
          : null,
    );
  }

  Widget _buildClaimedQuests() {
    final quests = widget.questManager.quests
        .where((q) => q.status == QuestStatus.claimed)
        .toList();

    if (quests.isEmpty) {
      return const Center(
        child: Text(
          'No claimed quests yet',
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
