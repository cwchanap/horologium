import 'package:flutter/material.dart';
import '../../game/resources/resource_type.dart';
import '../../constants/assets_path.dart';

class ResourceIcon extends StatelessWidget {
  final ResourceType resourceType;
  final double size;
  final Color? fallbackColor;

  const ResourceIcon({
    super.key,
    required this.resourceType,
    this.size = 24.0,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = _getAssetPath(resourceType);
    
    if (assetPath != null) {
      return Image.asset(
        'assets/images/$assetPath',
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon();
        },
      );
    } else {
      return _buildFallbackIcon();
    }
  }

  Widget _buildFallbackIcon() {
    return Icon(
      _getFallbackIcon(resourceType),
      size: size,
      color: fallbackColor ?? _getFallbackColor(resourceType),
    );
  }

  String? _getAssetPath(ResourceType resourceType) {
    switch (resourceType) {
      case ResourceType.gold:
        return Assets.goldIcon;
      case ResourceType.wood:
        return Assets.woodIcon;
      case ResourceType.coal:
        return Assets.coalIcon;
      case ResourceType.electricity:
        return Assets.electricityIcon;
      case ResourceType.research:
        return Assets.researchIcon;
      case ResourceType.water:
        return Assets.waterIcon;
      case ResourceType.planks:
        return Assets.planksIcon;
      case ResourceType.stone:
        return Assets.stoneIcon;
      case ResourceType.wheat:
        return Assets.wheatIcon;
      case ResourceType.corn:
        return Assets.cornIcon;
      case ResourceType.rice:
        return Assets.riceIcon;
      case ResourceType.barley:
        return Assets.barleyIcon;
      case ResourceType.flour:
        return Assets.flourIcon;
      case ResourceType.cornmeal:
        return Assets.cornmealIcon;
      case ResourceType.polishedRice:
        return Assets.polishedRiceIcon;
      case ResourceType.maltedBarley:
        return Assets.maltedBarleyIcon;
      case ResourceType.bread:
        return Assets.breadIcon;
      case ResourceType.pastries:
        return Assets.pastriesIcon;
      default:
        return null; // No asset available, will use fallback icon
    }
  }

  IconData _getFallbackIcon(ResourceType resourceType) {
    switch (resourceType) {
      case ResourceType.cash:
        return Icons.attach_money;
      case ResourceType.population:
        return Icons.people;
      case ResourceType.availableWorkers:
        return Icons.work;
      case ResourceType.gold:
        return Icons.star;
      case ResourceType.wood:
        return Icons.park;
      case ResourceType.coal:
        return Icons.fireplace;
      case ResourceType.electricity:
        return Icons.bolt;
      case ResourceType.research:
        return Icons.science;
      case ResourceType.water:
        return Icons.water_drop;
      case ResourceType.planks:
        return Icons.construction;
      case ResourceType.stone:
        return Icons.terrain;
      case ResourceType.wheat:
        return Icons.grass;
      case ResourceType.corn:
        return Icons.eco;
      case ResourceType.rice:
        return Icons.grain;
      case ResourceType.barley:
        return Icons.agriculture;
      case ResourceType.flour:
        return Icons.grain;
      case ResourceType.cornmeal:
        return Icons.grain;
      case ResourceType.polishedRice:
        return Icons.grain;
      case ResourceType.maltedBarley:
        return Icons.grain;
      case ResourceType.bread:
        return Icons.bakery_dining;
      case ResourceType.pastries:
        return Icons.bakery_dining;
    }
  }

  Color _getFallbackColor(ResourceType resourceType) {
    switch (resourceType) {
      case ResourceType.cash:
        return Colors.green;
      case ResourceType.population:
        return Colors.blue;
      case ResourceType.availableWorkers:
        return Colors.orange;
      case ResourceType.gold:
        return Colors.amber;
      case ResourceType.wood:
        return Colors.brown;
      case ResourceType.coal:
        return Colors.grey;
      case ResourceType.electricity:
        return Colors.yellow;
      case ResourceType.research:
        return Colors.purple;
      case ResourceType.water:
        return Colors.cyan;
      case ResourceType.planks:
        return Colors.brown;
      case ResourceType.stone:
        return Colors.grey;
      case ResourceType.wheat:
        return Colors.lightGreen;
      case ResourceType.corn:
        return Colors.orange;
      case ResourceType.rice:
        return Colors.green;
      case ResourceType.barley:
        return Colors.brown;
      case ResourceType.flour:
        return Colors.orange;
      case ResourceType.cornmeal:
        return Colors.yellow;
      case ResourceType.polishedRice:
        return Colors.lightGreen;
      case ResourceType.maltedBarley:
        return Colors.amber;
      case ResourceType.bread:
        return Colors.orange;
      case ResourceType.pastries:
        return Colors.orange;
    }
  }
}
