/// Resource flow edge widget for the production overlay.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/widgets/game/production_overlay/production_theme.dart';

/// Widget representing a directed edge between two building nodes.
/// Includes animated flow indicator showing resource direction.
class ResourceFlowEdgeWidget extends StatefulWidget {
  final ResourceFlowEdge edge;
  final BuildingNode? startNode;
  final BuildingNode? endNode;
  final bool isIncomplete;

  const ResourceFlowEdgeWidget({
    super.key,
    required this.edge,
    this.startNode,
    this.endNode,
    this.isIncomplete = false,
  });

  @override
  State<ResourceFlowEdgeWidget> createState() => _ResourceFlowEdgeWidgetState();
}

class _ResourceFlowEdgeWidgetState extends State<ResourceFlowEdgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startNode == null || widget.endNode == null) {
      debugPrint(
        'Warning: ResourceFlowEdgeWidget missing node(s) for edge ${widget.edge.id} '
        '(producer: ${widget.edge.producerNodeId}, consumer: ${widget.edge.consumerNodeId})',
      );
      return const SizedBox.shrink();
    }

    // Calculate edge positions
    final isIncomplete =
        widget.isIncomplete || (widget.startNode!.id == widget.endNode!.id);

    late final double startX;
    late final double startY;
    late final double endX;
    late final double endY;

    if (isIncomplete) {
      // For incomplete edges, draw a stub from the right side extending outward
      startX = widget.startNode!.position.dx + ProductionTheme.nodeWidth;
      startY = widget.startNode!.position.dy + ProductionTheme.nodeHeight / 2;
      endX = startX + ProductionTheme.nodeWidth * 0.8;
      endY = startY + ProductionTheme.nodeHeight * 0.5;
    } else {
      // Normal edge: from right side of start to left side of end
      startX = widget.startNode!.position.dx + ProductionTheme.nodeWidth;
      startY = widget.startNode!.position.dy + ProductionTheme.nodeHeight / 2;
      endX = widget.endNode!.position.dx;
      endY = widget.endNode!.position.dy + ProductionTheme.nodeHeight / 2;
    }

    // Calculate bounding box for local coordinates
    final minX = min(startX, endX);
    final minY = min(startY, endY);
    final maxX = max(startX, endX);
    final maxY = max(startY, endY);

    // Convert to local coordinates within the CustomPaint
    final localStartX = startX - minX + ProductionTheme.edgePadding / 2;
    final localStartY = startY - minY + ProductionTheme.edgePadding / 2;
    final localEndX = endX - minX + ProductionTheme.edgePadding / 2;
    final localEndY = endY - minY + ProductionTheme.edgePadding / 2;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(
            maxX - minX + ProductionTheme.edgePadding,
            maxY - minY + ProductionTheme.edgePadding,
          ),
          painter: _EdgePainter(
            startOffset: Offset(localStartX, localStartY),
            endOffset: Offset(localEndX, localEndY),
            status: widget.edge.status,
            isHighlighted: widget.edge.isHighlighted,
            isIncomplete: widget.edge.isIncomplete,
            rate: widget.edge.ratePerSecond,
            animationProgress: _animationController.value,
          ),
        );
      },
    );
  }
}

class _EdgePainter extends CustomPainter {
  final Offset startOffset;
  final Offset endOffset;
  final FlowStatus status;
  final bool isHighlighted;
  final bool isIncomplete;
  final double rate;
  final double animationProgress;

