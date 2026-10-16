import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/json_file_store.dart';
import 'package:pocketflow/dictation/models.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

class HistoryRepository {
  HistoryRepository({JsonFileStore? store}) : _store = store ?? JsonFileStore();

  final JsonFileStore _store;

  static const _limit = 1000;

  /// Newest first.
  Future<List<HistoryEntry>> load() async {
    final json = await _store.read('history');
    if (json is! List<Object?>) return [];
    return [for (final item in json.whereType<Map<String, Object?>>()) HistoryEntryMapper.fromMap(item)];
  }

  Future<void> add(HistoryEntry entry) async {
    final entries = [entry, ...await load()];
    final kept = entries.take(_limit).toList();
    for (final dropped in entries.skip(_limit)) {
      await _deleteAudio(dropped);
    }
    await _store.write('history', [for (final e in kept) e.toMap()]);
  }

  Future<void> remove(String id) async {
    final entries = await load();
    for (final entry in entries.where((e) => e.id == id)) {
      await _deleteAudio(entry);
    }
    await _store.write('history', [
      for (final e in entries)
        if (e.id != id) e.toMap(),
    ]);
  }

  /// Where memo recordings are kept so they can be replayed or re-transcribed.
  Future<Directory> memoDirectory() async {
    final dir = Directory('${(await _store.directory).path}/memos');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _deleteAudio(HistoryEntry entry) async {
    final path = entry.audioPath;
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}
