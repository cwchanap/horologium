import 'package:flutter/material.dart';

import '../../game/building/building.dart';
import '../../game/building/category.dart';
import '../../game/research/research.dart';
import '../../game/services/building_service.dart';
import '../../game/grid.dart';
import '../cards/building_card.dart';

class BuildingSelectionPanel extends StatefulWidget {
  final bool isVisible;
  final int? selectedGridX;
  final int? selectedGridY;
  final VoidCallback onClose;
  final Function(Building) onBuildingSelected;
  final ResearchManager researchManager;
  final BuildingLimitManager buildingLimitManager;
  final Grid grid;

  const BuildingSelectionPanel({
    super.key,
    required this.isVisible,
    required this.selectedGridX,
    required this.selectedGridY,
    required this.onClose,
    required this.onBuildingSelected,
    required this.researchManager,
    required this.buildingLimitManager,
    required this.grid,
  });

  @override
  State<BuildingSelectionPanel> createState() => _BuildingSelectionPanelState();
}

class _BuildingSelectionPanelState extends State<BuildingSelectionPanel>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: BuildingCategory.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height:
            MediaQuery.of(context).size.height * 0.5, // 50% of screen height
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.9).round()),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.cyanAccent, width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Building (${widget.selectedGridX}, ${widget.selectedGridY})',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: BuildingCategory.values
                  .map(
                    (category) =>
                        Tab(text: category.toString().split('.').last),
                  )
                  .toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: BuildingCategory.values.map((category) {
                  final buildings = BuildingService.getAvailableBuildings(
                    widget.researchManager,
                  ).where((b) => b.category == category).toList();
                  if (buildings.isEmpty) {
                    return const Center(
                      child: Text(
                        'No buildings in this category',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: buildings.length,
                    itemBuilder: (context, index) {
                      final building = buildings[index];
                      return BuildingCard(
                        building: building,
                        onTap: () => widget.onBuildingSelected(building),
                        currentCount: widget.grid.countBuildingsOfType(
                          building.type,
                        ),
                        maxCount: widget.buildingLimitManager.getBuildingLimit(
                          building.type,
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
