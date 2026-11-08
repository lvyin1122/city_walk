// Renders store and marketing screenshots. Not part of `flutter test`:
//
//   flutter test tool/store_screenshots
//
// See tool/store_screenshots/README.md for fonts, photos and device captures.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/widgets/botanical.dart';

import 'captions.dart';
import 'frame.dart';
import 'screens.dart';

const _toolDir = 'tool/store_screenshots';
const _outDir = 'build/store';

/// Family name the screenshots are set in; the static fonts are registered
/// under it (see prepare_fonts.py).
const _sans = 'StoreSans';
const _emoji = 'StoreEmoji';
const _emojiFont = String.fromEnvironment(
  'STORE_EMOJI_FONT',
  defaultValue: '/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf',
);

/// Output sizes in pixels, and the device pixel ratio used to lay them out.
const _targets = <String, (Size, double)>{
  'appstore': (Size(1320, 2868), 3),
  'play': (Size(1080, 1920), 2.4),
  'social-4x5': (Size(1080, 1350), 2.4),
  'social-3x4': (Size(1242, 1660), 2.76),
  'social-9x16': (Size(1080, 1920), 2.4),
  'readme': (Size(540, 1173), 1.2),
};

const _slugs = {
  1: 'setup',
  2: 'preview',
  3: 'walk-task',
  4: 'photo-check',
  5: 'summary',
  6: 'history',
};

const _botanicals = {
  1: BotanicalKind.sprig,
  2: BotanicalKind.ginkgo,
  3: BotanicalKind.bamboo,
  4: BotanicalKind.sprig,
  5: BotanicalKind.blossom,
  6: BotanicalKind.ginkgo,
};

