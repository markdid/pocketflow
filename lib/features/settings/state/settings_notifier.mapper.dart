// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'settings_notifier.dart';

class SettingsStateMapper extends ClassMapperBase<SettingsState> {
  SettingsStateMapper._();

  static SettingsStateMapper? _instance;
  static SettingsStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SettingsStateMapper._());
      AppSettingsMapper.ensureInitialized();
      AndroidDeviceSettingsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SettingsState';

  static AppSettings _$settings(SettingsState v) => v.settings;
  static const Field<SettingsState, AppSettings> _f$settings = Field(
    'settings',
    _$settings,
  );
  static String _$apiKey(SettingsState v) => v.apiKey;
  static const Field<SettingsState, String> _f$apiKey = Field(
    'apiKey',
    _$apiKey,
  );
  static AndroidDeviceSettings? _$device(SettingsState v) => v.device;
  static const Field<SettingsState, AndroidDeviceSettings> _f$device = Field(
    'device',
    _$device,
    opt: true,
  );

  @override
  final MappableFields<SettingsState> fields = const {
    #settings: _f$settings,
    #apiKey: _f$apiKey,
    #device: _f$device,
  };

  static SettingsState _instantiate(DecodingData data) {
    return SettingsState(
      settings: data.dec(_f$settings),
      apiKey: data.dec(_f$apiKey),
      device: data.dec(_f$device),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SettingsState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SettingsState>(map);
  }

  static SettingsState fromJson(String json) {
    return ensureInitialized().decodeJson<SettingsState>(json);
  }
}

mixin SettingsStateMappable {
  String toJson() {
    return SettingsStateMapper.ensureInitialized().encodeJson<SettingsState>(
      this as SettingsState,
    );
  }

  Map<String, dynamic> toMap() {
    return SettingsStateMapper.ensureInitialized().encodeMap<SettingsState>(
      this as SettingsState,
    );
  }

  SettingsStateCopyWith<SettingsState, SettingsState, SettingsState>
  get copyWith => _SettingsStateCopyWithImpl<SettingsState, SettingsState>(
    this as SettingsState,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SettingsStateMapper.ensureInitialized().stringifyValue(
      this as SettingsState,
    );
  }

  @override
  bool operator ==(Object other) {
    return SettingsStateMapper.ensureInitialized().equalsValue(
      this as SettingsState,
      other,
    );
  }

  @override
  int get hashCode {
    return SettingsStateMapper.ensureInitialized().hashValue(
      this as SettingsState,
    );
  }
}

extension SettingsStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SettingsState, $Out> {
  SettingsStateCopyWith<$R, SettingsState, $Out> get $asSettingsState =>
      $base.as((v, t, t2) => _SettingsStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SettingsStateCopyWith<$R, $In extends SettingsState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  AppSettingsCopyWith<$R, AppSettings, AppSettings> get settings;
  AndroidDeviceSettingsCopyWith<
    $R,
    AndroidDeviceSettings,
    AndroidDeviceSettings
  >?
  get device;
  $R call({
    AppSettings? settings,
    String? apiKey,
    AndroidDeviceSettings? device,
  });
  SettingsStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SettingsStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SettingsState, $Out>
    implements SettingsStateCopyWith<$R, SettingsState, $Out> {
  _SettingsStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SettingsState> $mapper =
      SettingsStateMapper.ensureInitialized();
  @override
  AppSettingsCopyWith<$R, AppSettings, AppSettings> get settings =>
      $value.settings.copyWith.$chain((v) => call(settings: v));
  @override
  AndroidDeviceSettingsCopyWith<
    $R,
    AndroidDeviceSettings,
    AndroidDeviceSettings
  >?
  get device => $value.device?.copyWith.$chain((v) => call(device: v));
  @override
  $R call({AppSettings? settings, String? apiKey, Object? device = $none}) =>
      $apply(
        FieldCopyWithData({
          if (settings != null) #settings: settings,
          if (apiKey != null) #apiKey: apiKey,
          if (device != $none) #device: device,
        }),
      );
  @override
  SettingsState $make(CopyWithData data) => SettingsState(
    settings: data.get(#settings, or: $value.settings),
    apiKey: data.get(#apiKey, or: $value.apiKey),
    device: data.get(#device, or: $value.device),
  );

  @override
  SettingsStateCopyWith<$R2, SettingsState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SettingsStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

