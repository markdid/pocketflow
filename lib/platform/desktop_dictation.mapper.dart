// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'desktop_dictation.dart';

class DesktopDictationStateMapper
    extends ClassMapperBase<DesktopDictationState> {
  DesktopDictationStateMapper._();

  static DesktopDictationStateMapper? _instance;
  static DesktopDictationStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DesktopDictationStateMapper._());
      DictationStateMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DesktopDictationState';

  static DictationState _$state(DesktopDictationState v) => v.state;
  static const Field<DesktopDictationState, DictationState> _f$state = Field(
    'state',
    _$state,
    opt: true,
    def: DictationState.idle,
  );
  static String _$message(DesktopDictationState v) => v.message;
  static const Field<DesktopDictationState, String> _f$message = Field(
    'message',
    _$message,
    opt: true,
    def: '',
  );
  static bool _$accessibility(DesktopDictationState v) => v.accessibility;
  static const Field<DesktopDictationState, bool> _f$accessibility = Field(
    'accessibility',
    _$accessibility,
    opt: true,
    def: false,
  );
  static bool _$microphone(DesktopDictationState v) => v.microphone;
  static const Field<DesktopDictationState, bool> _f$microphone = Field(
    'microphone',
    _$microphone,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<DesktopDictationState> fields = const {
    #state: _f$state,
    #message: _f$message,
    #accessibility: _f$accessibility,
    #microphone: _f$microphone,
  };

  static DesktopDictationState _instantiate(DecodingData data) {
    return DesktopDictationState(
      state: data.dec(_f$state),
      message: data.dec(_f$message),
      accessibility: data.dec(_f$accessibility),
      microphone: data.dec(_f$microphone),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DesktopDictationState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DesktopDictationState>(map);
  }

  static DesktopDictationState fromJson(String json) {
    return ensureInitialized().decodeJson<DesktopDictationState>(json);
  }
}

mixin DesktopDictationStateMappable {
  String toJson() {
    return DesktopDictationStateMapper.ensureInitialized()
        .encodeJson<DesktopDictationState>(this as DesktopDictationState);
  }

  Map<String, dynamic> toMap() {
    return DesktopDictationStateMapper.ensureInitialized()
        .encodeMap<DesktopDictationState>(this as DesktopDictationState);
  }

  DesktopDictationStateCopyWith<
    DesktopDictationState,
    DesktopDictationState,
    DesktopDictationState
  >
  get copyWith =>
      _DesktopDictationStateCopyWithImpl<
        DesktopDictationState,
        DesktopDictationState
      >(this as DesktopDictationState, $identity, $identity);
  @override
  String toString() {
    return DesktopDictationStateMapper.ensureInitialized().stringifyValue(
      this as DesktopDictationState,
    );
  }

  @override
  bool operator ==(Object other) {
    return DesktopDictationStateMapper.ensureInitialized().equalsValue(
      this as DesktopDictationState,
      other,
    );
  }

  @override
  int get hashCode {
    return DesktopDictationStateMapper.ensureInitialized().hashValue(
      this as DesktopDictationState,
    );
  }
}

extension DesktopDictationStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DesktopDictationState, $Out> {
  DesktopDictationStateCopyWith<$R, DesktopDictationState, $Out>
  get $asDesktopDictationState => $base.as(
    (v, t, t2) => _DesktopDictationStateCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DesktopDictationStateCopyWith<
  $R,
  $In extends DesktopDictationState,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    DictationState? state,
    String? message,
    bool? accessibility,
    bool? microphone,
  });
  DesktopDictationStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DesktopDictationStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DesktopDictationState, $Out>
    implements DesktopDictationStateCopyWith<$R, DesktopDictationState, $Out> {
  _DesktopDictationStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DesktopDictationState> $mapper =
      DesktopDictationStateMapper.ensureInitialized();
  @override
  $R call({
    DictationState? state,
    String? message,
    bool? accessibility,
    bool? microphone,
  }) => $apply(
    FieldCopyWithData({
      if (state != null) #state: state,
      if (message != null) #message: message,
      if (accessibility != null) #accessibility: accessibility,
      if (microphone != null) #microphone: microphone,
    }),
  );
  @override
  DesktopDictationState $make(CopyWithData data) => DesktopDictationState(
    state: data.get(#state, or: $value.state),
    message: data.get(#message, or: $value.message),
    accessibility: data.get(#accessibility, or: $value.accessibility),
    microphone: data.get(#microphone, or: $value.microphone),
  );

  @override
  DesktopDictationStateCopyWith<$R2, DesktopDictationState, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DesktopDictationStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

