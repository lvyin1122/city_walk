import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';

/// The Japanese Fresh style forbids some things outright. These checks scan
/// `lib/` so a forbidden pattern fails CI instead of slipping into a screen.
void main() {
  final sources = {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart')) file.path: file.readAsStringSync(),
  };

  List<String> offenders(RegExp pattern) => [
    for (final MapEntry(key: path, value: source) in sources.entries)
      for (final (i, line) in source.split('\n').indexed)
        if (pattern.hasMatch(line) && !line.trimLeft().startsWith('//')) '$path:${i + 1}: ${line.trim()}',
  ];

  final rules = {
    'bold or heavy font weights': RegExp(r'FontWeight\.(bold|w[5-9]00)'),
    'visible shadows': RegExp(r'BoxShadow\(|elevation: *[1-9]'),
    'uppercase text': RegExp(r'toUpperCase\(\)'),
    'borders thicker than a hairline': RegExp(r'(strokeWidth|width): *[2-9](\.\d+)?[,)]\s*$|Border\.all\([^)]*width: *[2-9]'),
    'dark or black backgrounds': RegExp(r'(backgroundColor|color): *(const )?Colors\.(black|grey\.shade(800|900))'),
    'sharp corners': RegExp(r'BorderRadius\.zero|BorderRadius\.circular\(0\)'),
    'raw Material colours instead of tokens': RegExp(r'Colors\.(?!transparent\b)[a-z]+'),
  };

  for (final MapEntry(key: rule, value: pattern) in rules.entries) {
    test('no $rule in lib/', () {
      expect(offenders(pattern), isEmpty);
    });
  }

  test('no interaction is faster than 200 ms', () {
    final durations = RegExp(r'Duration\(milliseconds: *(\d+)\)');
    final fast = [
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final match in durations.allMatches(source))
          if (int.parse(match.group(1)!) < 200) '$path: ${match.group(0)}',
    ];
    expect(fast, isEmpty);
    expect(FreshMotion.slow.inMilliseconds, 500);
    expect(FreshMotion.gentle.inMilliseconds, greaterThanOrEqualTo(200));
  });

  group('theme', () {
    final theme = AppTheme.light();

    test('every text style is light', () {
      final styles = [
        theme.textTheme.displayLarge, theme.textTheme.headlineMedium,
        theme.textTheme.titleLarge, theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium, theme.textTheme.labelLarge,
        theme.textTheme.labelSmall,
      ];
      for (final style in styles) {
        expect(style!.fontWeight!.value, lessThanOrEqualTo(400));
      }
    });

    test('surfaces are flat', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.floatingActionButtonTheme.elevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.scaffoldBackgroundColor, FreshColors.riceWhite);
    });

    test('inputs are a single bottom line', () {
      expect(theme.inputDecorationTheme.enabledBorder, isA<UnderlineInputBorder>());
      expect(theme.inputDecorationTheme.focusedBorder, isA<UnderlineInputBorder>());
      expect(theme.inputDecorationTheme.filled, isFalse);
    });
  });

  group('contrast (WCAG AA)', () {
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    }

    double ratio(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    test('body text reads on paper and rice white', () {
      for (final text in [FreshColors.ink, FreshColors.body, FreshColors.skyText, FreshColors.error, FreshColors.mintText]) {
        expect(ratio(text, FreshColors.paper), greaterThanOrEqualTo(4.5), reason: '$text');
        expect(ratio(text, FreshColors.riceWhite), greaterThanOrEqualTo(4.5), reason: '$text');
      }
    });

    test('text on the sky-blue button reads', () {
      expect(ratio(FreshColors.onSky, FreshColors.sky), greaterThanOrEqualTo(4.5));
    });

    test('soft grey is only fit for large text', () {
      expect(ratio(FreshColors.inkSoft, FreshColors.paper), greaterThanOrEqualTo(3));
    });
  });
}
