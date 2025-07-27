import 'package:flutter/material.dart';
import '../game/research.dart';
import '../game/resources/resources.dart';
import '../game/building/building.dart';

class ResearchTreePage extends StatefulWidget {
  final ResearchManager researchManager;
  final Resources resources;
  final Function() onResourcesChanged;
  final BuildingLimitManager? buildingLimitManager;

  const ResearchTreePage({
    super.key,
    required this.researchManager,
    required this.resources,
    required this.onResourcesChanged,
    this.buildingLimitManager,
  });

  @override
  State<ResearchTreePage> createState() => _ResearchTreePageState();
}

class _ResearchTreePageState extends State<ResearchTreePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Research Tree',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.purple.withAlpha((255 * 0.8).round()),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.science, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${widget.resources.research.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Research',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock new technologies and buildings by spending research points.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: Research.availableResearch.length,
                itemBuilder: (context, index) {
                  final research = Research.availableResearch[index];
                  return _buildResearchCard(research);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearchCard(Research research) {
    final isCompleted = widget.researchManager.isResearched(research.id);
    final canResearch = widget.researchManager.canResearch(research);
    final hasEnoughResources = widget.resources.research >= research.cost;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCompleted 
            ? Colors.green.withAlpha((255 * 0.15).round())
            : Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
              ? Colors.green
              : research.color,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isCompleted ? Colors.green : research.color).withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : research.icon,
                  color: isCompleted ? Colors.green : research.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      research.name,
                      style: TextStyle(
                        color: isCompleted ? Colors.green : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      research.description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompleted)
                ElevatedButton(
                  onPressed: (canResearch && hasEnoughResources) ? () {
                    setState(() {
                      widget.resources.research -= research.cost;
                      widget.researchManager.completeResearch(research.id);
                      
                      // Handle building limit upgrades
                      if (widget.buildingLimitManager != null) {
                        if (research.id == 'expansion_planning') {
                          // Increase all building limits by 2
                          for (final buildingType in BuildingType.values) {
                            widget.buildingLimitManager!.increaseBuildingLimit(buildingType, 2);
                          }
                        } else if (research.id == 'advanced_construction') {
                          // Increase all building limits by 3
                          for (final buildingType in BuildingType.values) {
                            widget.buildingLimitManager!.increaseBuildingLimit(buildingType, 3);
                          }
                        }
                      }
                      
                      widget.onResourcesChanged();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Research completed: ${research.name}'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: research.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    canResearch && hasEnoughResources 
                        ? 'Research'
                        : !hasEnoughResources 
                            ? 'Not Enough'
                            : 'Locked',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((255 * 0.2).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Cost and unlocks info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha((255 * 0.3).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science, color: Colors.purple, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${research.cost}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (research.unlocksBuildings.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((255 * 0.3).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.build, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Unlocks ${research.unlocksBuildings.length} building${research.unlocksBuildings.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}