// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'android_bridge.dart';

class DictationStateMapper extends EnumMapper<DictationState> {
  DictationStateMapper._();

  static DictationStateMapper? _instance;
  static DictationStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DictationStateMapper._());
    }
    return _instance!;
  }

  static DictationState fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DictationState decode(dynamic value) {
    switch (value) {
      case r'idle':
        return DictationState.idle;
      case r'listening':
        return DictationState.listening;
      case r'transcribing':
        return DictationState.transcribing;
      case r'error':
        return DictationState.error;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(DictationState self) {
    switch (self) {
      case DictationState.idle:
        return r'idle';
      case DictationState.listening:
        return r'listening';
      case DictationState.transcribing:
        return r'transcribing';
      case DictationState.error:
        return r'error';
    }
  }
}

extension DictationStateMapperExtension on DictationState {
  String toValue() {
    DictationStateMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DictationState>(this) as String;
  }
}

class BubbleStyleMapper extends EnumMapper<BubbleStyle> {
  BubbleStyleMapper._();

  static BubbleStyleMapper? _instance;
  static BubbleStyleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BubbleStyleMapper._());
    }
    return _instance!;
  }

  static BubbleStyle fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  BubbleStyle decode(dynamic value) {
    switch (value) {
      case r'auto':
        return BubbleStyle.auto;
      case r'light':
        return BubbleStyle.light;
      case r'dark':
        return BubbleStyle.dark;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(BubbleStyle self) {
    switch (self) {
      case BubbleStyle.auto:
        return r'auto';
      case BubbleStyle.light:
        return r'light';
      case BubbleStyle.dark:
        return r'dark';
    }
  }
}

extension BubbleStyleMapperExtension on BubbleStyle {
  String toValue() {
    BubbleStyleMapper.ensureInitialized();
    return MapperContainer.globals.toValue<BubbleStyle>(this) as String;
  }
}

class HotkeyModeMapper extends EnumMapper<HotkeyMode> {
  HotkeyModeMapper._();

  static HotkeyModeMapper? _instance;
  static HotkeyModeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HotkeyModeMapper._());
    }
    return _instance!;
  }

  static HotkeyMode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  HotkeyMode decode(dynamic value) {
    switch (value) {
      case r'capsLock':
        return HotkeyMode.capsLock;
      case r'ctrlShiftSpace':
        return HotkeyMode.ctrlShiftSpace;
      case r'ctrlAltSpace':
        return HotkeyMode.ctrlAltSpace;
      case r'altSpace':
        return HotkeyMode.altSpace;
      case r'off':
        return HotkeyMode.off;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(HotkeyMode self) {
    switch (self) {
      case HotkeyMode.capsLock:
        return r'capsLock';
      case HotkeyMode.ctrlShiftSpace:
        return r'ctrlShiftSpace';
      case HotkeyMode.ctrlAltSpace:
        return r'ctrlAltSpace';
      case HotkeyMode.altSpace:
        return r'altSpace';
      case HotkeyMode.off:
        return r'off';
    }
  }
}

extension HotkeyModeMapperExtension on HotkeyMode {
  String toValue() {
    HotkeyModeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<HotkeyMode>(this) as String;
  }
}

class AndroidStatusMapper extends ClassMapperBase<AndroidStatus> {
  AndroidStatusMapper._();

  static AndroidStatusMapper? _instance;
  static AndroidStatusMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AndroidStatusMapper._());
      DictationStateMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AndroidStatus';

  static bool _$micPermission(AndroidStatus v) => v.micPermission;
  static const Field<AndroidStatus, bool> _f$micPermission = Field(
    'micPermission',
    _$micPermission,
    opt: true,
    def: false,
  );
  static bool _$notificationPermission(AndroidStatus v) =>
      v.notificationPermission;
  static const Field<AndroidStatus, bool> _f$notificationPermission = Field(
    'notificationPermission',
    _$notificationPermission,
    opt: true,
    def: false,
  );
  static bool _$accessibilityEnabled(AndroidStatus v) => v.accessibilityEnabled;
  static const Field<AndroidStatus, bool> _f$accessibilityEnabled = Field(
    'accessibilityEnabled',
    _$accessibilityEnabled,
    opt: true,
    def: false,
  );
  static bool _$keyboardEnabled(AndroidStatus v) => v.keyboardEnabled;
  static const Field<AndroidStatus, bool> _f$keyboardEnabled = Field(
    'keyboardEnabled',
    _$keyboardEnabled,
    opt: true,
    def: false,
  );
  static bool _$secureSettingsGranted(AndroidStatus v) =>
      v.secureSettingsGranted;
  static const Field<AndroidStatus, bool> _f$secureSettingsGranted = Field(
    'secureSettingsGranted',
    _$secureSettingsGranted,
    opt: true,
    def: false,
  );
  static bool _$armed(AndroidStatus v) => v.armed;
  static const Field<AndroidStatus, bool> _f$armed = Field(
    'armed',
    _$armed,
    opt: true,
    def: false,
  );
  static bool _$walkMode(AndroidStatus v) => v.walkMode;
  static const Field<AndroidStatus, bool> _f$walkMode = Field(
    'walkMode',
    _$walkMode,
    opt: true,
    def: false,
  );
  static bool _$bluetoothMicAvailable(AndroidStatus v) =>
      v.bluetoothMicAvailable;
  static const Field<AndroidStatus, bool> _f$bluetoothMicAvailable = Field(
    'bluetoothMicAvailable',
    _$bluetoothMicAvailable,
    opt: true,
    def: false,
  );
  static DictationState _$state(AndroidStatus v) => v.state;
  static const Field<AndroidStatus, DictationState> _f$state = Field(
    'state',
    _$state,
    opt: true,
    def: DictationState.idle,
  );
  static String _$message(AndroidStatus v) => v.message;
  static const Field<AndroidStatus, String> _f$message = Field(
    'message',
    _$message,
    opt: true,
    def: '',
  );

  @override
  final MappableFields<AndroidStatus> fields = const {
    #micPermission: _f$micPermission,
    #notificationPermission: _f$notificationPermission,
    #accessibilityEnabled: _f$accessibilityEnabled,
    #keyboardEnabled: _f$keyboardEnabled,
    #secureSettingsGranted: _f$secureSettingsGranted,
    #armed: _f$armed,
    #walkMode: _f$walkMode,
    #bluetoothMicAvailable: _f$bluetoothMicAvailable,
    #state: _f$state,
    #message: _f$message,
  };

  static AndroidStatus _instantiate(DecodingData data) {
    return AndroidStatus(
      micPermission: data.dec(_f$micPermission),
      notificationPermission: data.dec(_f$notificationPermission),
      accessibilityEnabled: data.dec(_f$accessibilityEnabled),
      keyboardEnabled: data.dec(_f$keyboardEnabled),
      secureSettingsGranted: data.dec(_f$secureSettingsGranted),
      armed: data.dec(_f$armed),
      walkMode: data.dec(_f$walkMode),
      bluetoothMicAvailable: data.dec(_f$bluetoothMicAvailable),
      state: data.dec(_f$state),
      message: data.dec(_f$message),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AndroidStatus fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AndroidStatus>(map);
  }

  static AndroidStatus fromJson(String json) {
    return ensureInitialized().decodeJson<AndroidStatus>(json);
  }
}

mixin AndroidStatusMappable {
  String toJson() {
    return AndroidStatusMapper.ensureInitialized().encodeJson<AndroidStatus>(
      this as AndroidStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return AndroidStatusMapper.ensureInitialized().encodeMap<AndroidStatus>(
      this as AndroidStatus,
    );
  }

  AndroidStatusCopyWith<AndroidStatus, AndroidStatus, AndroidStatus>
  get copyWith => _AndroidStatusCopyWithImpl<AndroidStatus, AndroidStatus>(
    this as AndroidStatus,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return AndroidStatusMapper.ensureInitialized().stringifyValue(
      this as AndroidStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    return AndroidStatusMapper.ensureInitialized().equalsValue(
      this as AndroidStatus,
      other,
    );
  }

  @override
  int get hashCode {
    return AndroidStatusMapper.ensureInitialized().hashValue(
      this as AndroidStatus,
    );
  }
}

extension AndroidStatusValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AndroidStatus, $Out> {
  AndroidStatusCopyWith<$R, AndroidStatus, $Out> get $asAndroidStatus =>
      $base.as((v, t, t2) => _AndroidStatusCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AndroidStatusCopyWith<$R, $In extends AndroidStatus, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    bool? micPermission,
    bool? notificationPermission,
    bool? accessibilityEnabled,
    bool? keyboardEnabled,
    bool? secureSettingsGranted,
    bool? armed,
    bool? walkMode,
    bool? bluetoothMicAvailable,
    DictationState? state,
    String? message,
  });
  AndroidStatusCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AndroidStatusCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AndroidStatus, $Out>
    implements AndroidStatusCopyWith<$R, AndroidStatus, $Out> {
  _AndroidStatusCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AndroidStatus> $mapper =
      AndroidStatusMapper.ensureInitialized();
  @override
  $R call({
    bool? micPermission,
    bool? notificationPermission,
    bool? accessibilityEnabled,
    bool? keyboardEnabled,
    bool? secureSettingsGranted,
    bool? armed,
    bool? walkMode,
    bool? bluetoothMicAvailable,
    DictationState? state,
    String? message,
  }) => $apply(
    FieldCopyWithData({
      if (micPermission != null) #micPermission: micPermission,
      if (notificationPermission != null)
        #notificationPermission: notificationPermission,
      if (accessibilityEnabled != null)
        #accessibilityEnabled: accessibilityEnabled,
      if (keyboardEnabled != null) #keyboardEnabled: keyboardEnabled,
      if (secureSettingsGranted != null)
        #secureSettingsGranted: secureSettingsGranted,
      if (armed != null) #armed: armed,
      if (walkMode != null) #walkMode: walkMode,
      if (bluetoothMicAvailable != null)
        #bluetoothMicAvailable: bluetoothMicAvailable,
      if (state != null) #state: state,
      if (message != null) #message: message,
    }),
  );
  @override
  AndroidStatus $make(CopyWithData data) => AndroidStatus(
    micPermission: data.get(#micPermission, or: $value.micPermission),
    notificationPermission: data.get(
      #notificationPermission,
      or: $value.notificationPermission,
    ),
    accessibilityEnabled: data.get(
      #accessibilityEnabled,
      or: $value.accessibilityEnabled,
    ),
    keyboardEnabled: data.get(#keyboardEnabled, or: $value.keyboardEnabled),
    secureSettingsGranted: data.get(
      #secureSettingsGranted,
      or: $value.secureSettingsGranted,
    ),
    armed: data.get(#armed, or: $value.armed),
    walkMode: data.get(#walkMode, or: $value.walkMode),
    bluetoothMicAvailable: data.get(
      #bluetoothMicAvailable,
      or: $value.bluetoothMicAvailable,
    ),
    state: data.get(#state, or: $value.state),
    message: data.get(#message, or: $value.message),
  );

  @override
  AndroidStatusCopyWith<$R2, AndroidStatus, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AndroidStatusCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AndroidDeviceSettingsMapper
    extends ClassMapperBase<AndroidDeviceSettings> {
  AndroidDeviceSettingsMapper._();

  static AndroidDeviceSettingsMapper? _instance;
  static AndroidDeviceSettingsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AndroidDeviceSettingsMapper._());
      HotkeyModeMapper.ensureInitialized();
      BubbleStyleMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AndroidDeviceSettings';

  static HotkeyMode _$hotkeyMode(AndroidDeviceSettings v) => v.hotkeyMode;
  static const Field<AndroidDeviceSettings, HotkeyMode> _f$hotkeyMode = Field(
    'hotkeyMode',
    _$hotkeyMode,
    opt: true,
    def: HotkeyMode.capsLock,
  );
  static bool _$bluetoothMic(AndroidDeviceSettings v) => v.bluetoothMic;
  static const Field<AndroidDeviceSettings, bool> _f$bluetoothMic = Field(
    'bluetoothMic',
    _$bluetoothMic,
    opt: true,
    def: true,
  );
  static bool _$bubble(AndroidDeviceSettings v) => v.bubble;
  static const Field<AndroidDeviceSettings, bool> _f$bubble = Field(
    'bubble',
    _$bubble,
    opt: true,
    def: true,
  );
  static BubbleStyle _$bubbleStyle(AndroidDeviceSettings v) => v.bubbleStyle;
  static const Field<AndroidDeviceSettings, BubbleStyle> _f$bubbleStyle = Field(
    'bubbleStyle',
    _$bubbleStyle,
    opt: true,
    def: BubbleStyle.auto,
  );
  static bool _$remoteDesktopTyping(AndroidDeviceSettings v) =>
      v.remoteDesktopTyping;
  static const Field<AndroidDeviceSettings, bool> _f$remoteDesktopTyping =
      Field('remoteDesktopTyping', _$remoteDesktopTyping, opt: true, def: true);
  static int _$walkAutoStopSeconds(AndroidDeviceSettings v) =>
      v.walkAutoStopSeconds;
  static const Field<AndroidDeviceSettings, int> _f$walkAutoStopSeconds = Field(
    'walkAutoStopSeconds',
    _$walkAutoStopSeconds,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<AndroidDeviceSettings> fields = const {
    #hotkeyMode: _f$hotkeyMode,
    #bluetoothMic: _f$bluetoothMic,
    #bubble: _f$bubble,
    #bubbleStyle: _f$bubbleStyle,
    #remoteDesktopTyping: _f$remoteDesktopTyping,
    #walkAutoStopSeconds: _f$walkAutoStopSeconds,
  };

  static AndroidDeviceSettings _instantiate(DecodingData data) {
    return AndroidDeviceSettings(
      hotkeyMode: data.dec(_f$hotkeyMode),
      bluetoothMic: data.dec(_f$bluetoothMic),
      bubble: data.dec(_f$bubble),
      bubbleStyle: data.dec(_f$bubbleStyle),
      remoteDesktopTyping: data.dec(_f$remoteDesktopTyping),
      walkAutoStopSeconds: data.dec(_f$walkAutoStopSeconds),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AndroidDeviceSettings fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AndroidDeviceSettings>(map);
  }

  static AndroidDeviceSettings fromJson(String json) {
    return ensureInitialized().decodeJson<AndroidDeviceSettings>(json);
  }
}

mixin AndroidDeviceSettingsMappable {
  String toJson() {
    return AndroidDeviceSettingsMapper.ensureInitialized()
        .encodeJson<AndroidDeviceSettings>(this as AndroidDeviceSettings);
  }

  Map<String, dynamic> toMap() {
    return AndroidDeviceSettingsMapper.ensureInitialized()
        .encodeMap<AndroidDeviceSettings>(this as AndroidDeviceSettings);
  }

  AndroidDeviceSettingsCopyWith<
    AndroidDeviceSettings,
    AndroidDeviceSettings,
    AndroidDeviceSettings
  >
  get copyWith =>
      _AndroidDeviceSettingsCopyWithImpl<
        AndroidDeviceSettings,
        AndroidDeviceSettings
      >(this as AndroidDeviceSettings, $identity, $identity);
  @override
  String toString() {
    return AndroidDeviceSettingsMapper.ensureInitialized().stringifyValue(
      this as AndroidDeviceSettings,
    );
  }

  @override
  bool operator ==(Object other) {
    return AndroidDeviceSettingsMapper.ensureInitialized().equalsValue(
      this as AndroidDeviceSettings,
      other,
    );
  }

  @override
  int get hashCode {
    return AndroidDeviceSettingsMapper.ensureInitialized().hashValue(
      this as AndroidDeviceSettings,
    );
  }
}

extension AndroidDeviceSettingsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AndroidDeviceSettings, $Out> {
  AndroidDeviceSettingsCopyWith<$R, AndroidDeviceSettings, $Out>
  get $asAndroidDeviceSettings => $base.as(
    (v, t, t2) => _AndroidDeviceSettingsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class AndroidDeviceSettingsCopyWith<
  $R,
  $In extends AndroidDeviceSettings,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    HotkeyMode? hotkeyMode,
    bool? bluetoothMic,
    bool? bubble,
    BubbleStyle? bubbleStyle,
    bool? remoteDesktopTyping,
    int? walkAutoStopSeconds,
  });
  AndroidDeviceSettingsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AndroidDeviceSettingsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AndroidDeviceSettings, $Out>
    implements AndroidDeviceSettingsCopyWith<$R, AndroidDeviceSettings, $Out> {
  _AndroidDeviceSettingsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AndroidDeviceSettings> $mapper =
      AndroidDeviceSettingsMapper.ensureInitialized();
  @override
  $R call({
    HotkeyMode? hotkeyMode,
    bool? bluetoothMic,
    bool? bubble,
    BubbleStyle? bubbleStyle,
    bool? remoteDesktopTyping,
    int? walkAutoStopSeconds,
  }) => $apply(
    FieldCopyWithData({
      if (hotkeyMode != null) #hotkeyMode: hotkeyMode,
      if (bluetoothMic != null) #bluetoothMic: bluetoothMic,
      if (bubble != null) #bubble: bubble,
      if (bubbleStyle != null) #bubbleStyle: bubbleStyle,
      if (remoteDesktopTyping != null)
        #remoteDesktopTyping: remoteDesktopTyping,
      if (walkAutoStopSeconds != null)
        #walkAutoStopSeconds: walkAutoStopSeconds,
    }),
  );
  @override
  AndroidDeviceSettings $make(CopyWithData data) => AndroidDeviceSettings(
    hotkeyMode: data.get(#hotkeyMode, or: $value.hotkeyMode),
    bluetoothMic: data.get(#bluetoothMic, or: $value.bluetoothMic),
    bubble: data.get(#bubble, or: $value.bubble),
    bubbleStyle: data.get(#bubbleStyle, or: $value.bubbleStyle),
    remoteDesktopTyping: data.get(
      #remoteDesktopTyping,
      or: $value.remoteDesktopTyping,
    ),
    walkAutoStopSeconds: data.get(
      #walkAutoStopSeconds,
      or: $value.walkAutoStopSeconds,
    ),
  );

  @override
  AndroidDeviceSettingsCopyWith<$R2, AndroidDeviceSettings, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AndroidDeviceSettingsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

