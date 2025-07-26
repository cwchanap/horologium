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
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('TRADE CENTER', style: TextStyle(fontFamily: 'Orbitron', color: Colors.cyanAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f1e)],
          ),
        ),
        child: Padding(
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Colors.cyanAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _performTrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('PERFORM TRADE', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceSelector(
    String label,
    ResourceType? selectedResource,
    ValueChanged<ResourceType?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Orbitron')),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<ResourceType>(
              value: selectedResource,
              onChanged: onChanged,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
              dropdownColor: const Color(0xFF16213e),
              iconEnabledColor: Colors.cyanAccent,
              items: ResourceRegistry.availableResources
                  .map((resource) => DropdownMenuItem(
                        value: resource.type,
                        child: Text('${resource.name} (${widget.resources.resources[resource.type]?.toStringAsFixed(2) ?? 0})'),
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