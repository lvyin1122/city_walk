import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's Material theme in the Japanese Fresh style.
///
/// Component themes carry the style (flat, hairline, light type, slow
/// transitions), so screens rarely need inline styling: use the theme's text
/// styles and plain Material widgets.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: FreshColors.sky,
      onPrimary: FreshColors.onSky,
      primaryContainer: Color(0xFFE3F1FC),
      onPrimaryContainer: FreshColors.onSky,
      secondary: FreshColors.mint,
      onSecondary: FreshColors.ink,
      secondaryContainer: Color(0xFFE6F5F1),
      onSecondaryContainer: FreshColors.ink,
      tertiary: FreshColors.pink,
      onTertiary: FreshColors.ink,
      tertiaryContainer: Color(0xFFFFF0F3),
      onTertiaryContainer: FreshColors.ink,
      error: FreshColors.error,
      onError: FreshColors.paper,
      errorContainer: Color(0xFFFBEFF1),
      onErrorContainer: FreshColors.error,
      surface: FreshColors.paper,
      onSurface: FreshColors.ink,
      onSurfaceVariant: FreshColors.body,
      surfaceContainerLowest: FreshColors.paper,
      surfaceContainerLow: FreshColors.riceWhite,
      surfaceContainer: FreshColors.riceWhite,
      surfaceContainerHigh: Color(0xFFF4F4F1),
      surfaceContainerHighest: Color(0xFFEFEFEB),
      outline: FreshColors.line,
      outlineVariant: Color(0xFFE8E8E4),
      shadow: Color(0x00000000),
      scrim: Color(0x334A5568),
      inverseSurface: FreshColors.paper,
      onInverseSurface: FreshColors.ink,
      inversePrimary: FreshColors.skyText,
      surfaceTint: Color(0x00000000),
    );

    final text = _textTheme();
    final buttonText = text.labelLarge!.copyWith(
      fontWeight: FreshWeights.light,
      letterSpacing: 0.6,
    );
    final flatButton = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: FreshRadius.button,
          side: FreshBorders.hairline,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      textStyle: WidgetStatePropertyAll(buttonText),
      // A pressed button only clouds over slightly; no ripple, no scaling.
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed)
                ? FreshColors.ink.withValues(alpha: 0.06)
                : states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? FreshColors.sky.withValues(alpha: 0.06)
                : null,
      ),
      splashFactory: NoSplash.splashFactory,
      animationDuration: FreshMotion.slow,
    );

    final underline = UnderlineInputBorder(borderSide: FreshBorders.hairline);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FreshColors.riceWhite,
      canvasColor: FreshColors.riceWhite,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: FreshColors.sky.withValues(alpha: 0.05),
      hoverColor: FreshColors.sky.withValues(alpha: 0.04),
      dividerColor: FreshColors.line,
      iconTheme: const IconThemeData(color: FreshColors.inkSoft, size: 22),
      dividerTheme: DividerThemeData(
        color: FreshColors.line.withValues(alpha: 0.7),
        thickness: FreshBorders.hairlineWidth,
        space: FreshSpace.xl,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FreshColors.riceWhite,
        foregroundColor: FreshColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: const IconThemeData(color: FreshColors.ink),
      ),
      cardTheme: CardThemeData(
        color: FreshColors.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.card,
          side: FreshBorders.hairline,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: flatButton.copyWith(
          backgroundColor: _byState(
            FreshColors.sky.withValues(alpha: 0.9),
            disabled: FreshColors.tint(FreshColors.line, 0.5),
          ),
          foregroundColor: _byState(
            FreshColors.onSky,
            disabled: FreshColors.body,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: flatButton.copyWith(
          backgroundColor: _byState(
            FreshColors.sky.withValues(alpha: 0.9),
            disabled: FreshColors.tint(FreshColors.line, 0.5),
          ),
          foregroundColor: _byState(
            FreshColors.onSky,
            disabled: FreshColors.body,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: flatButton.copyWith(
          backgroundColor: const WidgetStatePropertyAll(FreshColors.paper),
          foregroundColor: _byState(FreshColors.ink, disabled: FreshColors.inkMuted),
          side: WidgetStatePropertyAll(FreshBorders.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: flatButton.copyWith(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: FreshRadius.button),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          foregroundColor: _byState(
            FreshColors.skyText,
            disabled: FreshColors.inkMuted,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: _byState(
            FreshColors.inkSoft,
            disabled: FreshColors.inkMuted,
          ),
          overlayColor: WidgetStatePropertyAll(
            FreshColors.sky.withValues(alpha: 0.06),
          ),
          splashFactory: NoSplash.splashFactory,
          animationDuration: FreshMotion.slow,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FreshColors.paper,
        foregroundColor: FreshColors.ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.card,
          side: FreshBorders.hairline,
        ),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: text.bodyMedium!.copyWith(color: FreshColors.body),
        floatingLabelStyle: text.bodySmall!.copyWith(color: FreshColors.skyText),
        hintStyle: text.bodyMedium!.copyWith(color: FreshColors.inkSoft),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: FreshColors.error),
        prefixIconColor: FreshColors.inkSoft,
        suffixIconColor: FreshColors.inkSoft,
        border: underline,
        enabledBorder: underline,
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: FreshColors.line.withValues(alpha: 0.4),
            width: FreshBorders.hairlineWidth,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: FreshBorders.focused,
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: FreshColors.error,
            width: FreshBorders.hairlineWidth,
          ),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: FreshColors.error,
            width: FreshBorders.hairlineWidth,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: FreshColors.sky,
        selectionColor: FreshColors.sky.withValues(alpha: 0.25),
        selectionHandleColor: FreshColors.sky,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FreshColors.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        barrierColor: const Color(0x334A5568),
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.card,
          side: FreshBorders.hairline,
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FreshColors.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: const Color(0x334A5568),
        dragHandleColor: FreshColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FreshRadius.xl),
          ),
          side: FreshBorders.hairline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FreshColors.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: FreshColors.tint(FreshColors.sky),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: FreshRadius.button,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            color:
                states.contains(WidgetState.selected)
                    ? FreshColors.ink
                    : FreshColors.body,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? FreshColors.skyText
                    : FreshColors.inkSoft,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FreshColors.paper,
        contentTextStyle: text.bodyMedium!.copyWith(color: FreshColors.ink),
        actionTextColor: FreshColors.skyText,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.card,
          side: FreshBorders.hairline,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FreshColors.paper,
        selectedColor: FreshColors.tint(FreshColors.sky),
        disabledColor: FreshColors.riceWhite,
        side: FreshBorders.hairline,
        shape: const RoundedRectangleBorder(borderRadius: FreshRadius.button),
        labelStyle: text.bodyMedium,
        secondaryLabelStyle: text.bodyMedium!.copyWith(color: FreshColors.onSky),
        checkmarkColor: FreshColors.skyText,
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: FreshColors.sky,
        inactiveTrackColor: FreshColors.line,
        thumbColor: FreshColors.sky,
        overlayColor: FreshColors.sky.withValues(alpha: 0.1),
        valueIndicatorColor: FreshColors.paper,
        valueIndicatorTextStyle: text.bodySmall!.copyWith(color: FreshColors.ink),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: FreshColors.sky,
        linearTrackColor: FreshColors.tint(FreshColors.line, 0.5),
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: FreshColors.inkSoft,
        textColor: FreshColors.ink,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: FreshSpace.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: FreshColors.paper,
          borderRadius: FreshRadius.button,
          border: FreshBorders.all,
        ),
        textStyle: text.bodySmall!.copyWith(color: FreshColors.ink),
        waitDuration: FreshMotion.slow,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: _byState(FreshColors.paper),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? FreshColors.sky
                  : FreshColors.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? FreshColors.sky
                  : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(FreshColors.onSky),
        side: BorderSide(color: FreshColors.line, width: 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _MistPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _MistPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _MistPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Light weights throughout: extra-light for display and headings, light
  /// for everything else. Nothing is bold.
  static TextTheme _textTheme() {
    const ink = FreshColors.ink;
    const body = FreshColors.body;
    TextStyle style(double size, FontWeight weight, Color color, {double height = 1.6, double spacing = 0.2}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: spacing,
        );
    return TextTheme(
      displayLarge: style(48, FreshWeights.extraLight, ink, height: 1.2, spacing: 1),
      displayMedium: style(40, FreshWeights.extraLight, ink, height: 1.2, spacing: 1),
      displaySmall: style(34, FreshWeights.extraLight, ink, height: 1.25, spacing: 0.8),
      headlineLarge: style(30, FreshWeights.extraLight, ink, height: 1.3, spacing: 0.8),
      headlineMedium: style(26, FreshWeights.extraLight, ink, height: 1.35, spacing: 0.6),
      headlineSmall: style(22, FreshWeights.light, ink, height: 1.4, spacing: 0.5),
      titleLarge: style(20, FreshWeights.light, ink, height: 1.4, spacing: 0.4),
      titleMedium: style(17, FreshWeights.light, ink, height: 1.45, spacing: 0.3),
      titleSmall: style(15, FreshWeights.light, ink, height: 1.45),
      bodyLarge: style(16, FreshWeights.light, ink),
      bodyMedium: style(15, FreshWeights.light, body),
      bodySmall: style(13, FreshWeights.light, body, height: 1.5),
      labelLarge: style(15, FreshWeights.light, ink, height: 1.3, spacing: 0.6),
      labelMedium: style(13, FreshWeights.light, body, height: 1.3, spacing: 0.4),
      labelSmall: style(12, FreshWeights.regular, body, height: 1.3, spacing: 0.4),
    );
  }

  static WidgetStateProperty<Color?> _byState(Color color, {Color? disabled}) =>
      WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabled ?? color : color,
      );
}

/// Pages fade in and drift up a few pixels, like mist settling.
class _MistPageTransitionsBuilder extends PageTransitionsBuilder {
  const _MistPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: FreshMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
