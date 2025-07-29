import 'dart:async';
import 'package:flutter/material.dart';
import '../game/resources/resources.dart';
import '../game/resources/resource_type.dart';
import '../game/resources/resource_category.dart';
import '../game/building/building.dart';
import '../game/grid.dart';
import '../widgets/cards/cards.dart';

class ResourcesPage extends StatefulWidget {
  final Resources resources;
  final Grid grid;

  const ResourcesPage({
    super.key,
    required this.resources,
    required this.grid,
  });

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  Map<String, double> _productionRates = {};
  Map<String, double> _consumptionRates = {};
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
    
    final production = <String, double>{};
    final consumption = <String, double>{};

    for (final building in buildings) {
      // Only calculate production if building has workers (except houses which don't need workers)
      if (building.type == BuildingType.house || building.type == BuildingType.largeHouse || building.hasWorkers) {
        // Calculate production
        building.generation.forEach((resource, rate) {
          if (resource == 'research') {
            // Research has special handling - 1 point every 10 seconds
            production.update(resource, (v) => v + 0.1, ifAbsent: () => 0.1);
          } else {
            production.update(resource, (v) => v + rate, ifAbsent: () => rate);
          }
        });
      }
      
      // Only calculate consumption if building has workers and can actually consume
      if (building.consumption.isNotEmpty && building.hasWorkers) {
        bool canConsume = true;
        
        // Check if building can consume what it needs
        building.consumption.forEach((key, value) {
          final resourceType = ResourceType.values.firstWhere((e) => e.toString() == 'ResourceType.$key');
          if ((widget.resources.resources[resourceType] ?? 0) < value) {
            canConsume = false;
          }
        });
        
        if (canConsume) {
          building.consumption.forEach((resource, rate) {
            consumption.update(resource, (v) => v + rate, ifAbsent: () => rate);
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
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        name: resourceData['name'],
        amount: resourceData['amount'],
        color: resourceData['color'],
        icon: resourceData['icon'],
        productionRate: _productionRates[resourceData['key']] ?? 0.0,
        consumptionRate: _consumptionRates[resourceData['key']] ?? 0.0,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getResourcesForCategory(ResourceCategory category) {
    switch (category) {
      case ResourceCategory.rawMaterials:
        return [
          {'name': 'Gold', 'amount': widget.resources.gold, 'color': Colors.amber, 'icon': Icons.star, 'key': 'gold'},
          {'name': 'Coal', 'amount': widget.resources.coal, 'color': Colors.grey, 'icon': Icons.fireplace, 'key': 'coal'},
          {'name': 'Electricity', 'amount': widget.resources.electricity, 'color': Colors.yellow, 'icon': Icons.bolt, 'key': 'electricity'},
          {'name': 'Wood', 'amount': widget.resources.wood, 'color': Colors.brown, 'icon': Icons.park, 'key': 'wood'},
          {'name': 'Water', 'amount': widget.resources.water, 'color': Colors.cyan, 'icon': Icons.water_drop, 'key': 'water'},
          {'name': 'Planks', 'amount': widget.resources.planks, 'color': Colors.brown, 'icon': Icons.construction, 'key': 'planks'},
          {'name': 'Stone', 'amount': widget.resources.stone, 'color': Colors.grey, 'icon': Icons.terrain, 'key': 'stone'},
        ];
      case ResourceCategory.foodResources:
        return [
          {'name': 'Wheat', 'amount': widget.resources.wheat, 'color': Colors.orange, 'icon': Icons.grass, 'key': 'wheat'},
          {'name': 'Corn', 'amount': widget.resources.corn, 'color': Colors.yellow, 'icon': Icons.eco, 'key': 'corn'},
          {'name': 'Rice', 'amount': widget.resources.rice, 'color': Colors.lightGreen, 'icon': Icons.grain, 'key': 'rice'},
          {'name': 'Barley', 'amount': widget.resources.barley, 'color': Colors.amber, 'icon': Icons.agriculture, 'key': 'barley'},
        ];
      case ResourceCategory.stapleGrains:
        return [
          {'name': 'Flour', 'amount': widget.resources.flour, 'color': Colors.orange, 'icon': Icons.grain, 'key': 'flour'},
          {'name': 'Cornmeal', 'amount': widget.resources.cornmeal, 'color': Colors.yellow, 'icon': Icons.grain, 'key': 'cornmeal'},
          {'name': 'Polished Rice', 'amount': widget.resources.polishedRice, 'color': Colors.lightGreen, 'icon': Icons.grain, 'key': 'polishedRice'},
          {'name': 'Malted Barley', 'amount': widget.resources.maltedBarley, 'color': Colors.amber, 'icon': Icons.grain, 'key': 'maltedBarley'},
        ];
    }
  }
}