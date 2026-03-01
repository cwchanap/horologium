import 'package:flutter/material.dart';

import '../../game/quests/quest_manager.dart';
import '../../game/quests/quest.dart';
import '../../game/achievements/achievement_manager.dart';
import '../../game/research/research.dart';
import '../../game/resources/resources.dart';
import '../../game/building/building.dart';
import '../../pages/research_tree_page.dart';
import '../../pages/resources_page.dart';
import '../../pages/trade_page.dart';
import '../../pages/quest_log_page.dart';
import '../../game/grid.dart';
import '../planet_switcher.dart';

class HamburgerMenu extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final Resources resources;
  final ResearchManager researchManager;
  final BuildingLimitManager buildingLimitManager;
  final Grid grid;
  final VoidCallback onResourcesChanged;
  // Quest & achievement managers
  final QuestManager? questManager;
  final AchievementManager? achievementManager;
  final void Function(Quest)? onClaimQuestReward;
  // Audio controls
  final bool musicEnabled;
  final double musicVolume;
  final ValueChanged<bool>? onMusicEnabledChanged;
  final ValueChanged<double>? onMusicVolumeChanged;

  const HamburgerMenu({
    super.key,
    required this.isVisible,
    required this.onClose,
    required this.resources,
    required this.researchManager,
    required this.buildingLimitManager,
    required this.grid,
    required this.onResourcesChanged,
    this.questManager,
    this.achievementManager,
    this.onClaimQuestReward,
    this.musicEnabled = true,
    this.musicVolume = 0.5,
    this.onMusicEnabledChanged,
    this.onMusicVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 80,
      right: 20,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.9).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.science, color: Colors.purple),
              title: const Text(
                'Research Tree',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                onClose();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResearchTreePage(
                      researchManager: researchManager,
                      resources: resources,
                      buildingLimitManager: buildingLimitManager,
                      onResourcesChanged: onResourcesChanged,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.cyan),
              title: const Text(
                'Resources',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                onClose();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ResourcesPage(resources: resources, grid: grid),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.green),
              title: const Text('Trade', style: TextStyle(color: Colors.white)),
              onTap: () {
                onClose();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TradePage(resources: resources),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            if (questManager != null && achievementManager != null) ...[
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.amber),
                title: const Text(
                  'Quests',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: questManager!.hasUnclaimedRewards
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () {
                  onClose();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestLogPage(
                        questManager: questManager!,
                        achievementManager: achievementManager!,
                        onClaimReward: onClaimQuestReward,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.grey, height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.public, color: Colors.blue),
              title: const Text(
                'Planet Selection',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                onClose();
                _showPlanetSwitcher(context);
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            // Audio controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: const [
                  Icon(Icons.music_note, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text(
                'Music',
                style: TextStyle(color: Colors.white70),
              ),
              value: musicEnabled,
              onChanged: onMusicEnabledChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Volume', style: TextStyle(color: Colors.white70)),
                  Text(
                    '${(musicVolume * 100).round()}%',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
            Slider(
              value: musicVolume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(musicVolume * 100).round()}%',
              onChanged: musicEnabled ? onMusicVolumeChanged : null,
            ),
            const Divider(color: Colors.grey, height: 1),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text('Close', style: TextStyle(color: Colors.white)),
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanetSwitcher(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Planet Selection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PlanetSwitcher(
                  onPlanetChanged: () {
                    Navigator.of(context).pop();
                    onResourcesChanged(); // Refresh the UI
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
