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
      height: 64,
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final destination in MiningNavigationDestination.values)
            SizedBox(
              width: 68,
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
        color: selected
            ? Colors.cyanAccent.withAlpha(28)
            : const Color(0xD90E1828),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Colors.cyanAccent : Colors.white24,
          ),
        ),
        child: InkWell(
          key: Key('mining-nav-${destination.name}'),
          onTap: onPressed,
          customBorder: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 54,
            child: Icon(
              _icon(destination),
              semanticLabel: label,
              size: 25,
              color: selected ? Colors.cyanAccent : Colors.white60,
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
