import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';

/// Live microphone loudness (0..1) while dictating, for the orb. A notifier rather than state, so 20 updates a second
/// repaint the orb without rebuilding pages.
final voiceLevelProvider = Provider<ValueNotifier<double>>((ref) {
  final level = ValueNotifier<double>(0);
  final events = Platform.isAndroid
      ? ref.watch(androidBridgeProvider).events()
      : Platform.isMacOS
      ? DesktopDictationNotifier.events
      : null;
  final subscription = events?.listen((event) {
    if (event['type'] == 'level') level.value = (event['value'] as num? ?? 0).toDouble();
  });
  ref.onDispose(() {
    subscription?.cancel();
    level.dispose();
  });
  return level;
});
