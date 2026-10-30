import 'dart:async';
import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketflow/dictation/dictation_pipeline.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/vocabulary/state/vocabulary_notifier.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/services/logging_service.dart';

part 'desktop_dictation.mapper.dart';

@MappableClass()
class DesktopDictationState with DesktopDictationStateMappable {
  const DesktopDictationState({
    this.state = DictationState.idle,
    this.message = '',
    this.accessibility = false,
    this.microphone = false,
    this.audioOnly = false,
  });

  final DictationState state;
  final String message;
  final bool accessibility;
  final bool microphone;

  /// The active recording is saved as audio without transcribing.
  final bool audioOnly;
}

final desktopDictationProvider = NotifierProvider<DesktopDictationNotifier, DesktopDictationState?>(
  DesktopDictationNotifier.new,
);

/// macOS dictation: hold Right Option to talk (or tap it to start and tap again to stop), text is pasted into the
/// frontmost app, and the field is watched briefly afterwards to learn from corrections. Null on other platforms.
class DesktopDictationNotifier extends Notifier<DesktopDictationState?> {
  static const _channel = MethodChannel('pocketflow/desktop');

  /// Hotkey and `level` (mic loudness, 0..1) events. Shared: an EventChannel supports only one native listener.
  static final Stream<Map<Object?, Object?>> events = const EventChannel('pocketflow/desktop_events')
      .receiveBroadcastStream()
      .cast<Map<Object?, Object?>>()
      .asBroadcastStream();
  static const _tapMillis = 300;
  static const _minAudioMillis = 400;

  DateTime? _downAt;
  bool _latched = false;
  String? _appId;
  String? _audioPath;
  Timer? _watch;

  @override
  DesktopDictationState? build() {
    if (!Platform.isMacOS) return null;
    final subscription = events.listen(_onEvent);
    ref.onDispose(() {
      subscription.cancel();
      _watch?.cancel();
    });
    unawaited(refreshPermissions());
    return const DesktopDictationState();
  }

  Future<void> refreshPermissions() async {
    final permissions = await _channel.invokeMapMethod<String, bool>('permissions') ?? const {};
    _update(accessibility: permissions['accessibility'] ?? false, microphone: permissions['microphone'] ?? false);
  }

  Future<void> requestAccessibility() async {
    await _channel.invokeMethod<bool>('requestAccessibility');
    await refreshPermissions();
  }

  Future<void> requestMicrophone() async {
    await _channel.invokeMethod<bool>('requestMicrophone');
    await refreshPermissions();
  }

  /// Tap-to-talk from the window's orb: start (latched until the next tap) or finish.
  Future<void> toggle() async {
    switch (state?.state) {
      case DictationState.listening:
        await _stop();
      case DictationState.transcribing || null:
        return;
      default:
        _latched = true;
        await _start();
    }
  }

  /// Starts or finishes a recording that's saved without transcribing. Leaves a dictation in progress alone.
  Future<void> toggleRecording() async {
    switch (state) {
      case DesktopDictationState(state: DictationState.listening, audioOnly: true):
        await _stop();
      case DesktopDictationState(state: DictationState.idle || DictationState.error):
        _latched = true;
        await _start(audioOnly: true);
    }
  }

  void _onEvent(Map<Object?, Object?> event) {
    final current = state;
    if (current == null) return;
    switch (event['type']) {
      case 'hotkey' when event['down'] == true:
        if (current.state == DictationState.listening && _latched) {
          unawaited(_stop());
        } else if (current.state != DictationState.listening && current.state != DictationState.transcribing) {
          _downAt = DateTime.now();
          _latched = false;
          unawaited(_start());
        }
      case 'hotkey':
        final downAt = _downAt;
        if (current.state != DictationState.listening || _latched || downAt == null) return;
        if (DateTime.now().difference(downAt).inMilliseconds < _tapMillis) {
          _latched = true; // a quick tap: keep listening until the next tap
          _update(message: 'Listening. Tap Right Option to finish.');
        } else {
          unawaited(_stop());
        }
      case 'hotkeyCancel':
        if (current.state == DictationState.listening && !_latched) unawaited(_cancel());
    }
  }

  Future<void> _start({bool audioOnly = false}) async {
    _finishWatch();
    _appId = audioOnly ? null : await _channel.invokeMethod<String>('frontmostApp');
    final path = '${(await getTemporaryDirectory()).path}/pocketflow_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final started = await _channel.invokeMethod<bool>('startRecording', {'path': path}) ?? false;
    if (!started) {
      _setState(DictationState.error, 'Couldn’t start the microphone. Allow it in PocketFlow.');
      return;
    }
    _audioPath = path;
    _setState(DictationState.listening, audioOnly ? 'Recording…' : 'Listening…', audioOnly: audioOnly);
    if (!audioOnly) unawaited(ref.read(dictationPipelineProvider).warmUp());
  }

