import 'package:flutter/material.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';

enum MiningNavigationDestination { siteDeck, technology, stellarMap, settings }

class MiningNavigationBar extends StatelessWidget {
  const MiningNavigationBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    this.compact = false,
  });

  final MiningNavigationDestination selected;
  final ValueChanged<MiningNavigationDestination> onDestinationSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mining-bottom-navigation'),
      height: compact ? 54 : 88,
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? 0 : 26),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final destination in MiningNavigationDestination.values)
              SizedBox(
                width: compact ? 48 : 56,
                height: compact ? 54 : 62,
                child: _DestinationButton(
                  destination: destination,
                  selected: destination == selected,
                  onPressed: () => onDestinationSelected(destination),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final MiningNavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _label(destination);
    return Semantics(
      selected: selected,
      child: MiningHex(
        fill: selected
            ? Colors.cyanAccent.withAlpha(28)
            : const Color(0xD90E1828),
        border: selected ? Colors.cyanAccent : Colors.cyan.withAlpha(76),
        onTap: onPressed,
        semanticLabel: label,
        child: SizedBox.expand(
          key: Key('mining-nav-${destination.name}'),
          child: Icon(
            _icon(destination),
            semanticLabel: label,
            size: 25,
            color: selected ? Colors.cyanAccent : Colors.white60,
          ),
        ),
      ),
    );
  }

  static IconData _icon(MiningNavigationDestination destination) {
    switch (destination) {
      case MiningNavigationDestination.siteDeck:
        return Icons.dashboard_rounded;
      case MiningNavigationDestination.technology:
        return Icons.biotech_rounded;
      case MiningNavigationDestination.stellarMap:
        return Icons.public_rounded;
      case MiningNavigationDestination.settings:
        return Icons.settings_rounded;
    }
  }

  static String _label(MiningNavigationDestination destination) {
    switch (destination) {
      case MiningNavigationDestination.siteDeck:
        return 'Site Deck';
      case MiningNavigationDestination.technology:
        return 'Technology';
      case MiningNavigationDestination.stellarMap:
        return 'Stellar Map';
      case MiningNavigationDestination.settings:
        return 'Settings';
    }
  }
}
