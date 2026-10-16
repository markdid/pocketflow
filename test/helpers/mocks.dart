import 'package:mocktail/mocktail.dart';
import 'package:pocketflow/data/repositories/history_repository.dart';
import 'package:pocketflow/data/repositories/settings_repository.dart';
import 'package:pocketflow/data/repositories/vocabulary_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockVocabularyRepository extends Mock implements VocabularyRepository {}

class MockHistoryRepository extends Mock implements HistoryRepository {}
