import 'package:flutter/material.dart';

import '../../game/research/research.dart';
import '../../game/resources/resources.dart';
import '../../game/building/building.dart';
import '../../pages/research_tree_page.dart';
import '../../pages/resources_page.dart';
import '../../pages/trade_page.dart';
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

  const HamburgerMenu({
    super.key,
    required this.isVisible,
    required this.onClose,
    required this.resources,
    required this.researchManager,
    required this.buildingLimitManager,
    required this.grid,
    required this.onResourcesChanged,
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
                    builder: (context) => ResourcesPage(
                      resources: resources,
                      grid: grid,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.green),
              title: const Text(
                'Trade',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                onClose();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TradePage(
                      resources: resources,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 1),
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
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
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