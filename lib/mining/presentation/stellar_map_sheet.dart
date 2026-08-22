import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';

/// Render surface for [StellarMapView]. It renders the pre-computed unlock
/// requirements and forwards unlock/travel taps; it never calculates
/// eligibility.
class StellarMapSheet extends StatelessWidget {
  const StellarMapSheet({
    super.key,
    required this.view,
    required this.activePlanetId,
    required this.homeworldName,
    required this.lunarName,
    required this.onUnlockLunar,
    required this.onTravel,
  });

  final StellarMapView view;
  final MiningPlanetId activePlanetId;
  final String homeworldName;
  final String lunarName;
  final VoidCallback onUnlockLunar;
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
                _planetCard(
                  key: const Key('stellar-map-planet-homeworld'),
                  name: homeworldName,
                  isActive: activePlanetId == MiningPlanetId.homeworld,
                  child: _travelButton(
                    context: context,
                    key: const Key('mining-stellar-map-travel-homeworld'),
                    planetId: MiningPlanetId.homeworld,
                  ),
                ),
                _planetCard(
                  key: const Key('stellar-map-planet-lunarFrontier'),
                  name: lunarName,
                  isActive: activePlanetId == MiningPlanetId.lunarFrontier,
                  child: view.isLunarUnlocked
                      ? _travelButton(
                          context: context,
                          key: const Key(
                            'mining-stellar-map-travel-lunarFrontier',
                          ),
                          planetId: MiningPlanetId.lunarFrontier,
                        )
                      : _lockedLunarCard(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _travelButton({
    required BuildContext context,
    required Key key,
    required MiningPlanetId planetId,
  }) {
    final isActive = activePlanetId == planetId;
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isActive
            ? null
            : () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop();
                onTravel(planetId);
              },
        child: Text(isActive ? 'CURRENT LOCATION' : 'TRAVEL HERE'),
      ),
    );
  }

  Widget _lockedLunarCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _requirementRow(
          'Homeworld mines ${view.homeworldMinesBuilt}/${view.homeworldMineTotal}',
          view.hasHomeworldMastery,
        ),
        _requirementRow(
          'Surveying ${view.requiredSurveyingLevel}',
          view.hasSurveying,
        ),
        _requirementRow('${view.lunarUnlockCashCost} cash', view.hasCash),
        const SizedBox(height: 8),
        SizedBox(
          key: const Key('mining-stellar-map-unlock'),
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: view.canUnlockLunar
                ? () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) navigator.pop();
                    onUnlockLunar();
                  }
                : null,
            child: Text('UNLOCK FOR ${view.lunarUnlockCashCost} CASH'),
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

  Widget _planetCard({
    required Key key,
    required String name,
    required bool isActive,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? Colors.cyanAccent : Colors.white24,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.public : Icons.public_outlined,
                color: isActive ? Colors.cyanAccent : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isActive)
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
          child,
        ],
      ),
    );
  }
}