Future<void> _loadFonts() async {
  final fonts = Directory('$_toolDir/fonts');
  final files = fonts.existsSync()
      ? fonts.listSync().whereType<File>().where((f) => f.path.endsWith('.otf')).toList()
      : <File>[];
  if (files.isEmpty) {
    fail('No fonts in $_toolDir/fonts. Run: python3 $_toolDir/prepare_fonts.py');
  }
  for (final family in [_sans]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  final emoji = File(_emojiFont);
  if (emoji.existsSync()) {
    await (FontLoader(_emoji)..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())))).load();
  } else {
    debugPrint('No emoji font at $_emojiFont; keyword chips will show boxes.');
  }

  // flutter_tester runs from <flutter>/bin/cache/artifacts/engine/...
  final tester = Platform.resolvedExecutable;
  final cache = tester.substring(0, tester.indexOf('/bin/cache/') + '/bin/cache/'.length);
  final icons = File('${cache}artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!icons.existsSync()) {
    fail('Material icons not found at ${icons.path}');
  } else {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

/// The app theme with the screenshot fonts named in every text style.
/// Buttons, chips and other components do not inherit the ambient text
/// style, and the engine default cannot point at fonts loaded at runtime.
ThemeData _theme() {
  final base = AppTheme.light();
  TextStyle? f(TextStyle? style) =>
      style?.copyWith(fontFamily: _sans, fontFamilyFallback: const [_emoji]);
  WidgetStateProperty<TextStyle?>? fs(WidgetStateProperty<TextStyle?>? style) =>
      style == null ? null : WidgetStateProperty.resolveWith((states) => f(style.resolve(states)));
  ButtonStyle? button(ButtonStyle? style) => style?.copyWith(textStyle: fs(style.textStyle));
  TextTheme text(TextTheme theme) =>
      theme.apply(fontFamily: _sans, fontFamilyFallback: const [_emoji]);
  final input = base.inputDecorationTheme;
  return base.copyWith(
    textTheme: text(base.textTheme),
    primaryTextTheme: text(base.primaryTextTheme),
    elevatedButtonTheme: ElevatedButtonThemeData(style: button(base.elevatedButtonTheme.style)),
    filledButtonTheme: FilledButtonThemeData(style: button(base.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button(base.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: button(base.textButtonTheme.style)),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: f(base.chipTheme.labelStyle ?? base.textTheme.labelLarge),
      secondaryLabelStyle: f(base.chipTheme.secondaryLabelStyle ?? base.textTheme.labelLarge),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: fs(base.navigationBarTheme.labelTextStyle),
    ),
    appBarTheme: base.appBarTheme.copyWith(titleTextStyle: f(base.appBarTheme.titleTextStyle)),
    inputDecorationTheme: input.copyWith(
      labelStyle: f(input.labelStyle),
      floatingLabelStyle: f(input.floatingLabelStyle),
      hintStyle: f(input.hintStyle),
      helperStyle: f(input.helperStyle),
      errorStyle: f(input.errorStyle),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: f(base.tabBarTheme.labelStyle),
      unselectedLabelStyle: f(base.tabBarTheme.unselectedLabelStyle),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      titleTextStyle: f(base.listTileTheme.titleTextStyle),
      subtitleTextStyle: f(base.listTileTheme.subtitleTextStyle),
    ),
  );
}

/// Captured screenshots from tool/store_screenshots/raw/, by slot number.
Map<int, File> _captures() {
  final raw = Directory('$_toolDir/raw');
  if (!raw.existsSync()) return {};
  return {
    for (final file in raw.listSync().whereType<File>())
      if (RegExp(r'(\d\d)-[^/]*\.png$').firstMatch(file.path) case final match?)
        int.parse(match.group(1)!): file,
  };
}

/// Your own photos from tool/store_screenshots/photos/ for the summary.
List<File> _photos() {
  final dir = Directory('$_toolDir/photos');
  if (!dir.existsSync()) return [];
  return (dir.listSync().whereType<File>().where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f.path)).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      .take(6)
      .toList();
}

void main() {
  testWidgets('store screenshots', (tester) async {
    await _loadFonts();
    final captures = _captures();
    final photos = _photos();

    // PhotoGrid uses Image.network; serve the local photos from the cache.
    final photoUrls = <String>[];
    for (final (i, file) in photos.indexed) {
      final url = 'https://photos.local/$i.jpg';
      photoUrls.add(url);
      final provider = ResizeImage(FileImage(file), width: 600);
      final key = (await tester.runAsync(() => provider.obtainKey(ImageConfiguration.empty)))!;
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(url),
        () => provider.loadImage(key, PaintingBinding.instance.instantiateImageCodecWithSize),
      );
    }

    PhoneScreen? phoneFor(int slot) {
      if (captures[slot] case final file?) {
        return PhoneScreen.captured(capture: FileImage(file));
      }
      return switch (slot) {
        1 => PhoneScreen.rendered(screen: setupScreen()),
        5 => PhoneScreen.rendered(screen: summaryScreen(photoUrls: photoUrls)),
        6 => PhoneScreen.rendered(screen: historyScreen()),
        _ => null,
      };
    }

    final written = <String>[];
    final missing = <String>[];

    Future<void> render(Widget frame, Size pixels, double ratio, String path) async {
      tester.view.physicalSize = pixels;
      tester.view.devicePixelRatio = ratio;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(),
            home: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: _sans, fontFamilyFallback: [_emoji]),
                child: frame,
              ),
            ),
          ),
        ),
      );
      // Decode every image in the tree before painting.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = element.widget as Image;
          await precacheImage(image.image, element);
        }
      });
      await tester.pumpAndSettle();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: ratio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final file = File(path)..createSync(recursive: true);
      file.writeAsBytesSync(bytes!);
      written.add(path);
    }

    for (final lang in Lang.values) {
      for (final MapEntry(key: target, value: (pixels, ratio)) in _targets.entries) {
        for (final slot in _slugs.keys) {
          final phone = phoneFor(slot);
          final path = '$_outDir/${lang.folder}/$target/${slot.toString().padLeft(2, '0')}-${_slugs[slot]}.png';
          if (phone == null) {
            missing.add(path);
            continue;
          }
          await render(
            StoreFrame(
              brand: brand[lang]!,
              caption: captions[slot]![lang]!,
              phone: phone,
              botanical: _botanicals[slot]!,
            ),
            pixels,
            ratio,
            path,
          );
        }
      }
      await render(
        FeatureGraphic(
          brand: brand[lang]!,
          tagline: featureTagline[lang]!,
          phone: phoneFor(3) ?? phoneFor(1)!,
        ),
        const Size(1024, 500),
        2,
        '$_outDir/${lang.folder}/play-feature/feature-graphic.png',
      );
    }

    tester.view.reset();
    debugPrint('Wrote ${written.length} images to $_outDir.');
    if (missing.isNotEmpty) {
      debugPrint(
        'Skipped ${missing.length} images: slots 02-04 need device captures in '
        '$_toolDir/raw/ (see capture_ios.sh).',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