  Future<void> _cancel() async {
    await _channel.invokeMethod<int>('stopRecording');
    _deleteAudio();
    _setState(DictationState.idle, '');
  }

  Future<void> _stop() async {
    final released = Stopwatch()..start();
    final millis = await _channel.invokeMethod<int>('stopRecording') ?? 0;
    final path = _audioPath;
    if (path == null || millis < _minAudioMillis) {
      _deleteAudio();
      _setState(DictationState.idle, '');
      return;
    }
    if (state?.audioOnly ?? false) return _saveRecording(path, millis);
    _setState(DictationState.transcribing, 'Writing…');
    try {
      final result = await ref
          .read(dictationPipelineProvider)
          .process(audio: File(path), appId: _appId, audioMillis: millis);
      if (result.text.isEmpty) {
        _setState(DictationState.idle, 'Didn’t catch that.');
        return;
      }
      await _channel.invokeMethod<void>('paste', {'text': result.text});
      LoggerService.i('Released → pasted in ${released.elapsedMilliseconds} ms');
      _setState(DictationState.idle, result.warning ?? '');
      unawaited(ref.read(historyProvider.notifier).refresh());
      _watchForCorrections(result.text);
    } on TranscriptionSavedException catch (e) {
      _setState(DictationState.error, e.toString());
      unawaited(ref.read(historyProvider.notifier).refresh());
    } on Exception catch (e, stack) {
      LoggerService.e('Dictation failed', e, stack);
      _setState(DictationState.error, e.toString());
    } finally {
      _deleteAudio();
    }
  }

  Future<void> _saveRecording(String path, int millis) async {
    _audioPath = null; // a new recording can start while this one is copied
    _setState(DictationState.idle, '');
    final audio = File(path);
    try {
      await ref.read(dictationPipelineProvider).saveRecording(audio: audio, audioMillis: millis);
      unawaited(ref.read(historyProvider.notifier).refresh());
    } on Exception catch (e, stack) {
      LoggerService.e('Saving a recording failed', e, stack);
      _setState(DictationState.error, e.toString());
    } finally {
      if (audio.existsSync()) audio.deleteSync();
    }
  }

  /// Polls the focused field for a minute (or until the user switches apps or dictates again).
  void _watchForCorrections(String inserted) {
    final appId = _appId;
    String? latest;
    var ticks = 0;
    _watch = Timer.periodic(const Duration(seconds: 1), (timer) async {
      ticks++;
      final frontmost = await _channel.invokeMethod<String>('frontmostApp');
      if (frontmost != appId || ticks >= 60) {
        _finishWatch(inserted: inserted, latest: latest);
        return;
      }
      latest = await _channel.invokeMethod<String>('focusedText') ?? latest;
    });
  }

  void _finishWatch({String? inserted, String? latest}) {
    _watch?.cancel();
    _watch = null;
    if (inserted == null || latest == null || latest.contains(inserted)) return;
    unawaited(_learn(inserted, latest));
  }

  Future<void> _learn(String inserted, String fieldText) async {
    try {
      final learned = await ref.read(dictationPipelineProvider).learnFromEdit(inserted: inserted, fieldText: fieldText);
      if (learned.isEmpty) return;
      _update(message: 'Learned ${learned.map((l) => l.term).join(', ')}');
      await ref.read(vocabularyProvider.notifier).refresh();
    } on Exception catch (e) {
      LoggerService.w('Learning from an edit failed', e);
    }
  }

  void _deleteAudio() {
    final path = _audioPath;
    _audioPath = null;
    if (path != null && File(path).existsSync()) File(path).deleteSync();
  }

  void _setState(DictationState dictation, String message, {bool audioOnly = false}) {
    _update(state: dictation, message: message, audioOnly: audioOnly);
    unawaited(_channel.invokeMethod<void>('setStatus', {'state': dictation.name}));
  }

  void _update({DictationState? state, String? message, bool? accessibility, bool? microphone, bool? audioOnly}) {
    final current = this.state;
    if (current == null) return;
    this.state = current.copyWith(
      state: state,
      message: message,
      accessibility: accessibility,
      microphone: microphone,
      audioOnly: audioOnly,
    );
  }
}
