import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rice-paper page background: off-white with a faint linen grain.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: FreshColors.riceWhite),
      child: CustomPaint(
        painter: const _LinenPainter(),
        isComplex: true,
        child: child,
      ),
    );
  }
}

class _LinenPainter extends CustomPainter {
  const _LinenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed: the grain must not shimmer between frames.
    final random = math.Random(7);
    final thread =
        Paint()
          ..strokeWidth = 0.5
          ..color = FreshColors.line.withValues(alpha: 0.12);
    for (var y = 0.0; y < size.height; y += 3 + random.nextDouble() * 5) {
      final start = random.nextDouble() * size.width * 0.5;
      canvas.drawLine(
        Offset(start, y),
        Offset(start + 40 + random.nextDouble() * size.width * 0.6, y),
        thread,
      );
    }
    for (var x = 0.0; x < size.width; x += 4 + random.nextDouble() * 7) {
      final start = random.nextDouble() * size.height * 0.5;
      canvas.drawLine(
        Offset(x, start),
        Offset(x, start + 30 + random.nextDouble() * size.height * 0.4),
        thread..color = FreshColors.line.withValues(alpha: 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(_LinenPainter oldDelegate) => false;
}

/// White card with a hairline border and generous padding. Do not nest one
/// card inside another.
class FreshCard extends StatelessWidget {
  const FreshCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FreshSpace.card),
    this.color = FreshColors.paper,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: FreshMotion.of(context),
      curve: FreshMotion.curve,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: FreshRadius.card,
        border: FreshBorders.all,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return _WeightlessPress(onTap: onTap!, child: card);
  }
}

/// Tap feedback without weight: the child lifts by half a pixel and clouds
/// over slightly while pressed, over half a second.
class _WeightlessPress extends StatefulWidget {
  const _WeightlessPress({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_WeightlessPress> createState() => _WeightlessPressState();
}

class _WeightlessPressState extends State<_WeightlessPress> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final duration = FreshMotion.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: duration,
          curve: FreshMotion.curve,
          offset: _pressed ? const Offset(0, -0.002) : Offset.zero,
          child: AnimatedOpacity(
            duration: duration,
            curve: FreshMotion.curve,
            opacity: _pressed ? 0.82 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A thin, rounded progress line made of [total] segments.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.done,
    required this.total,
    this.color = FreshColors.sky,
  });

  final int done;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done / $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: AnimatedContainer(
                duration: FreshMotion.of(context),
                curve: FreshMotion.curve,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < done ? color : FreshColors.tint(FreshColors.line, 0.6),
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
