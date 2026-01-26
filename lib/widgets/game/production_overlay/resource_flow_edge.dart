/// Resource flow edge widget for the production overlay.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/production/production_graph.dart';

/// Widget representing a directed edge between two building nodes.
/// Includes animated flow indicator showing resource direction.
class ResourceFlowEdgeWidget extends StatefulWidget {
  final ResourceFlowEdge edge;
  final BuildingNode? startNode;
  final BuildingNode? endNode;

  const ResourceFlowEdgeWidget({
    super.key,
    required this.edge,
    this.startNode,
    this.endNode,
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
      return const SizedBox.shrink();
    }

    // Calculate edge positions (from right side of start to left side of end)
    const nodeWidth = 120.0;
    const nodeHeight = 80.0;

    final startX = widget.startNode!.position.dx + nodeWidth;
    final startY = widget.startNode!.position.dy + nodeHeight / 2;
    final endX = widget.endNode!.position.dx;
    final endY = widget.endNode!.position.dy + nodeHeight / 2;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size((endX - startX).abs() + 50, (endY - startY).abs() + 50),
          painter: _EdgePainter(
            startOffset: Offset(startX, startY),
            endOffset: Offset(endX, endY),
            status: widget.edge.status,
            isHighlighted: widget.edge.isHighlighted,
            isIncomplete: widget.edge.isIncomplete,
            rate: widget.edge.ratePerSecond,
            resourceName: widget.edge.resourceType.name,
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
  final String resourceName;
  final double animationProgress;

  _EdgePainter({
    required this.startOffset,
    required this.endOffset,
    required this.status,
    required this.isHighlighted,
    required this.isIncomplete,
    required this.rate,
    required this.resourceName,
    this.animationProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = _getStatusColor();
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
    final distance = (dx * dx + dy * dy);
    if (distance == 0) return;

    final length = distance > 0 ? (distance).abs() : 1.0;
    final unitX = dx / length;
    final unitY = dy / length;

    var currentX = start.dx;
    var currentY = start.dy;
    var drawn = 0.0;

    while (drawn < length) {
      final dashEnd = (drawn + dashWidth).clamp(0, length);
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
    final angle = dx != 0 || dy != 0 ? (dy / dx).abs() : 0.0;

    const arrowSize = 10.0;
    final arrowAngle = angle * 0.5;

    final arrowPath = Path();
    arrowPath.moveTo(endOffset.dx, endOffset.dy);
    arrowPath.lineTo(
      endOffset.dx - arrowSize * (1 + arrowAngle),
      endOffset.dy - arrowSize / 2,
    );
    arrowPath.lineTo(
      endOffset.dx - arrowSize * (1 + arrowAngle),
      endOffset.dy + arrowSize / 2,
    );
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
        color: _getStatusColor(),
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

    // Draw small status indicator icon
    final iconPaint = Paint()
      ..color = _getStatusColor()
      ..style = PaintingStyle.fill;

    switch (status) {
      case FlowStatus.surplus:
        // Checkmark
        final path = Path();
        path.moveTo(iconPosition.dx - 4, iconPosition.dy);
        path.lineTo(iconPosition.dx - 1, iconPosition.dy + 3);
        path.lineTo(iconPosition.dx + 4, iconPosition.dy - 2);
        canvas.drawPath(
          path,
          iconPaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case FlowStatus.balanced:
        // Dash
        canvas.drawLine(
          Offset(iconPosition.dx - 4, iconPosition.dy),
          Offset(iconPosition.dx + 4, iconPosition.dy),
          iconPaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case FlowStatus.deficit:
        // X mark
        final path = Path();
        path.moveTo(iconPosition.dx - 3, iconPosition.dy - 3);
        path.lineTo(iconPosition.dx + 3, iconPosition.dy + 3);
        path.moveTo(iconPosition.dx + 3, iconPosition.dy - 3);
        path.lineTo(iconPosition.dx - 3, iconPosition.dy + 3);
        canvas.drawPath(
          path,
          iconPaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case FlowStatus.surplus:
        return const Color(0xFF4CAF50); // Green
      case FlowStatus.balanced:
        return const Color(0xFFFFEB3B); // Yellow
      case FlowStatus.deficit:
        return const Color(0xFFF44336); // Red
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
