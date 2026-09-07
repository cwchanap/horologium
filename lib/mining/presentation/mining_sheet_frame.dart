import 'package:flutter/material.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// Bottom sheet in portrait, right-hand navigation panel in landscape.
class MiningSheetFrame extends StatelessWidget {
  const MiningSheetFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.portraitHeight,
    this.portraitTabOnRight = false,
  });
  final String title;
  final Widget icon;
  final Widget child;
  final Widget? trailing;
  final double? portraitHeight;
  final bool portraitTabOnRight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final pad = MediaQuery.paddingOf(context);
    return Align(
      alignment: Alignment.bottomRight,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: landscape ? 556 : double.infinity,
          maxHeight: landscape
              ? size.height
              : (size.height - 160).clamp(180, double.infinity),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: landscape ? 28 : 0,
                top: landscape ? 0 : 30,
              ),
              child: Container(
                key: const Key('mining-sheet-panel'),
                height: landscape ? size.height : portraitHeight,
                decoration: BoxDecoration(
                  color: MiningTheme.panel,
                  borderRadius: landscape
                      ? null
                      : const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: MiningTheme.accent.withAlpha(100)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 32),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      landscape ? 30 : 14,
                      landscape ? 52 : 26,
                      landscape ? 16 : 14,
                      landscape ? 14 : 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: landscape ? 46 : null,
                          child: Padding(
                            padding: EdgeInsets.only(right: landscape ? 60 : 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: MiningTheme.accent,
                                      fontSize: landscape ? 21 : 23,
                                      height: 1.1,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (trailing != null) trailing!,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                          child: child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!landscape)
              Positioned(
                top: 41,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MiningTheme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            Positioned(
              key: const Key('mining-sheet-close-tab'),
              top: landscape ? 58 : 0,
              left: landscape
                  ? 0
                  : portraitTabOnRight
                  ? null
                  : 24,
              right: !landscape && portraitTabOnRight ? 26 : null,
              child: SizedBox(
                width: 56,
                height: 62,
                child: MiningHex(
                  fill: const Color(0xFF0E1828),
                  border: MiningTheme.highlight,
                  semanticLabel: !landscape && portraitTabOnRight
                      ? 'Close $title'
                      : null,
                  onTap: !landscape && portraitTabOnRight
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  child: icon,
                ),
              ),
            ),
            if (landscape || !portraitTabOnRight)
              Positioned(
                top: landscape ? 52 : 0,
                right: 14 + pad.right,
                child: SizedBox(
                  width: 52,
                  height: landscape ? 54 : 58,
                  child: MiningHex(
                    fill: const Color(0xFF060A10),
                    border: MiningTheme.accent.withAlpha(100),
                    semanticLabel: 'Close $title',
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.close, color: Colors.white60),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Scene artwork and HUD stay separate from the sheet and its dimming layer.
class MiningSheetScene extends StatelessWidget {
  const MiningSheetScene({
    super.key,
    required this.child,
    required this.backgroundAsset,
    required this.destination,
    required this.cash,
    required this.cargo,
    required this.capacity,
    required this.onDestinationSelected,
  });
  final Widget child;
  final String backgroundAsset;
  final MiningNavigationDestination destination;
  final int cash;
  final double cargo;
  final double capacity;
  final ValueChanged<MiningNavigationDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final settings = destination == MiningNavigationDestination.settings;
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: const Color(0xFF060A10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: landscape
                ? 1
                : settings
                ? .42
                : .5,
            child: Image.asset(
              backgroundAsset,
              key: const Key('mining-sheet-background'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF060A10)),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: landscape ? Alignment.centerLeft : Alignment.topCenter,
                end: landscape ? Alignment.centerRight : Alignment.bottomCenter,
                colors: landscape
                    ? const [
                        Color(0xE0060A10),
                        Color(0x66060A10),
                        Color(0xB8060A10),
                        Color(0xE6060A10),
                      ]
                    : settings
                    ? const [
                        Color(0x9E060A10),
                        Color(0xEB060A10),
                        Color(0xF7060A10),
                      ]
                    : const [
                        Color(0x99060A10),
                        Color(0xE6060A10),
                        Color(0xF5060A10),
                      ],
                stops: landscape
                    ? const [0, .22, .44, .6]
                    : settings
                    ? const [0, .42, 1]
                    : const [0, .46, 1],
              ),
            ),
          ),
          Positioned(
            left: pad.left,
            top: (landscape ? 52 : 54) + pad.top,
            child: MiningCashChip(cash: cash, compact: landscape),
          ),
          if (!landscape)
            Positioned(
              right: 12 + pad.right,
              top: 50 + pad.top,
              child: MiningCargoGauge(
                cargo: cargo,
                capacity: capacity,
                projectedValue: 0,
                size: 80,
              ),
            ),
          if (landscape)
            Positioned(
              left: 12 + pad.left,
              bottom: 16 + pad.bottom,
              width: 252,
              height: 54,
              child: MiningNavigationBar(
                compact: true,
                selected: destination,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
          Positioned(left: 0, right: 0, bottom: 0, child: child),
        ],
      ),
    );
  }
}