  _EdgePainter({
    required this.startOffset,
    required this.endOffset,
    required this.status,
    required this.isHighlighted,
    required this.isIncomplete,
    required this.rate,
    this.animationProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = ProductionTheme.getStatusColor(status);
    final paint = Paint()
      ..color = isHighlighted ? color : color.withAlpha(128)
      ..strokeWidth = isHighlighted ? 3 : 2
      ..style = PaintingStyle.stroke;

    // Dashed line for incomplete chains
    if (isIncomplete) {
      _drawDashedLine(canvas, startOffset, endOffset, paint);
    } else {
      canvas.drawLine(startOffset, endOffset, paint);
    }

    // Draw animated flow dots
    _drawFlowAnimation(canvas, color);

    // Draw arrowhead
    _drawArrowhead(canvas, paint);

    // Draw rate label at midpoint
    _drawRateLabel(canvas);

    // Draw status icon
    _drawStatusIcon(canvas);
  }

  void _drawFlowAnimation(Canvas canvas, Color color) {
    // Draw 3 animated dots moving along the edge
    const dotCount = 3;
    const dotRadius = 3.0;

    final dx = endOffset.dx - startOffset.dx;
    final dy = endOffset.dy - startOffset.dy;

    for (var i = 0; i < dotCount; i++) {
      // Stagger the dots evenly along the animation cycle
      final progress = (animationProgress + i / dotCount) % 1.0;

      // Position along the line
      final dotX = startOffset.dx + dx * progress;
      final dotY = startOffset.dy + dy * progress;

      // Fade dots at edges for smoother appearance
      final edgeFade = (progress < 0.1)
          ? progress / 0.1
          : (progress > 0.9)
          ? (1.0 - progress) / 0.1
          : 1.0;

      final dotPaint = Paint()
        ..color = color.withAlpha((200 * edgeFade).round())
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 10.0;
    const dashSpace = 5.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    var currentX = start.dx;
    var currentY = start.dy;
    var drawn = 0.0;

    while (drawn < distance) {
      final dashEnd = (drawn + dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        Offset(currentX, currentY),
        Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
        paint,
      );

      drawn = dashEnd + dashSpace;
      currentX = start.dx + unitX * drawn;
      currentY = start.dy + unitY * drawn;
    }
  }

  void _drawArrowhead(Canvas canvas, Paint paint) {
    final dx = endOffset.dx - startOffset.dx;
    final dy = endOffset.dy - startOffset.dy;
    final angle = atan2(dy, dx);

    const arrowSize = 10.0;
    const arrowSpread = 0.4; // ~23 degrees in radians

    // Calculate the two points of the arrowhead
    final arrowPoint1 = Offset(
      endOffset.dx - arrowSize * cos(angle - arrowSpread),
      endOffset.dy - arrowSize * sin(angle - arrowSpread),
    );
    final arrowPoint2 = Offset(
      endOffset.dx - arrowSize * cos(angle + arrowSpread),
      endOffset.dy - arrowSize * sin(angle + arrowSpread),
    );

    final arrowPath = Path();
    arrowPath.moveTo(endOffset.dx, endOffset.dy);
    arrowPath.lineTo(arrowPoint1.dx, arrowPoint1.dy);
    arrowPath.lineTo(arrowPoint2.dx, arrowPoint2.dy);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawRateLabel(Canvas canvas) {
    final midpoint = Offset(
      (startOffset.dx + endOffset.dx) / 2,
      (startOffset.dy + endOffset.dy) / 2 - 12,
    );

    final textSpan = TextSpan(
      text: '${rate.toStringAsFixed(1)}/s',
      style: TextStyle(
        color: ProductionTheme.getStatusColor(status),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Background for readability
    final bgRect = Rect.fromCenter(
      center: midpoint,
      width: textPainter.width + 8,
      height: textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = Colors.black87,
    );

    textPainter.paint(
      canvas,
      Offset(
        midpoint.dx - textPainter.width / 2,
        midpoint.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStatusIcon(Canvas canvas) {
    final iconPosition = Offset(
      (startOffset.dx + endOffset.dx) / 2,
      (startOffset.dy + endOffset.dy) / 2 + 8,
    );

    final baseColor = ProductionTheme.getStatusColor(status);

    switch (status) {
      case FlowStatus.surplus:
        // Checkmark
        final path = Path();
        path.moveTo(iconPosition.dx - 4, iconPosition.dy);
        path.lineTo(iconPosition.dx - 1, iconPosition.dy + 3);
        path.lineTo(iconPosition.dx + 4, iconPosition.dy - 2);
        canvas.drawPath(
          path,
          Paint()
            ..color = baseColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        break;
      case FlowStatus.balanced:
        // Dash
        canvas.drawLine(
          Offset(iconPosition.dx - 4, iconPosition.dy),
          Offset(iconPosition.dx + 4, iconPosition.dy),
          Paint()
            ..color = baseColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        break;
      case FlowStatus.deficit:
        // X mark
        final path = Path();
        path.moveTo(iconPosition.dx - 3, iconPosition.dy - 3);
        path.lineTo(iconPosition.dx + 3, iconPosition.dy + 3);
        path.moveTo(iconPosition.dx + 3, iconPosition.dy - 3);
        path.lineTo(iconPosition.dx - 3, iconPosition.dy + 3);
        canvas.drawPath(
          path,
          Paint()
            ..color = baseColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        break;
      case FlowStatus.unknown:
        // Question mark (circle for simplicity)
        canvas.drawCircle(
          iconPosition,
          4,
          Paint()
            ..color = baseColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return startOffset != oldDelegate.startOffset ||
        endOffset != oldDelegate.endOffset ||
        status != oldDelegate.status ||
        isHighlighted != oldDelegate.isHighlighted ||
        isIncomplete != oldDelegate.isIncomplete ||
        rate != oldDelegate.rate ||
        animationProgress != oldDelegate.animationProgress;
  }
}
