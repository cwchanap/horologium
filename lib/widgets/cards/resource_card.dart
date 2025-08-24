import 'package:flutter/material.dart';
import '../../game/resources/resource_type.dart';
import '../game/resource_icon.dart';

class ResourceCard extends StatelessWidget {
  final String name;
  final double amount;
  final Color color;
  final IconData? icon;
  final ResourceType? resourceType;
  final double productionRate;
  final double consumptionRate;

  const ResourceCard({
    super.key,
    required this.name,
    required this.amount,
    required this.color,
    this.icon,
    this.resourceType,
    this.productionRate = 0.0,
    this.consumptionRate = 0.0,
  }) : assert(icon != null || resourceType != null, 'Either icon or resourceType must be provided');

  @override
  Widget build(BuildContext context) {
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
                child: resourceType != null 
                    ? ResourceIcon(
                        resourceType: resourceType!,
                        size: 24,
                      )
                    : Icon(icon!, color: color, size: 24),
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
          const SizedBox(height: 12),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRateInfo(
                  'Production',
                  name == 'Research' ? '${(productionRate * 10).toStringAsFixed(1)}/s' : '${productionRate.toStringAsFixed(1)}/s',
                  productionRate > 0 ? Colors.green : Colors.grey,
                  Icons.add_circle_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRateInfo(
                  'Consumption',
                  '${consumptionRate.toStringAsFixed(1)}/s',
                  consumptionRate > 0 ? Colors.red : Colors.grey,
                  Icons.remove_circle_outline,
                ),
              ),
            ],
          ),
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
}
