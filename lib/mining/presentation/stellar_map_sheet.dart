import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';

/// Render surface for [StellarMapView]. It renders the pre-computed planet
/// requirements and forwards unlock/travel taps; it never calculates
/// eligibility.
class StellarMapSheet extends StatelessWidget {
  const StellarMapSheet({
    super.key,
    required this.view,
    required this.onUnlock,
    required this.onTravel,
  });

  final StellarMapView view;
  final ValueChanged<MiningPlanetId> onUnlock;
  final ValueChanged<MiningPlanetId> onTravel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: Material(
          key: const Key('mining-stellar-map-sheet'),
          color: const Color(0xF20E1828),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withAlpha(180),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Stellar Map',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chart the operation across the system.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                for (final planet in view.planets) _planetCard(context, planet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planetCard(BuildContext context, StellarMapPlanetView planet) {
    return Container(
      key: Key('stellar-map-planet-${planet.id.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: planet.isActive ? Colors.cyanAccent : Colors.white24,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                planet.isActive ? Icons.public : Icons.public_outlined,
                color: planet.isActive ? Colors.cyanAccent : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  planet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (planet.isActive)
                const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _progressRow(planet),
          const SizedBox(height: 8),
          if (planet.isUnlocked)
            _travelButton(context: context, planet: planet)
          else
            _lockedPlanet(context, planet),
        ],
      ),
    );
  }

  Widget _progressRow(StellarMapPlanetView planet) => Text(
    'Mines ${planet.minesBuilt}/${planet.mineTotal}',
    style: const TextStyle(color: Colors.white70),
  );

  Widget _travelButton({
    required BuildContext context,
    required StellarMapPlanetView planet,
  }) {
    return SizedBox(
      key: Key('mining-stellar-map-travel-${planet.id.name}'),
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: planet.isActive
            ? null
            : () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop();
                onTravel(planet.id);
              },
        child: Text(planet.isActive ? 'CURRENT LOCATION' : 'TRAVEL HERE'),
      ),
    );
  }

  Widget _lockedPlanet(BuildContext context, StellarMapPlanetView planet) {
    final requiredMasteryPlanetId = planet.requiredMasteryPlanetId;
    final requiredPlanet = requiredMasteryPlanetId == null
        ? null
        : view.planet(requiredMasteryPlanetId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requiredPlanet != null)
          _requirementRow(
            '${requiredPlanet.name} mines '
            '${requiredPlanet.minesBuilt}/${requiredPlanet.mineTotal}',
            planet.hasRequiredMastery,
          ),
        _requirementRow(
          'Surveying ${planet.requiredSurveyingLevel}',
          planet.hasSurveying,
        ),
        _requirementRow('${planet.unlockCashCost} cash', planet.hasCash),
        const SizedBox(height: 8),
        SizedBox(
          key: Key('mining-stellar-map-unlock-${planet.id.name}'),
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: planet.canUnlock
                ? () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) navigator.pop();
                    onUnlock(planet.id);
                  }
                : null,
            child: Text('UNLOCK FOR ${planet.unlockCashCost} CASH'),
          ),
        ),
      ],
    );
  }

  Widget _requirementRow(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: satisfied ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
