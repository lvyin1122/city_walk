import 'package:flutter/material.dart';

/// Design tokens for the "Japanese Fresh" (日系清新风) style: rice-paper
/// white, light type, hairline borders, slow transitions and a lot of space.
///
/// Every colour, size and duration in the UI should come from here or from
/// the theme built in `app_theme.dart`. `test/theme/style_rules_test.dart`
/// rejects the patterns this style forbids (bold type, shadows, thick borders,
/// dark backgrounds, fast transitions).
abstract final class FreshColors {
  /// Page background.
  static const riceWhite = Color(0xFFFAFAF8);

  /// Cards, sheets and dialogs.
  static const paper = Color(0xFFFFFFFF);

  static const sky = Color(0xFF64B5F6);
  static const mint = Color(0xFF98D8C8);
  static const pink = Color(0xFFFFB7C5);
  static const powder = Color(0xFFB8D4E3);

  /// Headings and primary text (7.4:1 on rice white).
  static const ink = Color(0xFF4A5568);

  /// Body and secondary text (4.6:1 on rice white).
  static const body = Color(0xFF6B7280);

  /// Large secondary text and icons only (3.4:1).
  static const inkSoft = Color(0xFF7A8A9E);

  /// Decoration and disabled states only; never for text people must read.
  static const inkMuted = Color(0xFFB0B8C4);

  /// Warm neutral for every border and divider.
  static const line = Color(0xFFD4D4CF);

  /// Text on a sky-blue fill. White on sky blue is 2.3:1 and fails WCAG AA;
  /// this deep ink is 5.3:1.
  static const onSky = Color(0xFF1F3A56);

  /// Sky blue dark enough for text and links on white (5.3:1).
  static const skyText = Color(0xFF2F6FA8);

  /// Errors: a muted rose that still reads at 5:1 on white.
  static const error = Color(0xFFB04A5F);

  /// Mint dark enough for "done" text and icons on white (4.6:1).
  static const mintText = Color(0xFF2E7D6B);

  /// Soft tints for chips, selected rows and progress tracks.
  static Color tint(Color color, [double alpha = 0.16]) =>
      color.withValues(alpha: alpha);
}

abstract final class FreshSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Breathing room between sections ("Ma").
  static const double section = 96;

  /// Side padding of a page.
  static const double page = 28;

  /// Inside a card.
  static const double card = 28;
}

abstract final class FreshRadius {
  /// Buttons, chips, inputs (rounded-lg).
  static const double lg = 8;

  /// Cards, sheets, dialogs (rounded-xl).
  static const double xl = 12;

  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl));
}

abstract final class FreshBorders {
  /// The only border weight this style uses.
  static const double hairlineWidth = 0.8;

  static final BorderSide hairline = BorderSide(
    color: FreshColors.line.withValues(alpha: 0.7),
    width: hairlineWidth,
  );

  static const BorderSide focused = BorderSide(
    color: FreshColors.sky,
    width: hairlineWidth,
  );

  static final Border all = Border.fromBorderSide(hairline);
}

abstract final class FreshMotion {
  /// Every interaction eases in over half a second, like morning mist.
  static const Duration slow = Duration(milliseconds: 500);

  /// Small state changes (progress dots, toggles). Never below 200 ms.
  static const Duration gentle = Duration(milliseconds: 300);

  static const Curve curve = Curves.easeInOut;

  /// [duration], or zero when the user asked the system to reduce motion.
  static Duration of(BuildContext context, [Duration duration = slow]) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}

abstract final class FreshWeights {
  /// Headings.
  static const FontWeight extraLight = FontWeight.w200;

  /// Everything else.
  static const FontWeight light = FontWeight.w300;

  /// Small labels where w300 would be too faint to read (still not bold).
  static const FontWeight regular = FontWeight.w400;
}
