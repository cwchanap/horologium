import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

class TradePage extends StatefulWidget {
  final Resources resources;

  const TradePage({super.key, required this.resources});

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> {
  ResourceType? _selectedFromResource;
  ResourceType? _selectedToResource;
  final _amountController = TextEditingController();

  // Resource icon and color mappings based on the game's existing patterns
  final Map<ResourceType, IconData> _resourceIcons = {
    ResourceType.money: Icons.attach_money,
    ResourceType.gold: Icons.star,
    ResourceType.wood: Icons.park,
    ResourceType.coal: Icons.fireplace,
    ResourceType.electricity: Icons.bolt,
    ResourceType.research: Icons.science,
    ResourceType.water: Icons.water_drop,
    ResourceType.planks: Icons.construction,
    ResourceType.stone: Icons.terrain,
    ResourceType.wheat: Icons.grass,
    ResourceType.corn: Icons.eco,
    ResourceType.rice: Icons.grain,
    ResourceType.barley: Icons.agriculture,
  };

  final Map<ResourceType, Color> _resourceColors = {
    ResourceType.money: Colors.green,
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
          'Trade Center',
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
              'Resource Trading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a resource to trade, then choose what to trade it for.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: ResourceRegistry.availableResources.length,
                itemBuilder: (context, index) {
                  final resource = ResourceRegistry.availableResources[index];
                  return _buildResourceTileCard(resource);
                },
              ),
            ),
            if (_selectedFromResource != null) ...[
              const SizedBox(height: 16),
              _buildTradeInterface(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourceTileCard(Resource resource) {
    final amount = widget.resources.resources[resource.type] ?? 0.0;
    final icon = _resourceIcons[resource.type] ?? Icons.help;
    final color = _resourceColors[resource.type] ?? Colors.grey;
    final isSelected = _selectedFromResource == resource.type;
    final hasResources = amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? Colors.cyan 
              : color.withAlpha((255 * 0.3).round()), 
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasResources ? () {
            setState(() {
              if (_selectedFromResource == resource.type) {
                _selectedFromResource = null;
                _selectedToResource = null;
              } else {
                _selectedFromResource = resource.type;
                _selectedToResource = null;
              }
            });
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasResources 
                        ? color.withAlpha((255 * 0.2).round())
                        : Colors.grey.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon, 
                    color: hasResources ? color : Colors.grey, 
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: TextStyle(
                          color: hasResources ? Colors.white : Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        resource.name == 'Research' 
                            ? '${amount.toInt()}' 
                            : amount.toStringAsFixed(1),
                        style: TextStyle(
                          color: hasResources ? color : Colors.grey,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: !hasResources
                        ? Colors.grey.withAlpha((255 * 0.1).round())
                        : isSelected 
                            ? Colors.cyan.withAlpha((255 * 0.2).round())
                            : Colors.grey.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: !hasResources
                          ? Colors.grey
                          : isSelected ? Colors.cyan : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    !hasResources 
                        ? 'NO STOCK'
                        : isSelected 
                            ? 'SELECTED' 
                            : 'TRADE FOR',
                    style: TextStyle(
                      color: !hasResources
                          ? Colors.grey
                          : isSelected ? Colors.cyan : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeInterface() {
    if (_selectedFromResource == null) return const SizedBox.shrink();

    final fromResource = ResourceRegistry.find(_selectedFromResource!)!;
    final fromIcon = _resourceIcons[_selectedFromResource] ?? Icons.help;
    final fromColor = _resourceColors[_selectedFromResource] ?? Colors.grey;
    final availableAmount = widget.resources.resources[_selectedFromResource!] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fromColor.withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(fromIcon, color: fromColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trading ${fromResource.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Available: ${fromResource.name == 'Research' ? availableAmount.toInt() : availableAmount.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: fromColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Amount to trade',
              labelStyle: const TextStyle(color: Colors.cyan),
              helperText: 'Max: ${fromResource.name == 'Research' ? availableAmount.toInt() : availableAmount.toStringAsFixed(1)}',
              helperStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  _amountController.text = (availableAmount / 2).toStringAsFixed(1);
                },
                child: const Text('Half', style: TextStyle(color: Colors.cyan)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _amountController.text = fromResource.name == 'Research' 
                      ? availableAmount.toInt().toString()
                      : availableAmount.toStringAsFixed(1);
                },
                child: const Text('Max', style: TextStyle(color: Colors.cyan)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Trade for:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ResourceRegistry.availableResources.length,
              itemBuilder: (context, index) {
                final resource = ResourceRegistry.availableResources[index];
                if (resource.type == _selectedFromResource) return const SizedBox.shrink();
                
                return _buildTargetResourceChip(resource);
              },
            ),
          ),
          if (_selectedToResource != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _performTrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.cyan,
                  side: const BorderSide(color: Colors.cyan, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'PERFORM TRADE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetResourceChip(Resource resource) {
    final icon = _resourceIcons[resource.type] ?? Icons.help;
    final color = _resourceColors[resource.type] ?? Colors.grey;
    final isSelected = _selectedToResource == resource.type;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedToResource = resource.type;
            });
          },
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? color.withAlpha((255 * 0.2).round())
                  : Colors.grey.withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withAlpha((255 * 0.3).round()),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  resource.name,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _performTrade() {
    if (_selectedFromResource != null &&
        _selectedToResource != null &&
        _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null && amount > 0) {
        final currentAmount = widget.resources.resources[_selectedFromResource!] ?? 0.0;
        
        if (currentAmount >= amount) {
          setState(() {
            widget.resources.trade(_selectedFromResource!, _selectedToResource!, amount);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trade successful! Exchanged ${amount.toStringAsFixed(1)} ${ResourceRegistry.find(_selectedFromResource!)?.name} for ${ResourceRegistry.find(_selectedToResource!)?.name}'),
              backgroundColor: Colors.green.withAlpha((255 * 0.8).round()),
              duration: const Duration(seconds: 3),
            ),
          );
          // Clear the amount field and selections after successful trade
          _amountController.clear();
          setState(() {
            _selectedFromResource = null;
            _selectedToResource = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not enough ${ResourceRegistry.find(_selectedFromResource!)?.name}! You have ${currentAmount.toStringAsFixed(1)} but need ${amount.toStringAsFixed(1)}'),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both resources and enter an amount'),
          backgroundColor: Colors.orange.withAlpha((255 * 0.8).round()),
        ),
      );
    }
  }
}