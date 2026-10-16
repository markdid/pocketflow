import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden comparator that passes when the pixel diff is within [tolerance]
/// (a fraction, 0.01 == 1%), to absorb tiny cross-machine rendering noise.
class TolerantGoldenFileComparator extends LocalFileComparator {
  TolerantGoldenFileComparator(super.testFile);

  static const double tolerance = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) return true;

    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

class ScreenSize {
  const ScreenSize({required this.name, required this.size, this.devicePixelRatio = 1.0});

  final String name;
  final Size size;
  final double devicePixelRatio;
}

class GoldenScreenSizes {
  GoldenScreenSizes._();

  static const iPhoneMini = ScreenSize(name: 'iPhone_mini', size: Size(375, 812), devicePixelRatio: 3);
  static const iPhone = ScreenSize(name: 'iPhone', size: Size(390, 844), devicePixelRatio: 3);
  static const iPhoneMax = ScreenSize(name: 'iPhone_max', size: Size(428, 926), devicePixelRatio: 3);
  static const desktopSmall = ScreenSize(name: 'desktop_small', size: Size(1024, 768));
  static const desktopLarge = ScreenSize(name: 'desktop_large', size: Size(1440, 900));

  static const mobile = [iPhoneMini, iPhone, iPhoneMax];
  static const desktop = [desktopSmall, desktopLarge];
  static const all = [...mobile, ...desktop];
}

bool _fontsLoaded = false;

/// Loads every font declared in pubspec.yaml (plus Material icons) so goldens
/// render real glyphs instead of the Ahem test font's boxes.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;

  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

void _useTolerantComparator() {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator && comparator is! TolerantGoldenFileComparator) {
    // LocalFileComparator expects a file URI and takes its directory as basedir.
    goldenFileComparator = TolerantGoldenFileComparator(comparator.basedir.resolve('golden_test.dart'));
  }
}

/// Pumps [widget] at each of [screenSizes] and compares against
/// `goldens/<goldenFileName>_<size>.png` next to the calling test file.
///
/// Pass [pumpDuration] for widgets with infinite animations (e.g. loading
/// spinners), which never settle.
Future<void> expectGoldenAcrossScreenSizes(
  WidgetTester tester, {
  required Widget widget,
  required String goldenFileName,
  List<ScreenSize> screenSizes = GoldenScreenSizes.all,
  Duration? pumpDuration,
}) async {
  _useTolerantComparator();
  await loadAppFonts();
  addTearDown(tester.view.reset);

  for (final screenSize in screenSizes) {
    tester.view.physicalSize = screenSize.size * screenSize.devicePixelRatio;
    tester.view.devicePixelRatio = screenSize.devicePixelRatio;

    await tester.pumpWidget(widget);
    if (pumpDuration != null) {
      await tester.pump(pumpDuration);
    } else {
      await tester.pumpAndSettle();
    }

    await expectLater(find.byWidget(widget), matchesGoldenFile('goldens/${goldenFileName}_${screenSize.name}.png'));
  }
}
