import 'package:flutter/material.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class MiningHud extends StatelessWidget {
  const MiningHud({
    super.key,
    required this.planetName,
    required this.cash,
    required this.commissionedSites,
    required this.totalSites,
    required this.cargo,
    required this.capacity,
    required this.cargoValue,
    required this.rate,
  });

  final String planetName;
  final int cash;
  final int commissionedSites;
  final int totalSites;
  final double cargo;
  final double capacity;
  final int cargoValue;
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mining-hud'),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          MiningCashChip(cash: cash),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planetName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MiningTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$commissionedSites/$totalSites ONLINE  ·  ${rate.toStringAsFixed(2)}/s',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MiningTheme.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          MiningCargoGauge(
            cargo: cargo,
            capacity: capacity,
            projectedValue: cargoValue,
          ),
        ],
      ),
    );
  }
}

class MiningCashChip extends StatelessWidget {
  const MiningCashChip({super.key, required this.cash});

  final int cash;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cash $cash',
      child: Container(
        key: const Key('mining-cash-chip'),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: ShapeDecoration(
          color: MiningTheme.warning.withAlpha(20),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: MiningTheme.warning.withAlpha(160)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              MiningVisuals.cashIcon,
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.monetization_on_rounded,
                color: MiningTheme.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$cash',
                  style: const TextStyle(
                    color: MiningTheme.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiningCargoGauge extends StatelessWidget {
  const MiningCargoGauge({
    super.key = const Key('mining-cargo-gauge'),
    required this.cargo,
    required this.capacity,
    required this.projectedValue,
    this.size = 72,
    this.onPressed,
    this.buttonKey,
    this.containerKey,
    this.semanticLabel,
  });

  final double cargo;
  final double capacity;
  final int projectedValue;
  final double size;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final Key? containerKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final progress = capacity <= 0 ? 0.0 : (cargo / capacity).clamp(0.0, 1.0);
    final label =
        semanticLabel ??
        'Cargo ${_amount(cargo)} of ${_amount(capacity)}, value $projectedValue cash';
    return Semantics(
      button: onPressed != null,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        key: containerKey,
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: MiningTheme.accent,
              backgroundColor: Colors.white12,
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: OutlinedButton(
                key: buttonKey,
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  side: BorderSide.none,
                  foregroundColor: MiningTheme.accent,
                  disabledForegroundColor: MiningTheme.mutedText,
                  backgroundColor: MiningTheme.panel.withAlpha(220),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      MiningVisuals.cargoIcon,
                      width: size < 68 ? 16 : 19,
                      height: size < 68 ? 16 : 19,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.inventory_2_rounded,
                        color: MiningTheme.accent,
                        size: size < 68 ? 16 : 19,
                      ),
                    ),
                    Text(
                      _amount(cargo),
                      maxLines: 1,
                      style: TextStyle(
                        color: MiningTheme.primaryText,
                        fontSize: size < 68 ? 9 : 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '+$projectedValue',
                      maxLines: 1,
                      style: TextStyle(
                        color: MiningTheme.warning,
                        fontSize: size < 68 ? 8 : 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
