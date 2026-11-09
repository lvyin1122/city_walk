import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/theme/tokens.dart';

/// A translucent rice-paper panel that floats over the map.
class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FreshSpace.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: FreshMotion.of(context),
      curve: FreshMotion.curve,
      padding: padding,
      decoration: BoxDecoration(
        color: FreshColors.paper.withValues(alpha: 0.94),
        borderRadius: FreshRadius.card,
        border: FreshBorders.all,
      ),
      child: child,
    );
  }
}

/// Time and distance walked, side by side.
class WalkStatsLine extends StatelessWidget {
  const WalkStatsLine({
    super.key,
    required this.elapsed,
    required this.distanceKm,
    this.stops,
  });

  final Duration elapsed;
  final double distanceKm;
  final String? stops;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FreshWeights.regular,
    );
    Widget item(IconData icon, String value, String label) => Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: FreshColors.inkSoft),
            const SizedBox(width: FreshSpace.sm),
            Flexible(child: Text(value, style: style)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        item(Icons.schedule_outlined, formatElapsed(elapsed), '已步行'),
        Container(width: FreshBorders.hairlineWidth, height: 20, color: FreshColors.line),
        item(Icons.directions_walk_outlined, formatKilometers(distanceKm), '距离'),
        if (stops != null) item(Icons.place_outlined, stops!, '地点'),
      ],
    );
  }
}

/// A small square button floating over the map.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: FreshColors.paper.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.button,
          side: FreshBorders.hairline,
        ),
        child: InkWell(
          borderRadius: FreshRadius.button,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, size: 22, color: FreshColors.ink),
          ),
        ),
      ),
    );
  }
}
