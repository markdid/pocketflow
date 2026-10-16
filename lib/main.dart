import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/app.dart';
import 'package:pocketflow/platform/dictation_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: App()));
}

/// Started by Android's DictationService in a background engine. Must live in main.dart to be found by name.
@pragma('vm:entry-point')
Future<void> dictationEngineMain() => runDictationEngine();
