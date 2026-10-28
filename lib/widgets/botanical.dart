import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Which plant to draw.
enum BotanicalKind {
  /// A thin stem with alternating leaves.
  sprig,

  /// A single fan-shaped ginkgo leaf.
  ginkgo,

  /// A bamboo stem with two narrow leaves.
  bamboo,

  /// A small branch with a blossom.
  blossom,
}

/// A single, delicate line drawing of a plant. One per major section, placed
/// slightly off-centre; purely decorative, so it is hidden from screen
/// readers.
class Botanical extends StatelessWidget {
  const Botanical({
    super.key,
    this.kind = BotanicalKind.sprig,
    this.size = 72,
    this.color,
    this.mirrored = false,
    this.opacity = 0.9,
  });

  final BotanicalKind kind;
  final double size;
  final Color? color;
  final bool mirrored;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget drawing = CustomPaint(
      size: Size.square(size),
      painter: BotanicalPainter(
        kind: kind,
        color: (color ?? _defaultColor(kind)).withValues(alpha: opacity),
      ),
    );
    if (mirrored) {
      drawing = Transform.flip(flipX: true, child: drawing);
    }
    return ExcludeSemantics(child: RepaintBoundary(child: drawing));
  }

  static Color _defaultColor(BotanicalKind kind) => switch (kind) {
    BotanicalKind.sprig => const Color(0xFF7FBFAE),
    BotanicalKind.ginkgo => const Color(0xFFC9B27C),
    BotanicalKind.bamboo => const Color(0xFF8CC5B5),
    BotanicalKind.blossom => const Color(0xFFE8A3B3),
  };
}

/// Paints a [BotanicalKind] in a square, with hairline strokes.
class BotanicalPainter extends CustomPainter {
  BotanicalPainter({required this.kind, required this.color});

  final BotanicalKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, size.shortestSide / 90)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width, size.height);
    stroke.strokeWidth /= size.shortestSide;
    switch (kind) {
      case BotanicalKind.sprig:
        _sprig(canvas, stroke);
      case BotanicalKind.ginkgo:
        _ginkgo(canvas, stroke);
      case BotanicalKind.bamboo:
        _bamboo(canvas, stroke);
      case BotanicalKind.blossom:
        _blossom(canvas, stroke);
    }
    canvas.restore();
  }

  /// A leaf from [base] pointing at [angle] (radians), drawn as two arcs and a
  /// midrib.
  void _leaf(Canvas canvas, Paint paint, Offset base, double angle, double length, double width) {
    final tip = base + Offset(math.cos(angle), math.sin(angle)) * length;
    final normal = Offset(-math.sin(angle), math.cos(angle)) * width;
    final mid = Offset.lerp(base, tip, 0.45)!;
    final path =
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo((mid + normal).dx, (mid + normal).dy, tip.dx, tip.dy)
          ..quadraticBezierTo((mid - normal).dx, (mid - normal).dy, base.dx, base.dy);
    canvas.drawPath(path, paint);
    canvas.drawLine(base, Offset.lerp(base, tip, 0.8)!, paint);
  }

  void _sprig(Canvas canvas, Paint paint) {
    final stem =
        Path()
          ..moveTo(0.18, 0.95)
          ..cubicTo(0.30, 0.70, 0.42, 0.45, 0.78, 0.08);
    canvas.drawPath(stem, paint);
    const leaves = [
      (0.27, 0.80, -2.2, 0.20),
      (0.33, 0.68, -0.55, 0.22),
      (0.42, 0.53, -2.35, 0.20),
      (0.50, 0.42, -0.70, 0.19),
      (0.61, 0.29, -2.45, 0.16),
      (0.68, 0.20, -0.85, 0.14),
    ];
    for (final (x, y, angle, length) in leaves) {
      _leaf(canvas, paint, Offset(x, y), angle, length, length * 0.32);
    }
  }

  void _ginkgo(Canvas canvas, Paint paint) {
    final base = const Offset(0.5, 0.62);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(0.47, 0.82, 0.38, 0.96),
      paint,
    );
    final fan =
        Path()
          ..moveTo(base.dx, base.dy)
          ..cubicTo(0.30, 0.55, 0.08, 0.38, 0.12, 0.22)
          ..quadraticBezierTo(0.28, 0.10, 0.46, 0.18)
          ..lineTo(0.50, 0.26)
          ..lineTo(0.54, 0.18)
          ..quadraticBezierTo(0.74, 0.08, 0.88, 0.22)
          ..cubicTo(0.92, 0.38, 0.70, 0.55, base.dx, base.dy);
    canvas.drawPath(fan, paint);
    for (var i = 0; i < 7; i++) {
      final angle = math.pi * (1.12 + i * 0.13);
      canvas.drawLine(
        base,
        base + Offset(math.cos(angle), math.sin(angle)) * 0.36,
        paint..color = color.withValues(alpha: color.a * 0.55),
      );
    }
    paint.color = color;
  }

  void _bamboo(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(0.42, 0.98), const Offset(0.46, 0.04), paint);
    canvas.drawLine(const Offset(0.50, 0.98), const Offset(0.53, 0.04), paint);
    for (final y in [0.28, 0.58, 0.86]) {
      canvas.drawLine(Offset(0.41, y), Offset(0.54, y - 0.006), paint);
    }
    _leaf(canvas, paint, const Offset(0.53, 0.28), -0.45, 0.40, 0.06);
    _leaf(canvas, paint, const Offset(0.52, 0.30), 0.15, 0.34, 0.05);
    _leaf(canvas, paint, const Offset(0.43, 0.58), -2.65, 0.32, 0.05);
  }

  void _blossom(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(0.05, 0.90)
        ..cubicTo(0.30, 0.80, 0.45, 0.60, 0.62, 0.40)
        ..moveTo(0.38, 0.72)
        ..quadraticBezierTo(0.46, 0.80, 0.62, 0.82),
      paint,
    );
    const centre = Offset(0.70, 0.30);
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final petalTip = centre + Offset(math.cos(angle), math.sin(angle)) * 0.17;
      final side = Offset(-math.sin(angle), math.cos(angle)) * 0.07;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..quadraticBezierTo((petalTip + side).dx, (petalTip + side).dy, petalTip.dx, petalTip.dy)
          ..quadraticBezierTo((petalTip - side).dx, (petalTip - side).dy, centre.dx, centre.dy),
        paint,
      );
    }
    canvas.drawCircle(centre, 0.018, paint);
    _leaf(canvas, paint, const Offset(0.62, 0.82), 0.2, 0.18, 0.06);
    canvas.drawCircle(const Offset(0.30, 0.66), 0.035, paint);
  }

  @override
  bool shouldRepaint(BotanicalPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// A section heading in light type with one botanical accent beside it,
/// slightly off-centre.
class FreshHeading extends StatelessWidget {
  const FreshHeading(
    this.text, {
    super.key,
    this.subtitle,
    this.botanical = BotanicalKind.sprig,
    this.style,
  });

  final String text;
  final String? subtitle;
  final BotanicalKind? botanical;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (botanical != null)
          Positioned(
            right: FreshSpace.md,
            top: -FreshSpace.sm,
            child: Botanical(kind: botanical!, size: 64, opacity: 0.7),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(text, style: style ?? theme.headlineMedium),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: FreshSpace.sm),
                Text(subtitle!, style: theme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
