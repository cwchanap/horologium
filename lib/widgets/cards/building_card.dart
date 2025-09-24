import 'package:flutter/material.dart';
import '../../game/building/building.dart';

class BuildingCard extends StatelessWidget {
  final Building building;
  final VoidCallback onTap;
  final int currentCount;
  final int maxCount;

  const BuildingCard({
    super.key,
    required this.building,
    required this.onTap,
    required this.currentCount,
    required this.maxCount,
  });

  Widget _buildBuildingImage({double size = 24}) {
    if (building.assetPath != null) {
      return Image.asset(
        'assets/images/${building.assetPath!}',
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if image fails to load
          return Icon(building.icon, color: building.color, size: size);
        },
      );
    } else {
      return Icon(building.icon, color: building.color, size: size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAtLimit = currentCount >= maxCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: building.color.withAlpha((255 * 0.2).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: building.color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildBuildingImage(size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      building.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${building.cost} cash',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$currentCount/$maxCount',
                      style: TextStyle(
                        color: isAtLimit ? Colors.red : Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
