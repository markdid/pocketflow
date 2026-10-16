// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'models.dart';

class TermSourceMapper extends EnumMapper<TermSource> {
  TermSourceMapper._();

  static TermSourceMapper? _instance;
  static TermSourceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TermSourceMapper._());
    }
    return _instance!;
  }

  static TermSource fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  TermSource decode(dynamic value) {
    switch (value) {
      case r'manual':
        return TermSource.manual;
      case r'learned':
        return TermSource.learned;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(TermSource self) {
    switch (self) {
      case TermSource.manual:
        return r'manual';
      case TermSource.learned:
        return r'learned';
    }
  }
}

extension TermSourceMapperExtension on TermSource {
  String toValue() {
    TermSourceMapper.ensureInitialized();
    return MapperContainer.globals.toValue<TermSource>(this) as String;
  }
}

class DictationModeMapper extends EnumMapper<DictationMode> {
  DictationModeMapper._();

  static DictationModeMapper? _instance;
  static DictationModeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DictationModeMapper._());
    }
    return _instance!;
  }

  static DictationMode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DictationMode decode(dynamic value) {
    switch (value) {
      case r'dictation':
        return DictationMode.dictation;
      case r'memo':
        return DictationMode.memo;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(DictationMode self) {
    switch (self) {
      case DictationMode.dictation:
        return r'dictation';
      case DictationMode.memo:
        return r'memo';
    }
  }
}

extension DictationModeMapperExtension on DictationMode {
  String toValue() {
    DictationModeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DictationMode>(this) as String;
  }
}

class AppSettingsMapper extends ClassMapperBase<AppSettings> {
  AppSettingsMapper._();

  static AppSettingsMapper? _instance;
  static AppSettingsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AppSettingsMapper._());
      DictationStyleMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AppSettings';

  static String _$apiBaseUrl(AppSettings v) => v.apiBaseUrl;
  static const Field<AppSettings, String> _f$apiBaseUrl = Field(
    'apiBaseUrl',
    _$apiBaseUrl,
    opt: true,
    def: groqBaseUrl,
  );
  static String _$transcriptionModel(AppSettings v) => v.transcriptionModel;
  static const Field<AppSettings, String> _f$transcriptionModel = Field(
    'transcriptionModel',
    _$transcriptionModel,
    opt: true,
    def: 'whisper-large-v3-turbo',
  );
  static String _$cleanupModel(AppSettings v) => v.cleanupModel;
  static const Field<AppSettings, String> _f$cleanupModel = Field(
    'cleanupModel',
    _$cleanupModel,
    opt: true,
    def: 'openai/gpt-oss-20b',
  );
  static bool _$cleanupEnabled(AppSettings v) => v.cleanupEnabled;
  static const Field<AppSettings, bool> _f$cleanupEnabled = Field(
    'cleanupEnabled',
    _$cleanupEnabled,
    opt: true,
    def: true,
  );
  static String _$language(AppSettings v) => v.language;
  static const Field<AppSettings, String> _f$language = Field(
    'language',
    _$language,
    opt: true,
    def: '',
  );
  static bool _$learnFromCorrections(AppSettings v) => v.learnFromCorrections;
  static const Field<AppSettings, bool> _f$learnFromCorrections = Field(
    'learnFromCorrections',
    _$learnFromCorrections,
    opt: true,
    def: true,
  );
  static String _$customInstructions(AppSettings v) => v.customInstructions;
  static const Field<AppSettings, String> _f$customInstructions = Field(
    'customInstructions',
    _$customInstructions,
    opt: true,
    def: '',
  );
  static Map<String, DictationStyle> _$appStyles(AppSettings v) => v.appStyles;
  static const Field<AppSettings, Map<String, DictationStyle>> _f$appStyles =
      Field('appStyles', _$appStyles, opt: true, def: const {});

  @override
  final MappableFields<AppSettings> fields = const {
    #apiBaseUrl: _f$apiBaseUrl,
    #transcriptionModel: _f$transcriptionModel,
    #cleanupModel: _f$cleanupModel,
    #cleanupEnabled: _f$cleanupEnabled,
    #language: _f$language,
    #learnFromCorrections: _f$learnFromCorrections,
    #customInstructions: _f$customInstructions,
    #appStyles: _f$appStyles,
  };

  static AppSettings _instantiate(DecodingData data) {
    return AppSettings(
      apiBaseUrl: data.dec(_f$apiBaseUrl),
      transcriptionModel: data.dec(_f$transcriptionModel),
      cleanupModel: data.dec(_f$cleanupModel),
      cleanupEnabled: data.dec(_f$cleanupEnabled),
      language: data.dec(_f$language),
      learnFromCorrections: data.dec(_f$learnFromCorrections),
      customInstructions: data.dec(_f$customInstructions),
      appStyles: data.dec(_f$appStyles),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AppSettings fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AppSettings>(map);
  }

  static AppSettings fromJson(String json) {
    return ensureInitialized().decodeJson<AppSettings>(json);
  }
}

mixin AppSettingsMappable {
  String toJson() {
    return AppSettingsMapper.ensureInitialized().encodeJson<AppSettings>(
      this as AppSettings,
    );
  }

  Map<String, dynamic> toMap() {
    return AppSettingsMapper.ensureInitialized().encodeMap<AppSettings>(
      this as AppSettings,
    );
  }

  AppSettingsCopyWith<AppSettings, AppSettings, AppSettings> get copyWith =>
      _AppSettingsCopyWithImpl<AppSettings, AppSettings>(
        this as AppSettings,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AppSettingsMapper.ensureInitialized().stringifyValue(
      this as AppSettings,
    );
  }

  @override
  bool operator ==(Object other) {
    return AppSettingsMapper.ensureInitialized().equalsValue(
      this as AppSettings,
      other,
    );
  }

  @override
  int get hashCode {
    return AppSettingsMapper.ensureInitialized().hashValue(this as AppSettings);
  }
}

extension AppSettingsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AppSettings, $Out> {
  AppSettingsCopyWith<$R, AppSettings, $Out> get $asAppSettings =>
      $base.as((v, t, t2) => _AppSettingsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AppSettingsCopyWith<$R, $In extends AppSettings, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<
    $R,
    String,
    DictationStyle,
    ObjectCopyWith<$R, DictationStyle, DictationStyle>
  >
  get appStyles;
  $R call({
    String? apiBaseUrl,
    String? transcriptionModel,
    String? cleanupModel,
    bool? cleanupEnabled,
    String? language,
    bool? learnFromCorrections,
    String? customInstructions,
    Map<String, DictationStyle>? appStyles,
  });
  AppSettingsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AppSettingsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AppSettings, $Out>
    implements AppSettingsCopyWith<$R, AppSettings, $Out> {
  _AppSettingsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AppSettings> $mapper =
      AppSettingsMapper.ensureInitialized();
  @override
  MapCopyWith<
    $R,
    String,
    DictationStyle,
    ObjectCopyWith<$R, DictationStyle, DictationStyle>
  >
  get appStyles => MapCopyWith(
    $value.appStyles,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(appStyles: v),
  );
  @override
  $R call({
    String? apiBaseUrl,
    String? transcriptionModel,
    String? cleanupModel,
    bool? cleanupEnabled,
    String? language,
    bool? learnFromCorrections,
    String? customInstructions,
    Map<String, DictationStyle>? appStyles,
  }) => $apply(
    FieldCopyWithData({
      if (apiBaseUrl != null) #apiBaseUrl: apiBaseUrl,
      if (transcriptionModel != null) #transcriptionModel: transcriptionModel,
      if (cleanupModel != null) #cleanupModel: cleanupModel,
      if (cleanupEnabled != null) #cleanupEnabled: cleanupEnabled,
      if (language != null) #language: language,
      if (learnFromCorrections != null)
        #learnFromCorrections: learnFromCorrections,
      if (customInstructions != null) #customInstructions: customInstructions,
      if (appStyles != null) #appStyles: appStyles,
    }),
  );
  @override
  AppSettings $make(CopyWithData data) => AppSettings(
    apiBaseUrl: data.get(#apiBaseUrl, or: $value.apiBaseUrl),
    transcriptionModel: data.get(
      #transcriptionModel,
      or: $value.transcriptionModel,
    ),
    cleanupModel: data.get(#cleanupModel, or: $value.cleanupModel),
    cleanupEnabled: data.get(#cleanupEnabled, or: $value.cleanupEnabled),
    language: data.get(#language, or: $value.language),
    learnFromCorrections: data.get(
      #learnFromCorrections,
      or: $value.learnFromCorrections,
    ),
    customInstructions: data.get(
      #customInstructions,
      or: $value.customInstructions,
    ),
    appStyles: data.get(#appStyles, or: $value.appStyles),
  );

  @override
  AppSettingsCopyWith<$R2, AppSettings, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AppSettingsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class VocabularyTermMapper extends ClassMapperBase<VocabularyTerm> {
  VocabularyTermMapper._();

  static VocabularyTermMapper? _instance;
  static VocabularyTermMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = VocabularyTermMapper._());
      TermSourceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'VocabularyTerm';

  static String _$term(VocabularyTerm v) => v.term;
  static const Field<VocabularyTerm, String> _f$term = Field('term', _$term);
  static TermSource _$source(VocabularyTerm v) => v.source;
  static const Field<VocabularyTerm, TermSource> _f$source = Field(
    'source',
    _$source,
  );
  static DateTime _$addedAt(VocabularyTerm v) => v.addedAt;
  static const Field<VocabularyTerm, DateTime> _f$addedAt = Field(
    'addedAt',
    _$addedAt,
  );
  static int _$hits(VocabularyTerm v) => v.hits;
  static const Field<VocabularyTerm, int> _f$hits = Field(
    'hits',
    _$hits,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<VocabularyTerm> fields = const {
    #term: _f$term,
    #source: _f$source,
    #addedAt: _f$addedAt,
    #hits: _f$hits,
  };

  static VocabularyTerm _instantiate(DecodingData data) {
    return VocabularyTerm(
      term: data.dec(_f$term),
      source: data.dec(_f$source),
      addedAt: data.dec(_f$addedAt),
      hits: data.dec(_f$hits),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static VocabularyTerm fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<VocabularyTerm>(map);
  }

  static VocabularyTerm fromJson(String json) {
    return ensureInitialized().decodeJson<VocabularyTerm>(json);
  }
}

mixin VocabularyTermMappable {
  String toJson() {
    return VocabularyTermMapper.ensureInitialized().encodeJson<VocabularyTerm>(
      this as VocabularyTerm,
    );
  }

  Map<String, dynamic> toMap() {
    return VocabularyTermMapper.ensureInitialized().encodeMap<VocabularyTerm>(
      this as VocabularyTerm,
    );
  }

  VocabularyTermCopyWith<VocabularyTerm, VocabularyTerm, VocabularyTerm>
  get copyWith => _VocabularyTermCopyWithImpl<VocabularyTerm, VocabularyTerm>(
    this as VocabularyTerm,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return VocabularyTermMapper.ensureInitialized().stringifyValue(
      this as VocabularyTerm,
    );
  }

  @override
  bool operator ==(Object other) {
    return VocabularyTermMapper.ensureInitialized().equalsValue(
      this as VocabularyTerm,
      other,
    );
  }

  @override
  int get hashCode {
    return VocabularyTermMapper.ensureInitialized().hashValue(
      this as VocabularyTerm,
    );
  }
}

extension VocabularyTermValueCopy<$R, $Out>
    on ObjectCopyWith<$R, VocabularyTerm, $Out> {
  VocabularyTermCopyWith<$R, VocabularyTerm, $Out> get $asVocabularyTerm =>
      $base.as((v, t, t2) => _VocabularyTermCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class VocabularyTermCopyWith<$R, $In extends VocabularyTerm, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? term, TermSource? source, DateTime? addedAt, int? hits});
  VocabularyTermCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _VocabularyTermCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, VocabularyTerm, $Out>
    implements VocabularyTermCopyWith<$R, VocabularyTerm, $Out> {
  _VocabularyTermCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<VocabularyTerm> $mapper =
      VocabularyTermMapper.ensureInitialized();
  @override
  $R call({String? term, TermSource? source, DateTime? addedAt, int? hits}) =>
      $apply(
        FieldCopyWithData({
          if (term != null) #term: term,
          if (source != null) #source: source,
          if (addedAt != null) #addedAt: addedAt,
          if (hits != null) #hits: hits,
        }),
      );
  @override
  VocabularyTerm $make(CopyWithData data) => VocabularyTerm(
    term: data.get(#term, or: $value.term),
    source: data.get(#source, or: $value.source),
    addedAt: data.get(#addedAt, or: $value.addedAt),
    hits: data.get(#hits, or: $value.hits),
  );

  @override
  VocabularyTermCopyWith<$R2, VocabularyTerm, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _VocabularyTermCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ReplacementRuleMapper extends ClassMapperBase<ReplacementRule> {
  ReplacementRuleMapper._();

  static ReplacementRuleMapper? _instance;
  static ReplacementRuleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ReplacementRuleMapper._());
      TermSourceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ReplacementRule';

  static String _$from(ReplacementRule v) => v.from;
  static const Field<ReplacementRule, String> _f$from = Field('from', _$from);
  static String _$to(ReplacementRule v) => v.to;
  static const Field<ReplacementRule, String> _f$to = Field('to', _$to);
  static TermSource _$source(ReplacementRule v) => v.source;
  static const Field<ReplacementRule, TermSource> _f$source = Field(
    'source',
    _$source,
  );
  static DateTime _$addedAt(ReplacementRule v) => v.addedAt;
  static const Field<ReplacementRule, DateTime> _f$addedAt = Field(
    'addedAt',
    _$addedAt,
  );

  @override
  final MappableFields<ReplacementRule> fields = const {
    #from: _f$from,
    #to: _f$to,
    #source: _f$source,
    #addedAt: _f$addedAt,
  };

  static ReplacementRule _instantiate(DecodingData data) {
    return ReplacementRule(
      from: data.dec(_f$from),
      to: data.dec(_f$to),
      source: data.dec(_f$source),
      addedAt: data.dec(_f$addedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ReplacementRule fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ReplacementRule>(map);
  }

  static ReplacementRule fromJson(String json) {
    return ensureInitialized().decodeJson<ReplacementRule>(json);
  }
}

mixin ReplacementRuleMappable {
  String toJson() {
    return ReplacementRuleMapper.ensureInitialized()
        .encodeJson<ReplacementRule>(this as ReplacementRule);
  }

  Map<String, dynamic> toMap() {
    return ReplacementRuleMapper.ensureInitialized().encodeMap<ReplacementRule>(
      this as ReplacementRule,
    );
  }

  ReplacementRuleCopyWith<ReplacementRule, ReplacementRule, ReplacementRule>
  get copyWith =>
      _ReplacementRuleCopyWithImpl<ReplacementRule, ReplacementRule>(
        this as ReplacementRule,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ReplacementRuleMapper.ensureInitialized().stringifyValue(
      this as ReplacementRule,
    );
  }

  @override
  bool operator ==(Object other) {
    return ReplacementRuleMapper.ensureInitialized().equalsValue(
      this as ReplacementRule,
      other,
    );
  }

  @override
  int get hashCode {
    return ReplacementRuleMapper.ensureInitialized().hashValue(
      this as ReplacementRule,
    );
  }
}

extension ReplacementRuleValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ReplacementRule, $Out> {
  ReplacementRuleCopyWith<$R, ReplacementRule, $Out> get $asReplacementRule =>
      $base.as((v, t, t2) => _ReplacementRuleCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ReplacementRuleCopyWith<$R, $In extends ReplacementRule, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? from, String? to, TermSource? source, DateTime? addedAt});
  ReplacementRuleCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ReplacementRuleCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ReplacementRule, $Out>
    implements ReplacementRuleCopyWith<$R, ReplacementRule, $Out> {
  _ReplacementRuleCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ReplacementRule> $mapper =
      ReplacementRuleMapper.ensureInitialized();
  @override
  $R call({String? from, String? to, TermSource? source, DateTime? addedAt}) =>
      $apply(
        FieldCopyWithData({
          if (from != null) #from: from,
          if (to != null) #to: to,
          if (source != null) #source: source,
          if (addedAt != null) #addedAt: addedAt,
        }),
      );
  @override
  ReplacementRule $make(CopyWithData data) => ReplacementRule(
    from: data.get(#from, or: $value.from),
    to: data.get(#to, or: $value.to),
    source: data.get(#source, or: $value.source),
    addedAt: data.get(#addedAt, or: $value.addedAt),
  );

  @override
  ReplacementRuleCopyWith<$R2, ReplacementRule, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ReplacementRuleCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class HistoryEntryMapper extends ClassMapperBase<HistoryEntry> {
  HistoryEntryMapper._();

  static HistoryEntryMapper? _instance;
  static HistoryEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HistoryEntryMapper._());
      DictationModeMapper.ensureInitialized();
      DictationStyleMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HistoryEntry';

  static String _$id(HistoryEntry v) => v.id;
  static const Field<HistoryEntry, String> _f$id = Field('id', _$id);
  static DateTime _$createdAt(HistoryEntry v) => v.createdAt;
  static const Field<HistoryEntry, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
  );
  static DictationMode _$mode(HistoryEntry v) => v.mode;
  static const Field<HistoryEntry, DictationMode> _f$mode = Field(
    'mode',
    _$mode,
  );
  static DictationStyle _$style(HistoryEntry v) => v.style;
  static const Field<HistoryEntry, DictationStyle> _f$style = Field(
    'style',
    _$style,
  );
  static String _$rawText(HistoryEntry v) => v.rawText;
  static const Field<HistoryEntry, String> _f$rawText = Field(
    'rawText',
    _$rawText,
  );
  static String _$text(HistoryEntry v) => v.text;
  static const Field<HistoryEntry, String> _f$text = Field('text', _$text);
  static String? _$appId(HistoryEntry v) => v.appId;
  static const Field<HistoryEntry, String> _f$appId = Field(
    'appId',
    _$appId,
    opt: true,
  );
  static String? _$audioPath(HistoryEntry v) => v.audioPath;
  static const Field<HistoryEntry, String> _f$audioPath = Field(
    'audioPath',
    _$audioPath,
    opt: true,
  );
  static int? _$audioMillis(HistoryEntry v) => v.audioMillis;
  static const Field<HistoryEntry, int> _f$audioMillis = Field(
    'audioMillis',
    _$audioMillis,
    opt: true,
  );
  static int? _$processingMillis(HistoryEntry v) => v.processingMillis;
  static const Field<HistoryEntry, int> _f$processingMillis = Field(
    'processingMillis',
    _$processingMillis,
    opt: true,
  );

  @override
  final MappableFields<HistoryEntry> fields = const {
    #id: _f$id,
    #createdAt: _f$createdAt,
    #mode: _f$mode,
    #style: _f$style,
    #rawText: _f$rawText,
    #text: _f$text,
    #appId: _f$appId,
    #audioPath: _f$audioPath,
    #audioMillis: _f$audioMillis,
    #processingMillis: _f$processingMillis,
  };

  static HistoryEntry _instantiate(DecodingData data) {
    return HistoryEntry(
      id: data.dec(_f$id),
      createdAt: data.dec(_f$createdAt),
      mode: data.dec(_f$mode),
      style: data.dec(_f$style),
      rawText: data.dec(_f$rawText),
      text: data.dec(_f$text),
      appId: data.dec(_f$appId),
      audioPath: data.dec(_f$audioPath),
      audioMillis: data.dec(_f$audioMillis),
      processingMillis: data.dec(_f$processingMillis),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HistoryEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HistoryEntry>(map);
  }

  static HistoryEntry fromJson(String json) {
    return ensureInitialized().decodeJson<HistoryEntry>(json);
  }
}

mixin HistoryEntryMappable {
  String toJson() {
    return HistoryEntryMapper.ensureInitialized().encodeJson<HistoryEntry>(
      this as HistoryEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return HistoryEntryMapper.ensureInitialized().encodeMap<HistoryEntry>(
      this as HistoryEntry,
    );
  }

  HistoryEntryCopyWith<HistoryEntry, HistoryEntry, HistoryEntry> get copyWith =>
      _HistoryEntryCopyWithImpl<HistoryEntry, HistoryEntry>(
        this as HistoryEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HistoryEntryMapper.ensureInitialized().stringifyValue(
      this as HistoryEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return HistoryEntryMapper.ensureInitialized().equalsValue(
      this as HistoryEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return HistoryEntryMapper.ensureInitialized().hashValue(
      this as HistoryEntry,
    );
  }
}

extension HistoryEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HistoryEntry, $Out> {
  HistoryEntryCopyWith<$R, HistoryEntry, $Out> get $asHistoryEntry =>
      $base.as((v, t, t2) => _HistoryEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HistoryEntryCopyWith<$R, $In extends HistoryEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    DateTime? createdAt,
    DictationMode? mode,
    DictationStyle? style,
    String? rawText,
    String? text,
    String? appId,
    String? audioPath,
    int? audioMillis,
    int? processingMillis,
  });
  HistoryEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HistoryEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HistoryEntry, $Out>
    implements HistoryEntryCopyWith<$R, HistoryEntry, $Out> {
  _HistoryEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HistoryEntry> $mapper =
      HistoryEntryMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    DateTime? createdAt,
    DictationMode? mode,
    DictationStyle? style,
    String? rawText,
    String? text,
    Object? appId = $none,
    Object? audioPath = $none,
    Object? audioMillis = $none,
    Object? processingMillis = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (createdAt != null) #createdAt: createdAt,
      if (mode != null) #mode: mode,
      if (style != null) #style: style,
      if (rawText != null) #rawText: rawText,
      if (text != null) #text: text,
      if (appId != $none) #appId: appId,
      if (audioPath != $none) #audioPath: audioPath,
      if (audioMillis != $none) #audioMillis: audioMillis,
      if (processingMillis != $none) #processingMillis: processingMillis,
    }),
  );
  @override
  HistoryEntry $make(CopyWithData data) => HistoryEntry(
    id: data.get(#id, or: $value.id),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    mode: data.get(#mode, or: $value.mode),
    style: data.get(#style, or: $value.style),
    rawText: data.get(#rawText, or: $value.rawText),
    text: data.get(#text, or: $value.text),
    appId: data.get(#appId, or: $value.appId),
    audioPath: data.get(#audioPath, or: $value.audioPath),
    audioMillis: data.get(#audioMillis, or: $value.audioMillis),
    processingMillis: data.get(#processingMillis, or: $value.processingMillis),
  );

  @override
  HistoryEntryCopyWith<$R2, HistoryEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HistoryEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LearnedItemMapper extends ClassMapperBase<LearnedItem> {
  LearnedItemMapper._();

  static LearnedItemMapper? _instance;
  static LearnedItemMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LearnedItemMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LearnedItem';

  static String _$heard(LearnedItem v) => v.heard;
  static const Field<LearnedItem, String> _f$heard = Field('heard', _$heard);
  static String _$term(LearnedItem v) => v.term;
  static const Field<LearnedItem, String> _f$term = Field('term', _$term);
  static bool _$addedRule(LearnedItem v) => v.addedRule;
  static const Field<LearnedItem, bool> _f$addedRule = Field(
    'addedRule',
    _$addedRule,
  );

  @override
  final MappableFields<LearnedItem> fields = const {
    #heard: _f$heard,
    #term: _f$term,
    #addedRule: _f$addedRule,
  };

  static LearnedItem _instantiate(DecodingData data) {
    return LearnedItem(
      heard: data.dec(_f$heard),
      term: data.dec(_f$term),
      addedRule: data.dec(_f$addedRule),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LearnedItem fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LearnedItem>(map);
  }

  static LearnedItem fromJson(String json) {
    return ensureInitialized().decodeJson<LearnedItem>(json);
  }
}

mixin LearnedItemMappable {
  String toJson() {
    return LearnedItemMapper.ensureInitialized().encodeJson<LearnedItem>(
      this as LearnedItem,
    );
  }

  Map<String, dynamic> toMap() {
    return LearnedItemMapper.ensureInitialized().encodeMap<LearnedItem>(
      this as LearnedItem,
    );
  }

  LearnedItemCopyWith<LearnedItem, LearnedItem, LearnedItem> get copyWith =>
      _LearnedItemCopyWithImpl<LearnedItem, LearnedItem>(
        this as LearnedItem,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LearnedItemMapper.ensureInitialized().stringifyValue(
      this as LearnedItem,
    );
  }

  @override
  bool operator ==(Object other) {
    return LearnedItemMapper.ensureInitialized().equalsValue(
      this as LearnedItem,
      other,
    );
  }

  @override
  int get hashCode {
    return LearnedItemMapper.ensureInitialized().hashValue(this as LearnedItem);
  }
}

extension LearnedItemValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LearnedItem, $Out> {
  LearnedItemCopyWith<$R, LearnedItem, $Out> get $asLearnedItem =>
      $base.as((v, t, t2) => _LearnedItemCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LearnedItemCopyWith<$R, $In extends LearnedItem, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? heard, String? term, bool? addedRule});
  LearnedItemCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LearnedItemCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LearnedItem, $Out>
    implements LearnedItemCopyWith<$R, LearnedItem, $Out> {
  _LearnedItemCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LearnedItem> $mapper =
      LearnedItemMapper.ensureInitialized();
  @override
  $R call({String? heard, String? term, bool? addedRule}) => $apply(
    FieldCopyWithData({
      if (heard != null) #heard: heard,
      if (term != null) #term: term,
      if (addedRule != null) #addedRule: addedRule,
    }),
  );
  @override
  LearnedItem $make(CopyWithData data) => LearnedItem(
    heard: data.get(#heard, or: $value.heard),
    term: data.get(#term, or: $value.term),
    addedRule: data.get(#addedRule, or: $value.addedRule),
  );

  @override
  LearnedItemCopyWith<$R2, LearnedItem, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LearnedItemCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

