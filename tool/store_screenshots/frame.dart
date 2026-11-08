import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

/// Logical size of an iPhone Pro Max screen (1320×2868 pixels at 3x).
const phoneSize = Size(440, 956);

/// Safe-area insets of that screen: status bar and home indicator.
const phonePadding = EdgeInsets.only(top: 62, bottom: 34);

/// A phone screen at [phoneSize]: either a rendered app screen with a status
/// bar drawn on top, or a captured screenshot that already has one.
class PhoneScreen extends StatelessWidget {
  const PhoneScreen.rendered({super.key, required Widget this.screen})
    : capture = null;

  const PhoneScreen.captured({super.key, required ImageProvider this.capture})
    : screen = null;

  final Widget? screen;
  final ImageProvider? capture;

  @override
  Widget build(BuildContext context) {
    final capture = this.capture;
    if (capture != null) {
      return Image(image: capture, fit: BoxFit.cover, width: phoneSize.width, height: phoneSize.height);
    }
    return SizedBox.fromSize(
      size: phoneSize,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: phoneSize,
          padding: phonePadding,
          viewPadding: phonePadding,
          textScaler: TextScaler.noScaling,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: screen!),
            // The status bar and indicator sit above the page's Material.
            const Positioned(top: 0, left: 0, right: 0, height: 54, child: _StatusBar()),
            const Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(child: _HomeIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const ink = FreshColors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 18, 36, 0),
      child: Row(
        children: [
          const Text(
            '9:41',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: ink, height: 1.2),
          ),
          const Spacer(),
          // The Dynamic Island.
          Container(
            width: 124,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
          const Spacer(),
          const Icon(Icons.signal_cellular_alt, size: 18, color: ink),
          const SizedBox(width: 5),
          const Icon(Icons.wifi, size: 18, color: ink),
          const SizedBox(width: 5),
          const Icon(Icons.battery_full, size: 20, color: ink),
        ],
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 5,
    decoration: const BoxDecoration(
      color: FreshColors.ink,
      borderRadius: BorderRadius.all(Radius.circular(3)),
    ),
  );
}

/// The phone screen with rounded corners and a hairline edge, scaled to
/// [width].
class FramedPhone extends StatelessWidget {
  const FramedPhone({super.key, required this.width, required this.child});

  final double width;
  final PhoneScreen child;

  @override
  Widget build(BuildContext context) {
    final scale = width / phoneSize.width;
    final radius = BorderRadius.circular(56 * scale);
    return Container(
      width: width,
      height: phoneSize.height * scale,
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: FreshColors.line, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: FittedBox(fit: BoxFit.fill, child: child),
      ),
    );
  }
}

/// A store or social image: brand line, caption, one botanical drawing and
/// the phone screen, on the app's paper background. Fills its parent; the
/// phone may run past the bottom edge on short formats.
class StoreFrame extends StatelessWidget {
  const StoreFrame({
    super.key,
    required this.brand,
    required this.caption,
    required this.phone,
    this.botanical = BotanicalKind.sprig,
  });

  final String brand;
  final String caption;
  final PhoneScreen phone;
  final BotanicalKind botanical;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tall = h / w > 1.6;
        final top = h * (tall ? 0.065 : 0.06);
        final captionSize = w * (tall ? 0.078 : 0.07);
        final phoneTop = h * (tall ? 0.235 : 0.30);
        // Tall formats show the whole phone; short social formats crop its
        // bottom on purpose.
        final phoneWidth = tall
            ? math.min(w * 0.8, (h * 0.97 - phoneTop) * phoneSize.width / phoneSize.height)
            : w * 0.66;
        return PaperBackground(
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  right: w * 0.04,
                  top: top * 0.6,
                  child: Botanical(kind: botanical, size: w * 0.24, opacity: 0.8),
                ),
                Positioned(
                  left: w * 0.09,
                  right: w * 0.2,
                  top: top,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: TextStyle(
                          fontSize: captionSize * 0.36,
                          fontWeight: FreshWeights.regular,
                          color: FreshColors.skyText,
                          letterSpacing: captionSize * 0.08,
                        ),
                      ),
                      SizedBox(height: captionSize * 0.35),
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: captionSize,
                          fontWeight: FreshWeights.light,
                          color: FreshColors.ink,
                          height: 1.32,
                          letterSpacing: captionSize * 0.03,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: phoneTop,
                  left: (w - phoneWidth) / 2,
                  child: FramedPhone(width: phoneWidth, child: phone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The Google Play feature graphic (1024×500): brand and tagline on the
/// left, the top of a phone screen on the right.
class FeatureGraphic extends StatelessWidget {
  const FeatureGraphic({
    super.key,
    required this.brand,
    required this.tagline,
    required this.phone,
  });

  final String brand;
  final String tagline;
  final PhoneScreen phone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return PaperBackground(
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: w * 0.07,
                  top: 0,
                  bottom: 0,
                  width: w * 0.55,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: TextStyle(
                          fontSize: h * 0.17,
                          fontWeight: FreshWeights.extraLight,
                          color: FreshColors.ink,
                          letterSpacing: h * 0.01,
                        ),
                      ),
                      SizedBox(height: h * 0.05),
                      Text(
                        tagline,
                        style: TextStyle(
                          fontSize: h * 0.075,
                          fontWeight: FreshWeights.light,
                          color: FreshColors.body,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: w * 0.29,
                  bottom: h * 0.06,
                  child: Botanical(kind: BotanicalKind.ginkgo, size: h * 0.3, opacity: 0.8),
                ),
                Positioned(
                  right: w * 0.06,
                  top: h * 0.1,
                  child: FramedPhone(width: w * 0.24, child: phone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
