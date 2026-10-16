import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'android_bridge.mapper.dart';

@MappableEnum()
enum DictationState { idle, listening, transcribing, error }

/// Hardware-keyboard trigger for the accessibility service (Bluetooth keyboards, RustDesk sessions).
@MappableEnum()
enum HotkeyMode {
  capsLock('Caps Lock'),
  ctrlShiftSpace('Ctrl+Shift+Space'),
  ctrlAltSpace('Ctrl+Alt+Space'),
  altSpace('Alt+Space'),
  off('Off');

  const HotkeyMode(this.label);

  final String label;
}

@MappableClass()
class AndroidStatus with AndroidStatusMappable {
  const AndroidStatus({
    this.micPermission = false,
    this.notificationPermission = false,
    this.accessibilityEnabled = false,
    this.keyboardEnabled = false,
    this.secureSettingsGranted = false,
    this.armed = false,
    this.walkMode = false,
    this.bluetoothMicAvailable = false,
    this.state = DictationState.idle,
    this.message = '',
  });

  final bool micPermission;
  final bool notificationPermission;
  final bool accessibilityEnabled;
  final bool keyboardEnabled;

  /// `adb shell pm grant … WRITE_SECURE_SETTINGS`: lets PocketFlow switch keyboards itself for remote desktop typing.
  final bool secureSettingsGranted;
  final bool armed;
  final bool walkMode;
  final bool bluetoothMicAvailable;
  final DictationState state;
  final String message;
}

@MappableClass()
class AndroidDeviceSettings with AndroidDeviceSettingsMappable {
  const AndroidDeviceSettings({
    this.hotkeyMode = HotkeyMode.capsLock,
    this.bluetoothMic = true,
    this.bubble = true,
    this.remoteDesktopTyping = true,
    this.walkAutoStopSeconds = 0,
  });

  final HotkeyMode hotkeyMode;

  /// Record from a connected headset's mic (Bluetooth call audio) instead of the phone's.
  final bool bluetoothMic;

  /// Floating mic button shown next to focused text fields.
  final bool bubble;

  /// Type into RustDesk and other remote-desktop apps key by key through the PocketFlow keyboard.
  final bool remoteDesktopTyping;

  /// Walk mode: stop after this many seconds of silence (0 = only the headset button stops).
  final int walkAutoStopSeconds;
}

final androidBridgeProvider = Provider<AndroidBridge>((ref) => AndroidBridge());

/// The UI's view of the native Android services (accessibility, keyboard, dictation service).
class AndroidBridge {
  static const _channel = MethodChannel('pocketflow/app');
  static const _events = EventChannel('pocketflow/events');

  /// `status`, `history` (a dictation finished), and `learned` events from the native side.
  Stream<Map<Object?, Object?>> events() => _events.receiveBroadcastStream().cast<Map<Object?, Object?>>();

  Future<AndroidStatus> status() async =>
      AndroidStatusMapper.fromMap(_stringKeys(await _channel.invokeMapMethod<Object?, Object?>('status')));

  Future<AndroidDeviceSettings> deviceSettings() async => AndroidDeviceSettingsMapper.fromMap(
    _stringKeys(await _channel.invokeMapMethod<Object?, Object?>('deviceSettings')),
  );

  Future<void> saveDeviceSettings(AndroidDeviceSettings settings) =>
      _channel.invokeMethod('saveDeviceSettings', settings.toMap());

  Future<void> requestPermissions() => _channel.invokeMethod('requestPermissions');
  Future<void> openAccessibilitySettings() => _channel.invokeMethod('openAccessibilitySettings');
  Future<void> openKeyboardSettings() => _channel.invokeMethod('openKeyboardSettings');
  Future<void> setArmed({required bool armed}) => _channel.invokeMethod('setArmed', {'value': armed});
  Future<void> setWalkMode({required bool enabled}) => _channel.invokeMethod('setWalkMode', {'value': enabled});
  Future<void> toggleDictation() => _channel.invokeMethod('toggleDictation');

  static Map<String, Object?> _stringKeys(Map<Object?, Object?>? map) => {
    for (final entry in (map ?? const {}).entries) entry.key.toString(): entry.value,
  };
}
