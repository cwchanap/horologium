import 'dart:async';
import 'package:flutter/material.dart';
import '../game/resources.dart';
import '../game/building/building.dart';
import '../game/grid.dart';

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
                  _buildResourceCard('Money', widget.resources.money, Colors.green, Icons.attach_money),
                  _buildResourceCard('Gold', widget.resources.gold, Colors.amber, Icons.star),
                  _buildResourceCard('Coal', widget.resources.coal, Colors.grey, Icons.fireplace),
                  _buildResourceCard('Electricity', widget.resources.electricity, Colors.yellow, Icons.bolt),
                  _buildResourceCard('Wood', widget.resources.wood, Colors.brown, Icons.park),
                  _buildResourceCard('Water', widget.resources.water, Colors.cyan, Icons.water_drop),
                  _buildResourceCard('Research', widget.resources.research, Colors.purple, Icons.science),
                  _buildResourceCard('Planks', widget.resources.planks, Colors.brown, Icons.construction),
                  _buildResourceCard('Stone', widget.resources.stone, Colors.grey, Icons.terrain),
                  const SizedBox(height: 16),
                  _buildPopulationCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(String name, double amount, Color color, IconData icon) {
    final productionRate = _productionRates[name.toLowerCase()] ?? 0.0;
    final consumptionRate = _consumptionRates[name.toLowerCase()] ?? 0.0;
    final netRate = productionRate - consumptionRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      name == 'Research' ? '${amount.toInt()}' : amount.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (netRate != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (netRate > 0 ? Colors.green : Colors.red).withAlpha((255 * 0.2).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            netRate > 0 ? Icons.trending_up : Icons.trending_down,
                            color: netRate > 0 ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${netRate > 0 ? '+' : ''}${name == 'Research' ? (netRate * 10).toStringAsFixed(1) : netRate.toStringAsFixed(1)}/s',
                            style: TextStyle(
                              color: netRate > 0 ? Colors.green : Colors.red,
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
          if (productionRate > 0 || consumptionRate > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.grey, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (productionRate > 0)
                  Expanded(
                    child: _buildRateInfo(
                      'Production',
                      name == 'Research' ? '${(productionRate * 10).toStringAsFixed(1)}/s' : '${productionRate.toStringAsFixed(1)}/s',
                      Colors.green,
                      Icons.add_circle_outline,
                    ),
                  ),
                if (productionRate > 0 && consumptionRate > 0)
                  const SizedBox(width: 16),
                if (consumptionRate > 0)
                  Expanded(
                    child: _buildRateInfo(
                      'Consumption',
                      '${consumptionRate.toStringAsFixed(1)}/s',
                      Colors.red,
                      Icons.remove_circle_outline,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateInfo(String label, String rate, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
            Text(
              rate,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPopulationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((255 * 0.2).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Population',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.resources.population}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Available Workers: ${widget.resources.availableWorkers}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((255 * 0.2).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text(
                  'Citizens',
                  style: TextStyle(
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
    );
  }
}