import 'package:flutter/material.dart';

enum MiningNavigationDestination { siteDeck, technology, stellarMap, settings }

class MiningNavigationBar extends StatelessWidget {
  const MiningNavigationBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
  });

  final MiningNavigationDestination selected;
  final ValueChanged<MiningNavigationDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mining-bottom-navigation'),
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xF20E1828),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          for (final destination in MiningNavigationDestination.values)
            Expanded(
              child: _DestinationButton(
                destination: destination,
                selected: destination == selected,
                onPressed: () => onDestinationSelected(destination),
              ),
            ),
        ],
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
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mining-nav-${destination.name}'),
          onTap: onPressed,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? Colors.cyanAccent.withAlpha(24) : null,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: Colors.cyanAccent.withAlpha(100))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _icon(destination),
                  size: 23,
                  color: selected ? Colors.cyanAccent : Colors.white60,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.cyanAccent : Colors.white70,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
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
