import 'dart:async';
import 'package:flutter/material.dart';
import '../game/resources/resources.dart';
import '../game/resources/resource_type.dart';
import '../game/resources/resource_category.dart';
import '../game/building/building.dart';
import '../game/grid.dart';
import '../widgets/cards/cards.dart';

/// Immutable data class for resource information
class _ResourceData {
  final String name;
  final double amount;
  final Color color;
  final ResourceType resourceType;

  const _ResourceData({
    required this.name,
    required this.amount,
    required this.color,
    required this.resourceType,
  });
}

class ResourcesPage extends StatefulWidget {
  final Resources resources;
  final Grid grid;

  const ResourcesPage({super.key, required this.resources, required this.grid});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  Map<ResourceType, double> _productionRates = {};
  Map<ResourceType, double> _consumptionRates = {};
  Timer? _updateTimer;
  ResourceCategory _selectedCategory = ResourceCategory.rawMaterials;

  @override
  void initState() {
    super.initState();
    _calculateRates();
    _startResourceUpdates();
  }

  void _startResourceUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRates();
    });
  }

  void _calculateRates() {
    final buildings = widget.grid.getAllBuildings();

    final production = <ResourceType, double>{};
    final consumption = <ResourceType, double>{};

    for (final building in buildings) {
      // Only calculate production if building has workers (except houses which don't need workers)
      if (building.type == BuildingType.house ||
          building.type == BuildingType.largeHouse ||
          building.hasWorkers) {
        // Calculate production
        building.generation.forEach((resourceType, rate) {
          if (resourceType == ResourceType.research) {
            // Research has special handling - 1 point every 10 seconds
            production.update(
              resourceType,
              (v) => v + 0.1,
              ifAbsent: () => 0.1,
            );
          } else {
            production.update(
              resourceType,
              (v) => v + rate,
              ifAbsent: () => rate,
            );
          }
        });
      }

      // Only calculate consumption if building has workers and can actually consume
      if (building.consumption.isNotEmpty && building.hasWorkers) {
        // Short-circuit check: can consume only if all required resources available
        final canConsume = building.consumption.entries.every(
          (entry) =>
              (widget.resources.resources[entry.key] ?? 0) >= entry.value,
        );

        if (canConsume) {
          building.consumption.forEach((resourceType, rate) {
            consumption.update(
              resourceType,
              (v) => v + rate,
              ifAbsent: () => rate,
            );
          });
        }
      }
    }

    setState(() {
      _productionRates = production;
      _consumptionRates = consumption;
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Resources Overview',
          style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Resources',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View your current resource levels and production rates.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Category Navigation Tabs
            _buildCategoryTabs(),

            const SizedBox(height: 16),

            Expanded(
              child: ListView(
                children: _buildResourceCardsForCategory(_selectedCategory),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Row(
      children: ResourceCategory.values.map((category) {
        final isSelected = category == _selectedCategory;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.cyan.withAlpha((255 * 0.2).round())
                    : Colors.grey.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.cyan
                      : Colors.grey.withAlpha((255 * 0.3).round()),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    color: isSelected ? Colors.cyan : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.cyan : Colors.grey,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildResourceCardsForCategory(ResourceCategory category) {
    final resourcesInCategory = _getResourcesForCategory(category);
    return resourcesInCategory.map((resourceData) {
      return ResourceCard(
        name: resourceData.name,
        amount: resourceData.amount,
        color: resourceData.color,
        resourceType: resourceData.resourceType,
        productionRate: _productionRates[resourceData.resourceType] ?? 0.0,
        consumptionRate: _consumptionRates[resourceData.resourceType] ?? 0.0,
      );
    }).toList();
  }

  List<_ResourceData> _getResourcesForCategory(ResourceCategory category) {
    switch (category) {
      case ResourceCategory.rawMaterials:
        return [
          _ResourceData(
            name: 'Gold',
            amount: widget.resources.gold,
            color: Colors.amber,
            resourceType: ResourceType.gold,
          ),
          _ResourceData(
            name: 'Coal',
            amount: widget.resources.coal,
            color: Colors.grey,
            resourceType: ResourceType.coal,
          ),
          _ResourceData(
            name: 'Electricity',
            amount: widget.resources.electricity,
            color: Colors.yellow,
            resourceType: ResourceType.electricity,
          ),
          _ResourceData(
            name: 'Wood',
            amount: widget.resources.wood,
            color: Colors.brown,
            resourceType: ResourceType.wood,
          ),
          _ResourceData(
            name: 'Water',
            amount: widget.resources.water,
            color: Colors.cyan,
            resourceType: ResourceType.water,
          ),
          _ResourceData(
            name: 'Planks',
            amount: widget.resources.planks,
            color: Colors.brown,
            resourceType: ResourceType.planks,
          ),
          _ResourceData(
            name: 'Stone',
            amount: widget.resources.stone,
            color: Colors.grey,
            resourceType: ResourceType.stone,
          ),
        ];
      case ResourceCategory.foodResources:
        return [
          _ResourceData(
            name: 'Wheat',
            amount: widget.resources.wheat,
            color: Colors.orange,
            resourceType: ResourceType.wheat,
          ),
          _ResourceData(
            name: 'Corn',
            amount: widget.resources.corn,
            color: Colors.yellow,
            resourceType: ResourceType.corn,
          ),
          _ResourceData(
            name: 'Rice',
            amount: widget.resources.rice,
            color: Colors.lightGreen,
            resourceType: ResourceType.rice,
          ),
          _ResourceData(
            name: 'Barley',
            amount: widget.resources.barley,
            color: Colors.amber,
            resourceType: ResourceType.barley,
          ),
        ];
      case ResourceCategory.stapleGrains:
        return [
          _ResourceData(
            name: 'Flour',
            amount: widget.resources.flour,
            color: Colors.orange,
            resourceType: ResourceType.flour,
          ),
          _ResourceData(
            name: 'Cornmeal',
            amount: widget.resources.cornmeal,
            color: Colors.yellow,
            resourceType: ResourceType.cornmeal,
          ),
          _ResourceData(
            name: 'Polished Rice',
            amount: widget.resources.polishedRice,
            color: Colors.lightGreen,
            resourceType: ResourceType.polishedRice,
          ),
          _ResourceData(
            name: 'Malted Barley',
            amount: widget.resources.maltedBarley,
            color: Colors.amber,
            resourceType: ResourceType.maltedBarley,
          ),
        ];
      case ResourceCategory.refinement:
        return [
          _ResourceData(
            name: 'Bread',
            amount: widget.resources.bread,
            color: Colors.orange,
            resourceType: ResourceType.bread,
          ),
          _ResourceData(
            name: 'Pastries',
            amount: widget.resources.pastries,
            color: Colors.orange,
            resourceType: ResourceType.pastries,
          ),
        ];
    }
  }
}
