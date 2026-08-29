import 'package:flutter/material.dart';

class MiningHex extends StatelessWidget {
  const MiningHex({
    super.key,
    required this.child,
    required this.fill,
    required this.border,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final Color fill;
  final Color border;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel,
      child: CustomPaint(
        painter: _HexBorderPainter(fill: fill, border: border),
        child: ClipPath(
          clipper: const _HexClipper(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => _hexPath(size);

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}

class _HexBorderPainter extends CustomPainter {
  const _HexBorderPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_HexBorderPainter oldDelegate) =>
      fill != oldDelegate.fill || border != oldDelegate.border;
}

Path _hexPath(Size size) => Path()
  ..moveTo(size.width / 2, 0)
  ..lineTo(size.width, size.height * .25)
  ..lineTo(size.width, size.height * .75)
  ..lineTo(size.width / 2, size.height)
  ..lineTo(0, size.height * .75)
  ..lineTo(0, size.height * .25)
  ..close();
