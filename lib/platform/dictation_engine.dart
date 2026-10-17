import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/dictation/dictation_pipeline.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/services/logging_service.dart';

/// Headless entrypoint run by Android's DictationService in its own Flutter engine, so dictation works from the
/// keyboard, accessibility hotkeys, and headset without the app's UI open. Native code records audio and delivers
/// text; Dart does everything in between.
Future<void> runDictationEngine() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  const channel = MethodChannel('pocketflow/engine');

  channel.setMethodCallHandler((call) async {
    final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final pipeline = container.read(dictationPipelineProvider);
    switch (call.method) {
      case 'process':
        try {
          final result = await pipeline.process(
            audio: File(args['path']! as String),
            mode: args['mode'] == 'memo' ? DictationMode.memo : DictationMode.dictation,
            appId: args['appId'] as String?,
            audioMillis: args['audioMillis'] as int?,
          );
          return {'text': result.text, 'warning': result.warning, 'historyId': result.entry?.id};
        } on TranscriptionSavedException catch (e) {
          return {'error': e.toString(), 'saved': true, 'historyId': e.entry.id};
        } on Exception catch (e, stack) {
          LoggerService.e('Dictation failed', e, stack);
          return {'error': e.toString()};
        }
      case 'warmUp':
        await pipeline.warmUp();
        return null;
      case 'learn':
        try {
          final learned = await pipeline.learnFromEdit(
            inserted: args['inserted']! as String,
            fieldText: args['fieldText']! as String,
          );
          return [for (final item in learned) item.toMap()];
        } on Exception catch (e, stack) {
          LoggerService.w('Learning from an edit failed', e, stack);
          return const <Object>[];
        }
      default:
        throw MissingPluginException(call.method);
    }
  });
  await channel.invokeMethod<void>('ready');
}
