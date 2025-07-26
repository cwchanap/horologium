import 'package:flutter/material.dart';
import 'package:horologium/game/resource_type.dart';
import 'package:horologium/game/resources.dart';

class TradePage extends StatefulWidget {
  final Resources resources;

  const TradePage({super.key, required this.resources});

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> {
  ResourceType? _fromResource;
  ResourceType? _toResource;
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Resources'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildResourceSelector('From', _fromResource, (type) {
              setState(() {
                _fromResource = type;
              });
            }),
            const SizedBox(height: 16),
            _buildResourceSelector('To', _toResource, (type) {
              setState(() {
                _toResource = type;
              });
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performTrade,
              child: const Text('Trade'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceSelector(
    String label,
    ResourceType? selectedResource,
    ValueChanged<ResourceType?> onChanged,
  ) {
    return Row(
      children: [
        Text('$label: '),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<ResourceType>(
            value: selectedResource,
            onChanged: onChanged,
            items: ResourceRegistry.availableResources
                .map((resource) => DropdownMenuItem(
                      value: resource.type,
                      child: Text('${resource.name} (${widget.resources.resources[resource.type]?.toStringAsFixed(2) ?? 0})'),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  void _performTrade() {
    if (_fromResource != null &&
        _toResource != null &&
        _amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null && amount > 0) {
        setState(() {
          widget.resources.trade(_fromResource!, _toResource!, amount);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trade successful!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid amount')),
        );
      }
    }
  }
}
