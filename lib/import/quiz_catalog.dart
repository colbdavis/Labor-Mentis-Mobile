import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/built_in_quiz_packs.dart';
import '../models/quiz_pack.dart';
import 'quiz_import_error.dart';
import 'quiz_yaml_parser.dart';

class QuizCatalog extends ChangeNotifier {
  QuizCatalog({QuizYamlParser? parser}) : _parser = parser ?? QuizYamlParser();

  final QuizYamlParser _parser;
  final Map<String, QuizPack> _imported = {};
  final List<QuizImportIssue> startupErrors = [];

  List<QuizPack> get packs => [...builtInQuizPacks, ..._imported.values];
  List<QuizPack> get importedPacks => _imported.values.toList();
  QuizPack? find(String id) => packs.where((pack) => pack.id == id).firstOrNull;
  bool isBuiltInId(String id) => builtInQuizPacks.any((pack) => pack.id == id);

  Future<void> load() async {
    _imported.clear();
    startupErrors.clear();
    final directory = await _directory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.yaml')) continue;
      try {
        final source = await entity.readAsString();
        final result = _parser.parse(source);
        if (result.isValid) {
          final pack = result.pack as QuizPack;
          if (!isBuiltInId(pack.id)) _imported[pack.id] = pack.asImported();
        } else {
          startupErrors.addAll(result.errors);
        }
      } catch (_) {
        startupErrors.add(
          QuizImportIssue(entity.path, 'Could not read this stored quiz.'),
        );
      }
    }
    notifyListeners();
  }

  Future<void> save(String source, QuizPack pack) async {
    if (isBuiltInId(pack.id)) {
      throw StateError('Built-in quiz IDs cannot be overwritten.');
    }
    final directory = await _directory();
    await directory.create(recursive: true);
    final target = File('${directory.path}/${pack.id}.yaml');
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');
    await temporary.writeAsString(source, flush: true);
    final check = _parser.parse(await temporary.readAsString());
    if (!check.isValid) {
      await temporary.delete();
      throw StateError('The quiz failed validation before saving.');
    }
    if (await backup.exists()) {
      await backup.delete();
    }
    final replacing = await target.exists();
    if (replacing) {
      await target.rename(backup.path);
    }
    try {
      await temporary.rename(target.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
    _imported[pack.id] = pack.asImported();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}/$id.yaml');
    if (await file.exists()) await file.delete();
    _imported.remove(id);
    notifyListeners();
  }

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/quiz_packs');
  }
}
