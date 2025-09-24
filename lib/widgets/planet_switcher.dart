import 'package:flutter/material.dart';
import '../game/planet/active_planet.dart';

/// A simple widget stub for switching between planets
/// This demonstrates the planet-switching framework without implementing multiple planets yet
class PlanetSwitcher extends StatefulWidget {
  final VoidCallback? onPlanetChanged;

  const PlanetSwitcher({super.key, this.onPlanetChanged});

  @override
  State<PlanetSwitcher> createState() => _PlanetSwitcherState();
}

class _PlanetSwitcherState extends State<PlanetSwitcher> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final activePlanet = ActivePlanet();
    final availablePlanets = ActivePlanet.getAvailablePlanetIds();
    final currentPlanetId = activePlanet.isInitialized
        ? activePlanet.activePlanetId
        : 'earth';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Planet Selection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Current Planet: ${ActivePlanet.getPlanetDisplayName(currentPlanetId)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Available Planets:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...availablePlanets.map(
              (planetId) => _buildPlanetButton(planetId, currentPlanetId),
            ),
            const SizedBox(height: 12),
            if (availablePlanets.length == 1)
              const Text(
                'More planets will be unlocked as you progress!',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanetButton(String planetId, String currentPlanetId) {
    final isCurrentPlanet = planetId == currentPlanetId;
    final displayName = ActivePlanet.getPlanetDisplayName(planetId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSwitching || isCurrentPlanet
              ? null
              : () => _switchToPlanet(planetId),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCurrentPlanet ? Colors.green.shade100 : null,
            foregroundColor: isCurrentPlanet ? Colors.green.shade800 : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(displayName),
              if (isCurrentPlanet)
                const Icon(Icons.check_circle, size: 16)
              else if (_isSwitching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchToPlanet(String planetId) async {
    setState(() {
      _isSwitching = true;
    });

    try {
      await ActivePlanet().switchToPlanet(planetId);
      widget.onPlanetChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${ActivePlanet.getPlanetDisplayName(planetId)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch planets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }
}
