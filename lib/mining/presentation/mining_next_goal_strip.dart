import 'package:flutter/material.dart';
import 'package:horologium/mining/next_goal_view.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

/// Site Deck strip naming the one next progression goal. It only reports the
/// goal's target through [onSelected]; it never derives goal legality.
class MiningNextGoalStrip extends StatelessWidget {
  const MiningNextGoalStrip({
    super.key,
    required this.goal,
    required this.onSelected,
    this.compact = false,
  });

  final MiningNextGoalView goal;

  /// Null leaves the strip informational: no chevron, button role, or tap.
  final ValueChanged<MiningGoalTarget>? onSelected;

  /// Single-line 48 px variant for the landscape Site Deck.
  final bool compact;

  /// Above this text scale the two-line layout no longer fits the 56 px
  /// portrait slot, so the strip switches to its single-line layout and drops
  /// the inline cash label; the progress bar and semantics label keep it.
  static const _twoLineMaxTextScale = 1.3;

  /// The strip is fixed-height chrome, so its text stops growing here.
  static const _maxTextScale = 2.0;

  static const _labelStyle = TextStyle(
    color: MiningTheme.accent,
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 1,
  );
  static const _titleStyle = TextStyle(
    color: MiningTheme.primaryText,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: _maxTextScale,
    child: Builder(builder: _buildStrip),
  );

  Widget _buildStrip(BuildContext context) {
    final select = onSelected;
    final onTap = goal.target.isNavigable && select != null
        ? () => select(goal.target)
        : null;
    final navigable = onTap != null;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > _twoLineMaxTextScale;
    final detailStyle = TextStyle(
      color: goal.sellWouldAfford
          ? MiningTheme.warning
          : MiningTheme.secondaryText,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final cashLabel = compact || !largeText ? goal.cashLabel : null;
    final progress = goal.progress;

    final text = compact || largeText
        ? Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'NEXT GOAL  ', style: _labelStyle),
                TextSpan(text: goal.title, style: _titleStyle),
                TextSpan(text: '  ·  ${goal.detail}', style: detailStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'NEXT GOAL  ', style: _labelStyle),
                    TextSpan(text: goal.title, style: _titleStyle),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                goal.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: detailStyle,
              ),
            ],
          );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: navigable,
      onTap: onTap,
      label: goal.semanticsLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: compact ? 48 : 56,
            padding: EdgeInsets.fromLTRB(10, 4, navigable ? 4 : 10, 4),
            decoration: BoxDecoration(
              color: MiningTheme.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MiningTheme.accent.withAlpha(110)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: MiningTheme.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: text),
                      if (cashLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          cashLabel,
                          key: const Key('next-goal-cash'),
                          maxLines: 1,
                          style: TextStyle(
                            color: goal.isReady
                                ? MiningTheme.accent
                                : MiningTheme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (navigable)
                        const Icon(
                          Icons.chevron_right_rounded,
                          key: Key('next-goal-chevron'),
                          color: MiningTheme.secondaryText,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                if (progress != null)
                  Padding(
                    padding: EdgeInsets.only(right: navigable ? 6 : 0),
                    child: _ProgressTrack(progress: progress),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static fill with no implicit animation, so reduced motion needs no case.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('next-goal-progress-track'),
    height: 3,
    width: double.infinity,
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          key: const Key('next-goal-progress-fill'),
          widthFactor: progress,
          heightFactor: 1,
          child: const ColoredBox(color: MiningTheme.accent),
        ),
      ),
    ),
  );
}
