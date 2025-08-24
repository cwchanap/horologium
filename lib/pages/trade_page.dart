import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import '../widgets/game/resource_icon.dart';

class TradePage extends StatefulWidget {
  final Resources resources;

  const TradePage({super.key, required this.resources});

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> {
  final _amountController = TextEditingController();

  // Resource color mappings based on the game's existing patterns
  final Map<ResourceType, Color> _resourceColors = {
    ResourceType.cash: Colors.green,
    ResourceType.gold: Colors.amber,
    ResourceType.wood: Colors.brown,
    ResourceType.coal: Colors.grey,
    ResourceType.electricity: Colors.yellow,
    ResourceType.research: Colors.purple,
    ResourceType.water: Colors.cyan,
    ResourceType.planks: Colors.brown,
    ResourceType.stone: Colors.grey,
    ResourceType.wheat: Colors.lightGreen,
    ResourceType.corn: Colors.orange,
    ResourceType.rice: Colors.green,
    ResourceType.barley: Colors.brown,
  };

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Resource Market',
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
              'Resource Market',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buy and sell resources using cash. Buy costs 10x value, sell gives 8x value.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: ResourceRegistry.availableResources.where((resource) => resource.type != ResourceType.research).length,
                itemBuilder: (context, index) {
                  final filteredResources = ResourceRegistry.availableResources.where((resource) => resource.type != ResourceType.research).toList();
                  final resource = filteredResources[index];
                  return _buildResourceTileCard(resource);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceTileCard(Resource resource) {
    final amount = widget.resources.resources[resource.type] ?? 0.0;
    final color = _resourceColors[resource.type] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((255 * 0.3).round()),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha((255 * 0.2).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ResourceIcon(
                resourceType: resource.type,
                size: 24,
                fallbackColor: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    resource.name == 'Research'
                        ? '${amount.toInt()}'
                        : amount.toStringAsFixed(1),
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Row(
                children: [
                  Flexible(
                    child: _buildTileActionButton(
                      'BUY',
                      Colors.green,
                      () => _showBuyDialog(resource, amount, resource.value * 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _buildTileActionButton(
                      'SELL',
                      Colors.orange,
                      amount > 0 ? () => _showSellDialog(resource, amount, resource.value * 8) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTileActionButton(String title, Color color, VoidCallback? onPressed) {
    final isDisabled = onPressed == null;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled
            ? Colors.grey.withAlpha((255 * 0.1).round())
            : color.withAlpha((255 * 0.1).round()),
        foregroundColor: isDisabled ? Colors.grey : color,
        side: BorderSide(
          color: isDisabled ? Colors.grey : color,
          width: 1
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isDisabled ? Colors.grey : color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showBuyDialog(Resource resource, double availableAmount, double buyCost) {
    final TextEditingController dialogController = TextEditingController();
    final currentCash = widget.resources.cash;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Buy ${resource.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Cash: ${currentCash.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                'Cost per unit: ${buyCost.toStringAsFixed(1)} cash',
                style: const TextStyle(color: Colors.cyan),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dialogController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount to buy',
                  labelStyle: TextStyle(color: Colors.cyan),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(dialogController.text);
                if (amount != null && amount > 0) {
                  final success = widget.resources.buyResource(resource.type, amount);
                  Navigator.of(context).pop();
                  if (success) {
                    setState(() {});
                    final cost = resource.value * 10 * amount;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purchase successful! Bought ${amount.toStringAsFixed(1)} ${resource.name} for ${cost.toStringAsFixed(1)} cash'),
                        backgroundColor: Colors.green.withAlpha((255 * 0.8).round()),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Not enough cash for this purchase!'),
                        backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid positive number'),
                      backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buy'),
            ),
          ],
        );
      },
    );
  }

  void _showSellDialog(Resource resource, double availableAmount, double sellGain) {
    final TextEditingController dialogController = TextEditingController();
    final currentCash = widget.resources.cash;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Sell ${resource.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Cash: ${currentCash.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${resource.name == 'Research' ? availableAmount.toInt() : availableAmount.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Text(
                'Gain per unit: ${sellGain.toStringAsFixed(1)} cash',
                style: const TextStyle(color: Colors.cyan),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dialogController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount to sell',
                  labelStyle: const TextStyle(color: Colors.cyan),
                  helperText: 'Max: ${resource.name == 'Research' ? availableAmount.toInt() : availableAmount.toStringAsFixed(1)}',
                  helperStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(dialogController.text);
                if (amount != null && amount > 0) {
                  if (availableAmount >= amount) {
                    final success = widget.resources.sellResource(resource.type, amount);
                    Navigator.of(context).pop();
                    if (success) {
                      setState(() {});
                      final gain = resource.value * 8 * amount;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sale successful! Sold ${amount.toStringAsFixed(1)} ${resource.name} for ${gain.toStringAsFixed(1)} cash'),
                          backgroundColor: Colors.green.withAlpha((255 * 0.8).round()),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Sale failed!'),
                          backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Not enough ${resource.name}! You have ${availableAmount.toStringAsFixed(1)} but need ${amount.toStringAsFixed(1)}'),
                        backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid positive number'),
                      backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sell'),
            ),
          ],
        );
      },
    );
  }
}