import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class TechnologySheet extends StatefulWidget {
  const TechnologySheet({
    super.key,
    required this.view,
    required this.onPurchase,
  });
  final TechnologySheetView view;
  final ValueChanged<TechnologyTrack> onPurchase;

  @override
  State<TechnologySheet> createState() => _TechnologySheetState();
}

class _TechnologySheetState extends State<TechnologySheet> {
  TechnologyTrack _selected = TechnologyTrack.extraction;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final selected = widget.view.track(_selected);
    return MiningSheetFrame(
      key: const Key('mining-technology-sheet'),
      title: 'Technology',
      icon: _trackIcon(TechnologyTrack.extraction),
      trailing: Text(
        landscape ? 'gate site, then cash · max LV 5' : 'MAX LV 5',
        style: const TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: Colors.white54,
          fontSize: 10,
        ),
      ),
      child: Column(
        children: [
          _tree(landscape),
          const SizedBox(height: 12),
          _compactDetails(selected),
        ],
      ),
    );
  }

  Widget _tree(bool horizontal) => LayoutBuilder(
    builder: (context, constraints) {
      final width = horizontal ? 482.0 : constraints.maxWidth;
      final height = horizontal
          ? 196.0
          : (MediaQuery.sizeOf(context).height - 361).clamp(
              500.0,
              double.infinity,
            );
      final tree = SizedBox(
        key: const Key('technology-tree'),
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TechnologyLinks(widget.view.tracks, horizontal),
              ),
            ),
            for (var index = 0; index < widget.view.tracks.length; index++) ...[
              Positioned(
                left: horizontal ? 70 : width * (index + .5) / 3 - 58,
                top: horizontal ? index * 66.0 + 14 : 0,
                width: horizontal ? 36 : 116,
                height: horizontal ? 48 : 48,
                child: Semantics(
                  selected: _selected == widget.view.tracks[index].track,
                  label: horizontal ? widget.view.tracks[index].name : null,
                  child: InkWell(
                    key: Key(
                      'technology-track-${widget.view.tracks[index].track.name}',
                    ),
                    onTap: () => setState(
                      () => _selected = widget.view.tracks[index].track,
                    ),
                    child: Column(
                      children: [
                        _trackIcon(widget.view.tracks[index].track),
                        if (!horizontal) ...[
                          const SizedBox(height: 5),
                          Text(
                            widget.view.tracks[index].name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 8.5,
                              height: 1,
                              letterSpacing: .85,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              for (var step = 0; step < 5; step++)
                Positioned(
                  left: horizontal
                      ? 106 + step * 70.0
                      : width * (index + .5) / 3 - 26,
                  top: horizontal ? 14 + index * 66.0 : 39 + step * 76.0,
                  width: horizontal ? 48 : 52,
                  height: horizontal ? 48 : 58,
                  child: _node(
                    widget.view.tracks[index],
                    horizontal ? step + 1 : 5 - step,
                    horizontal,
                  ),
                ),
            ],
            Positioned(
              left: horizontal ? 3 : width / 2 - 32,
              top: horizontal ? 74 : 427,
              width: horizontal ? 54 : 64,
              height: horizontal ? 60 : 70,
              child: SizedBox(
                key: const Key('technology-root'),
                child: MiningHex(
                  fill: const Color(0xFF0E1828),
                  border: MiningTheme.accent.withAlpha(128),
                  child: Image.asset(
                    MiningContentRegistry.stellarMining()
                        .planet(MiningPlanetId.homeworld)
                        .planetAsset,
                    width: horizontal ? 27 : 32,
                    height: horizontal ? 27 : 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return horizontal
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: tree)
          : tree;
    },
  );

  Widget _node(TechnologyTrackView track, int level, bool horizontal) {
    final owned = level <= track.level;
    final next = level == track.level + 1;
    final highlight = next && track.isGateSatisfied;
    final color = owned
        ? MiningTheme.accent
        : next
        ? (track.isGateSatisfied ? MiningTheme.warning : MiningTheme.gate)
        : Colors.white24;
    return Center(
      child: Transform.scale(
        scale: highlight ? (horizontal ? 1.09 : 1.12) : 1,
        child: Container(
          width: horizontal ? 48 : 52,
          height: horizontal ? 48 : 58,
          decoration: highlight
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MiningTheme.warning.withAlpha(80),
                      blurRadius: 26,
                    ),
                  ],
                )
              : null,
          child: MiningHex(
            key: Key('technology-node-${track.track.name}-$level'),
            fill: owned ? MiningTheme.accent : const Color(0xFF0E1828),
            border: color,
            semanticLabel:
                '${track.name} level $level, ${owned
                    ? 'owned'
                    : next
                    ? (track.isGateSatisfied ? 'next' : 'gated')
                    : 'locked'}',
            onTap: () => setState(() => _selected = track.track),
            child: next && !track.isGateSatisfied
                ? Icon(
                    Icons.lock_outline,
                    color: color,
                    size: horizontal ? 18 : 19,
                  )
                : Text(
                    '$level',
                    style: TextStyle(
                      color: owned ? const Color(0xFF04121A) : color,
                      fontFamily: 'Orbitron',
                      fontSize: horizontal
                          ? 14
                          : highlight
                          ? 18
                          : 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _compactDetails(TechnologyTrackView track) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical:
          MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
          ? 8
          : 11,
    ),
    decoration: BoxDecoration(
      color: MiningTheme.warning.withAlpha(22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MiningTheme.warning.withAlpha(115)),
    ),
    child: Row(
      children: [
        _trackIcon(track.track),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (track.track == TechnologyTrack.extraction)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        track.currentEffect.replaceFirst('Mining rate ', ''),
                        semanticsLabel: track.currentEffect,
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                        ),
                      ),
                      if (track.nextEffect != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 7),
                          child: Icon(
                            Icons.east,
                            size: 16,
                            color: MiningTheme.warning,
                          ),
                        ),
                        Text(
                          track.nextEffect!.replaceFirst('Mining rate ', ''),
                          semanticsLabel: 'Next: ${track.nextEffect}',
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                Text(
                  track.currentEffect,
                  style: const TextStyle(
                    color: MiningTheme.accent,
                    fontSize: 11,
                  ),
                ),
                if (track.nextEffect != null)
                  Text(
                    'Next: ${track.nextEffect}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
              ],
              if (track.gateSiteName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      track.isGateSatisfied
                          ? Icons.check_circle
                          : Icons.lock_outline,
                      size: 13,
                      color: track.isGateSatisfied
                          ? MiningTheme.accent
                          : MiningTheme.gate,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        track.isGateSatisfied
                            ? track.gateSiteName!
                            : 'Commission ${track.gateSiteName}',
                        style: TextStyle(
                          fontSize: 10,
                          color: track.isGateSatisfied
                              ? Colors.white54
                              : MiningTheme.gate,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (track.isGateSatisfied && !track.isAffordable)
                Text(
                  track.disabledReason!,
                  style: const TextStyle(color: MiningTheme.gate, fontSize: 10),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 104, child: _purchaseButton(track)),
      ],
    ),
  );

  Widget _purchaseButton(TechnologyTrackView track) => SizedBox(
    key: Key('mining-technology-buy-${track.track.name}'),
    width: double.infinity,
    height: MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
        ? 48
        : 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: MiningTheme.warning.withAlpha(45),
        foregroundColor: MiningTheme.warning,
        side: const BorderSide(color: MiningTheme.warning, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: track.canPurchase
          ? () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) navigator.pop();
              widget.onPurchase(track.track);
            }
          : null,
      child: track.isMaxLevel
          ? const Text('Max Level')
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  MiningVisuals.cashIcon,
                  width: 17,
                  height: 17,
                  errorBuilder: (_, _, _) => const Icon(Icons.paid),
                ),
                const SizedBox(width: 8),
                Text(
                  '${track.cost}',
                  semanticsLabel: 'Upgrade for ${track.cost} cash',
                ),
              ],
            ),
    ),
  );

  Widget _trackIcon(TechnologyTrack track) => Image.asset(
    switch (track) {
      TechnologyTrack.extraction => MiningVisuals.extractionIcon,
      TechnologyTrack.logistics => MiningVisuals.logisticsIcon,
      TechnologyTrack.surveying => MiningVisuals.surveyingIcon,
    },
    width: 28,
    height: 28,
    errorBuilder: (_, _, _) =>
        const Icon(Icons.science_outlined, color: MiningTheme.accent),
  );
}

// The authored tree has fixed node spacing; only portrait column centers expand.
class _TechnologyLinks extends CustomPainter {
  const _TechnologyLinks(this.tracks, this.horizontal);
  final List<TechnologyTrackView> tracks;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    void line(Offset a, Offset b, Color color, {bool dashed = false}) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2;
      if (!dashed) {
        canvas.drawLine(a, b, paint);
        return;
      }
      final distance = (b - a).distance;
      for (double at = 0; at < distance; at += 8) {
        canvas.drawLine(
          Offset.lerp(a, b, at / distance)!,
          Offset.lerp(a, b, ((at + 4).clamp(0, distance)) / distance)!,
          paint,
        );
      }
    }

    final base = MiningTheme.accent.withAlpha(128);
    for (var col = 0; col < tracks.length; col++) {
      final track = tracks[col];
      for (var step = 0; step < 4; step++) {
        final upper = horizontal ? step + 2 : 5 - step;
        final next = upper == track.level + 1;
        final color = upper <= track.level
            ? base
            : next
            ? (track.isGateSatisfied ? MiningTheme.warning : MiningTheme.gate)
                  .withAlpha(210)
            : Colors.white.withAlpha(33);
        line(
          horizontal
              ? Offset(152 + step * 70.0, 38 + col * 66.0)
              : Offset(size.width * (col + .5) / 3, 97 + step * 76.0),
          horizontal
              ? Offset(178 + step * 70.0, 38 + col * 66.0)
              : Offset(size.width * (col + .5) / 3, 115 + step * 76.0),
          color,
          dashed: next,
        );
      }
      if (horizontal) {
        line(Offset(70, 38 + col * 66.0), Offset(108, 38 + col * 66.0), base);
      } else {
        line(
          Offset(size.width * (col + .5) / 3, 401),
          Offset(size.width * (col + .5) / 3, 420),
          base,
        );
      }
    }
    if (horizontal) {
      line(const Offset(70, 38), const Offset(70, 170), base);
      line(const Offset(57, 104), const Offset(70, 104), base);
    } else {
      line(Offset(size.width / 6, 420), Offset(size.width * 5 / 6, 420), base);
      line(Offset(size.width / 2, 420), Offset(size.width / 2, 427), base);
    }
  }

  @override
  bool shouldRepaint(_TechnologyLinks old) =>
      old.tracks != tracks || old.horizontal != horizontal;
}
