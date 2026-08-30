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
  const MiningCashChip({super.key, required this.cash, this.compact = false});

  final int cash;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cash $cash',
      child: Container(
        key: const Key('mining-cash-chip'),
        height: compact ? 39 : null,
        constraints: BoxConstraints(minWidth: 76, minHeight: compact ? 39 : 46),
        padding: compact
            ? const EdgeInsets.fromLTRB(12, 9, 20, 9)
            : const EdgeInsets.fromLTRB(14, 11, 22, 11),
        decoration: ShapeDecoration(
          color: const Color.fromRGBO(255, 213, 74, .16),
          shape: _CashChipBorder(
            cut: compact ? .9 : .88,
            side: const BorderSide(
              color: Color.fromRGBO(255, 213, 74, .5),
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              MiningVisuals.cashIcon,
              width: compact ? 21 : 24,
              height: compact ? 21 : 24,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.monetization_on_rounded,
                color: MiningTheme.warning,
                size: compact ? 21 : 24,
              ),
            ),
            SizedBox(width: compact ? 8 : 9),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$cash',
                  style: TextStyle(
                    color: MiningTheme.warning,
                    fontSize: compact ? 19 : 22,
                    height: compact ? 1 : null,
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
    this.rate,
  });

  final double cargo;
  final double capacity;
  final int projectedValue;
  final double size;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final Key? containerKey;
  final String? semanticLabel;
  final double? rate;

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
            Padding(
              padding: const EdgeInsets.all(4.5),
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                color: MiningTheme.accent,
                backgroundColor: const Color.fromRGBO(255, 255, 255, .13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: OutlinedButton(
                key: buttonKey,
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  side: BorderSide.none,
                  foregroundColor: MiningTheme.accent,
                  disabledForegroundColor: MiningTheme.mutedText,
                  backgroundColor: const Color.fromRGBO(6, 10, 16, .72),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      MiningVisuals.cargoIcon,
                      width: size < 68 ? 16 : (size < 80 ? 18 : 20),
                      height: size < 68 ? 16 : (size < 80 ? 18 : 20),
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.inventory_2_rounded,
                        color: MiningTheme.accent,
                        size: size < 68 ? 16 : (size < 80 ? 18 : 20),
                      ),
                    ),
                    Text(
                      _amount(cargo),
                      maxLines: 1,
                      style: TextStyle(
                        color: MiningTheme.accent,
                        fontSize: size < 68 ? 9 : (size < 80 ? 12 : 14),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (rate case final value?)
                      Text(
                        '${value.toStringAsFixed(1)}/s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
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

class _CashChipBorder extends OutlinedBorder {
  const _CashChipBorder({this.cut = .88, super.side = BorderSide.none});

  final double cut;

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      _CashChipBorder(cut: cut, side: side ?? this.side);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..moveTo(rect.left, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.left + rect.width * cut, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.left + rect.width * cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom);
    canvas.drawPath(
      path,
      Paint()
        ..color = side.color
        ..strokeWidth = side.width
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => _CashChipBorder(cut: cut, side: side.scale(t));
}
