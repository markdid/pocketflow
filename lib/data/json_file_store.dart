import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON documents in the app support directory.
///
/// On Android the UI and the background dictation service run separate Dart isolates, so nothing is cached:
/// every read hits disk and writes go through a temp file + rename to stay atomic.
class JsonFileStore {
  JsonFileStore({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<Directory> get directory => _directory();

  Future<File> _file(String name) async => File('${(await _directory()).path}/$name.json');

  Future<Object?> read(String name) async {
    final file = await _file(name);
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String name, Object? value) async {
    final file = await _file(name);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }
}
