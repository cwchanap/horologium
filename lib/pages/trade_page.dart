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
              'Exchange resources at standard rates to meet your colony\'s needs.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
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
                  _buildAmountField(),
                  const SizedBox(height: 24),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: TextField(
        controller: _amountController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Amount',
          labelStyle: TextStyle(color: Colors.cyan),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildResourceSelector(
    String label,
    ResourceType? selectedResource,
    ValueChanged<ResourceType?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withAlpha((255 * 0.3).round()), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label Resource',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha((255 * 0.05).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<ResourceType>(
              value: selectedResource,
              onChanged: onChanged,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF2a2a2a),
              iconEnabledColor: Colors.cyan,
              hint: Text(
                'Select $label resource',
                style: const TextStyle(color: Colors.grey),
              ),
              items: ResourceRegistry.availableResources
                  .map((resource) => DropdownMenuItem(
                        value: resource.type,
                        child: Text(
                          '${resource.name} (${widget.resources.resources[resource.type]?.toStringAsFixed(2) ?? 0})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
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
          SnackBar(
            content: const Text('Trade successful!'),
            backgroundColor: Colors.green.withAlpha((255 * 0.8).round()),
          ),
        );
        // Clear the amount field after successful trade
        _amountController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid amount'),
            backgroundColor: Colors.red.withAlpha((255 * 0.8).round()),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select resources and enter an amount'),
          backgroundColor: Colors.orange.withAlpha((255 * 0.8).round()),
        ),
      );
    }
  }
}