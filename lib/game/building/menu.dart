import 'package:flutter/material.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

class BuildingMenu {
  static void showBuildingDetailsDialog({
    required BuildContext context,
    required int x,
    required int y,
    required Building building,
    required Resources resources,
    required VoidCallback onResourcesChanged,
    required VoidCallback onBuildingUpgraded,
    required VoidCallback onBuildingDeleted,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool meetsConsumptionRequirements = true;
            if (building.consumption.isNotEmpty) {
              building.consumption.forEach((key, value) {
                if ((resources.resources[key] ?? 0) < value) {
                  meetsConsumptionRequirements = false;
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  _buildBuildingImage(building, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          building.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Level ${building.level}/${building.maxLevel}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Cost
                    _buildDetailRow('Cost', '${building.cost} cash', Colors.green),

                    // Population
                    if (building.accommodationCapacity > 0)
                      _buildDetailRow(
                          'Accommodation', '${building.accommodationCapacity}', Colors.blue),
                    if (building.requiredWorkers > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Workers',
                              style: TextStyle(fontSize: 14),
                            ),
                            Row(
                              children: [
                                Visibility(
                                  visible: building.assignedWorkers > 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        resources.unassignWorkerFrom(building);
                                        onResourcesChanged();
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                  '${building.assignedWorkers}/${building.requiredWorkers}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: building.hasWorkers ? Colors.green : Colors.red,
                                  ),
                                ),
                                Visibility(
                                  visible: resources.canAssignWorkerTo(building),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: () {
                                      setState(() {
                                        resources.assignWorkerTo(building);
                                        onResourcesChanged();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Generation
                    if (building.generation.isNotEmpty) ...[
                      const Text(
                        'Generation:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      ...building.generation.entries.map((entry) {
                        // Show actual production rate (0 if no workers, except for houses)
                        final isProducing = building.type == BuildingType.house || 
                                          building.type == BuildingType.largeHouse || 
                                          building.hasWorkers;
                        final actualRate = isProducing ? entry.value : 0.0;
                        final color = isProducing ? Colors.green : Colors.grey;
                        return _buildDetailRow(
                            _capitalizeResource(entry.key), '+$actualRate/sec', color);
                      }),
                      const SizedBox(height: 8),
                    ],

                    // Consumption
                    if (building.consumption.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text(
                            'Consumption:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (!meetsConsumptionRequirements)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.warning, color: Colors.red, size: 16),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...building.consumption.entries.map((entry) {
                        final hasEnough = (resources.resources[entry.key] ?? 0) >= entry.value;
                        return _buildDetailRow(
                          _capitalizeResource(entry.key),
                          '-${entry.value}/sec',
                          !hasEnough ? Colors.red : Colors.grey,
                        );
                      }),
                    ],
                    if (building is Field) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Crop Type:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      DropdownButton<CropType>(
                        value: (building as Field).cropType,
                        onChanged: (CropType? newValue) {
                          if (newValue != null) {
                            setState(() {
                              (building as Field).cropType = newValue;
                            });
                          }
                        },
                        items: CropType.values
                            .map<DropdownMenuItem<CropType>>((CropType value) {
                          return DropdownMenuItem<CropType>(
                            value: value,
                            child: Text(value.toString().split('.').last),
                          );
                        }).toList(),
                      ),
                    ],
                    if (building is Bakery) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Product Type:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      DropdownButton<BakeryProduct>(
                        value: (building as Bakery).productType,
                        onChanged: (BakeryProduct? newValue) {
                          if (newValue != null) {
                            setState(() {
                              (building as Bakery).productType = newValue;
                            });
                          }
                        },
                        items: BakeryProduct.values
                            .map<DropdownMenuItem<BakeryProduct>>((BakeryProduct value) {
                          return DropdownMenuItem<BakeryProduct>(
                            value: value,
                            child: Text(value.toString().split('.').last),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (building.canUpgrade)
                  ElevatedButton(
                    onPressed: () {
                      if (resources.cash >= building.upgradeCost) {
                        setState(() {
                          resources.cash -= building.upgradeCost;
                          building.upgrade();
                          onResourcesChanged();
                        });
                        Navigator.of(context).pop();
                        onBuildingUpgraded();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Not enough cash!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: building.color,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Upgrade (${building.upgradeCost})'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalizeResource(String resource) {
    switch (resource) {
      case 'cash':
        return 'Cash';
      case 'electricity':
        return 'Electricity';
      case 'coal':
        return 'Coal';
      case 'water':
        return 'Water';
      case 'wood':
        return 'Wood';
      case 'gold':
        return 'Gold';
      case 'research':
        return 'Research';
      default:
        return resource[0].toUpperCase() + resource.substring(1);
    }
  }

  static Widget _buildBuildingImage(Building building, {double size = 24}) {
    if (building.assetPath != null) {
      return Image.asset(
        'assets/images/${building.assetPath!}',
        width: size,
        height: size,
      );
    } else {
      return Icon(
        building.icon,
        color: building.color,
        size: size,
      );
    }
  }
}
