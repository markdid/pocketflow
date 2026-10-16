import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketflow/data/json_file_store.dart';
import 'package:pocketflow/dictation/models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsRepository {
  SettingsRepository({JsonFileStore? store, FlutterSecureStorage? secureStorage})
    : _store = store ?? JsonFileStore(),
      // The data-protection keychain needs a signed team entitlement; the login keychain works for local builds.
      _secure = secureStorage ?? const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  final JsonFileStore _store;
  final FlutterSecureStorage _secure;

  static const _apiKey = 'api_key';

  Future<AppSettings> load() async {
    final json = await _store.read('settings');
    if (json is! Map<String, Object?>) return const AppSettings();
    try {
      return AppSettingsMapper.fromMap(json);
    } on Exception {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) => _store.write('settings', settings.toMap());

  Future<String> apiKey() async => (await _secure.read(key: _apiKey))?.trim() ?? '';

  Future<void> setApiKey(String value) => _secure.write(key: _apiKey, value: value.trim());
}
