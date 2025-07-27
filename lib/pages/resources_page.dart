import 'dart:async';
import 'package:flutter/material.dart';
import '../game/resources/resources.dart';
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
      // Calculate production
      building.generation.forEach((resource, rate) {
        if (resource == 'research') {
          // Research has special handling - 1 point every 10 seconds
          production.update(resource, (v) => v + 0.1, ifAbsent: () => 0.1);
        } else {
          production.update(resource, (v) => v + rate, ifAbsent: () => rate);
        }
      });
      
      // Calculate consumption
      building.consumption.forEach((resource, rate) {
        consumption.update(resource, (v) => v + rate, ifAbsent: () => rate);
      });
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
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  ResourceCard(
                    name: 'Money',
                    amount: widget.resources.money,
                    color: Colors.green,
                    icon: Icons.attach_money,
                    productionRate: _productionRates['money'] ?? 0.0,
                    consumptionRate: _consumptionRates['money'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Gold',
                    amount: widget.resources.gold,
                    color: Colors.amber,
                    icon: Icons.star,
                    productionRate: _productionRates['gold'] ?? 0.0,
                    consumptionRate: _consumptionRates['gold'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Coal',
                    amount: widget.resources.coal,
                    color: Colors.grey,
                    icon: Icons.fireplace,
                    productionRate: _productionRates['coal'] ?? 0.0,
                    consumptionRate: _consumptionRates['coal'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Electricity',
                    amount: widget.resources.electricity,
                    color: Colors.yellow,
                    icon: Icons.bolt,
                    productionRate: _productionRates['electricity'] ?? 0.0,
                    consumptionRate: _consumptionRates['electricity'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Wood',
                    amount: widget.resources.wood,
                    color: Colors.brown,
                    icon: Icons.park,
                    productionRate: _productionRates['wood'] ?? 0.0,
                    consumptionRate: _consumptionRates['wood'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Water',
                    amount: widget.resources.water,
                    color: Colors.cyan,
                    icon: Icons.water_drop,
                    productionRate: _productionRates['water'] ?? 0.0,
                    consumptionRate: _consumptionRates['water'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Research',
                    amount: widget.resources.research,
                    color: Colors.purple,
                    icon: Icons.science,
                    productionRate: _productionRates['research'] ?? 0.0,
                    consumptionRate: _consumptionRates['research'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Planks',
                    amount: widget.resources.planks,
                    color: Colors.brown,
                    icon: Icons.construction,
                    productionRate: _productionRates['planks'] ?? 0.0,
                    consumptionRate: _consumptionRates['planks'] ?? 0.0,
                  ),
                  ResourceCard(
                    name: 'Stone',
                    amount: widget.resources.stone,
                    color: Colors.grey,
                    icon: Icons.terrain,
                    productionRate: _productionRates['stone'] ?? 0.0,
                    consumptionRate: _consumptionRates['stone'] ?? 0.0,
                  ),
                  const SizedBox(height: 16),
                  PopulationCard(
                    population: widget.resources.population,
                    availableWorkers: widget.resources.availableWorkers,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}