import 'package:flutter/material.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

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
            ? const Color.fromRGBO(24, 255, 255, .16)
            : const Color.fromRGBO(6, 10, 16, .86),
        border: selected
            ? MiningTheme.highlight
            : const Color.fromRGBO(83, 212, 232, .3),
        onTap: onPressed,
        semanticLabel: label,
        child: SizedBox.expand(
          key: Key('mining-nav-${destination.name}'),
          child: _graphic(destination, selected, label),
        ),
      ),
    );
  }

  static Widget _graphic(
    MiningNavigationDestination destination,
    bool selected,
    String label,
  ) {
    final color = selected ? MiningTheme.highlight : Colors.white54;
    switch (destination) {
      case MiningNavigationDestination.siteDeck:
        return Icon(
          Icons.grid_view_rounded,
          semanticLabel: label,
          size: 25,
          color: color,
        );
      case MiningNavigationDestination.technology:
        return Image.asset(MiningVisuals.extractionIcon, width: 26, height: 26);
      case MiningNavigationDestination.stellarMap:
        return Image.asset(
          'assets/images/mining/planets/lunar_frontier.png',
          width: 28,
          height: 28,
          opacity: selected ? null : const AlwaysStoppedAnimation(.62),
        );
      case MiningNavigationDestination.settings:
        return Icon(
          Icons.tune_rounded,
          semanticLabel: label,
          size: 25,
          color: color,
        );
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
