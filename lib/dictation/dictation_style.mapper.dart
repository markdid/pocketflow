// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'dictation_style.dart';

class DictationStyleMapper extends EnumMapper<DictationStyle> {
  DictationStyleMapper._();

  static DictationStyleMapper? _instance;
  static DictationStyleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DictationStyleMapper._());
    }
    return _instance!;
  }

  static DictationStyle fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DictationStyle decode(dynamic value) {
    switch (value) {
      case r'standard':
        return DictationStyle.standard;
      case r'chat':
        return DictationStyle.chat;
      case r'email':
        return DictationStyle.email;
      case r'notes':
        return DictationStyle.notes;
      case r'code':
        return DictationStyle.code;
      case r'memo':
        return DictationStyle.memo;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(DictationStyle self) {
    switch (self) {
      case DictationStyle.standard:
        return r'standard';
      case DictationStyle.chat:
        return r'chat';
      case DictationStyle.email:
        return r'email';
      case DictationStyle.notes:
        return r'notes';
      case DictationStyle.code:
        return r'code';
      case DictationStyle.memo:
        return r'memo';
    }
  }
}

extension DictationStyleMapperExtension on DictationStyle {
  String toValue() {
    DictationStyleMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DictationStyle>(this) as String;
  }
}

