import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/built_in_quiz_packs.dart';
import '../models/quiz_pack.dart';
import 'quiz_folder.dart';
import 'quiz_import_error.dart';
import 'quiz_yaml_parser.dart';

/// Imported packs are stored as YAML files inside the app's private support
/// directory. A pack's folder is the subdirectory holding its file, so the
/// catalog needs no separate index and cannot disagree with the disk.
///
/// ```text
/// quiz_packs/
///   chemistry-symbols.yaml   <- unfiled
///   Biology 101/
///     cell-structure.yaml
/// ```
class QuizCatalog extends ChangeNotifier {
  QuizCatalog({QuizYamlParser? parser, this.storageDirectory})
    : _parser = parser ?? QuizYamlParser();

  final QuizYamlParser _parser;

  /// Set in tests to store packs in a temporary directory instead of the
  /// platform's application support directory.
  final Directory? storageDirectory;
  final Map<String, QuizPack> _imported = {};
  final List<String> _folders = [];
  final List<QuizImportIssue> startupErrors = [];

  List<QuizPack> get packs => [...builtInQuizPacks, ..._imported.values];
  List<QuizPack> get importedPacks => _imported.values.toList();
  QuizPack? find(String id) => packs.where((pack) => pack.id == id).firstOrNull;
  bool isBuiltInId(String id) => builtInQuizPacks.any((pack) => pack.id == id);

  /// Folder names, including folders that hold no pack yet.
  List<String> get folders => [..._folders]..sort(QuizFolder.compare);

  List<QuizPack> packsInFolder(String? folder) =>
      _imported.values
          .where((pack) => QuizFolder.sameName(pack.folder, folder))
          .toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

  bool get hasUnfiledPacks =>
      _imported.values.any((pack) => pack.folder == null);

  Future<void> load() async {
    _imported.clear();
    _folders.clear();
    startupErrors.clear();
    final root = await _root();
    if (!await root.exists()) {
      notifyListeners();
      return;
    }
    final directories = <Directory>[];
    await _recover(root);
    for (final entity in await root.list().toList()) {
      if (entity is Directory) {
        directories.add(entity);
      } else if (entity is File) {
        await _loadPack(entity, null);
      }
    }
    for (final directory in directories) {
      final name = QuizFolder.normalize(_baseName(directory.path));
      if (name == null) {
        startupErrors.add(
          QuizImportIssue(
            _baseName(directory.path),
            'Ignored a folder with an unsupported name.',
          ),
        );
        continue;
      }
      if (_folders.any((existing) => QuizFolder.sameName(existing, name))) {
        startupErrors.add(
          QuizImportIssue(name, 'Ignored a second folder with the same name.'),
        );
        continue;
      }
      if (_folders.length >= QuizFolder.maxFolders) {
        startupErrors.add(
          QuizImportIssue(
            name,
            'Ignored: at most ${QuizFolder.maxFolders} folders are supported.',
          ),
        );
        continue;
      }
      _folders.add(name);
      await _recover(directory);
      for (final entity in await directory.list().toList()) {
        if (entity is File) await _loadPack(entity, name);
      }
    }
    notifyListeners();
  }

  Future<void> save(
    String source,
    QuizPack pack, {
    required String? folder,
  }) async {
    if (isBuiltInId(pack.id)) {
      throw StateError('Built-in quiz IDs cannot be overwritten.');
    }
    final destination = canonicalFolder(folder);
    final root = await _root();
    final directory = _folderDirectory(root, destination);
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
    final previous = _imported[pack.id];
    _imported[pack.id] = pack.asImported(folder: destination);
    if (previous != null &&
        !QuizFolder.sameName(previous.folder, destination)) {
      final stale = File(
        '${_folderDirectory(root, previous.folder).path}/${pack.id}.yaml',
      );
      if (await stale.exists()) await stale.delete();
    }
    _rememberFolder(destination);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final pack = _imported[id];
    final root = await _root();
    final file = File('${_folderDirectory(root, pack?.folder).path}/$id.yaml');
    if (await file.exists()) await file.delete();
    _imported.remove(id);
    notifyListeners();
  }

  Future<void> move(String id, String? folder) async {
    final pack = _imported[id];
    if (pack == null) return;
    final destination = canonicalFolder(folder);
    if (QuizFolder.sameName(pack.folder, destination)) return;
    final root = await _root();
    final source = File('${_folderDirectory(root, pack.folder).path}/$id.yaml');
    final directory = _folderDirectory(root, destination);
    await directory.create(recursive: true);
    if (await source.exists()) {
      await source.rename('${directory.path}/$id.yaml');
    }
    _imported[id] = pack.asImported(folder: destination);
    _rememberFolder(destination);
    notifyListeners();
  }

  Future<void> createFolder(String name) async {
    final folder = _requireFolderName(name);
    if (_folders.any((existing) => QuizFolder.sameName(existing, folder))) {
      return;
    }
    if (_folders.length >= QuizFolder.maxFolders) {
      throw StateError('At most ${QuizFolder.maxFolders} folders are allowed.');
    }
    final root = await _root();
    await _folderDirectory(root, folder).create(recursive: true);
    _folders.add(folder);
    notifyListeners();
  }

  Future<void> renameFolder(String from, String to) async {
    final target = _requireFolderName(to);
    final current = _folders.firstWhere(
      (existing) => QuizFolder.sameName(existing, from),
      orElse: () => throw StateError('That folder no longer exists.'),
    );
    if (current == target) return;
    final clash = _folders.any(
      (existing) =>
          QuizFolder.sameName(existing, target) &&
          !QuizFolder.sameName(existing, current),
    );
    if (clash) throw StateError('A folder with that name already exists.');
    final root = await _root();
    final source = _folderDirectory(root, current);
    final destination = _folderDirectory(root, target);
    if (await source.exists()) {
      if (QuizFolder.sameName(current, target)) {
        // A case-only rename can be a no-op on a case-insensitive filesystem,
        // so it goes through a temporary name the folder rules cannot produce.
        final temporary = Directory('${root.path}/$current.renaming');
        await source.rename(temporary.path);
        await temporary.rename(destination.path);
      } else {
        await source.rename(destination.path);
      }
    } else {
      await destination.create(recursive: true);
    }
    _folders[_folders.indexOf(current)] = target;
    for (final pack in packsInFolder(current)) {
      _imported[pack.id] = pack.asImported(folder: target);
    }
    notifyListeners();
  }

  /// Deletes a folder. Its packs move to Unfiled unless [deletePacks] is set.
  Future<void> deleteFolder(String name, {bool deletePacks = false}) async {
    final current = _folders
        .where((existing) => QuizFolder.sameName(existing, name))
        .firstOrNull;
    if (current == null) return;
    final root = await _root();
    final directory = _folderDirectory(root, current);
    for (final pack in packsInFolder(current)) {
      if (deletePacks) {
        _imported.remove(pack.id);
        continue;
      }
      final source = File('${directory.path}/${pack.id}.yaml');
      if (await source.exists()) {
        await source.rename('${root.path}/${pack.id}.yaml');
      }
      _imported[pack.id] = pack.asImported(folder: null);
    }
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _folders.remove(current);
    notifyListeners();
  }

  /// Returns the folder as it is already spelled in the catalog, so that two
  /// spellings of the same name cannot create two directories.
  String? canonicalFolder(String? name) {
    if (name == null) return null;
    final folder = _requireFolderName(name);
    return _folders.firstWhere(
      (existing) => QuizFolder.sameName(existing, folder),
      orElse: () => folder,
    );
  }

  Future<void> _loadPack(File file, String? folder) async {
    if (!file.path.endsWith('.yaml')) return;
    final name = _baseName(file.path);
    try {
      final result = _parser.parse(await file.readAsString());
      if (!result.isValid) {
        startupErrors.addAll(
          result.errors.map(
            (error) => QuizImportIssue('$name → ${error.path}', error.message),
          ),
        );
        return;
      }
      final pack = result.pack as QuizPack;
      if (isBuiltInId(pack.id)) {
        startupErrors.add(
          QuizImportIssue(name, 'Ignored: this ID belongs to a built-in quiz.'),
        );
        return;
      }
      if (_imported.containsKey(pack.id)) {
        startupErrors.add(
          QuizImportIssue(
            name,
            'Ignored: the ID “${pack.id}” is already used.',
          ),
        );
        return;
      }
      _imported[pack.id] = pack.asImported(folder: folder);
    } catch (_) {
      startupErrors.add(
        QuizImportIssue(name, 'Could not read this stored quiz.'),
      );
    }
  }

  /// Cleans up the artefacts an interrupted save can leave behind.
  Future<void> _recover(Directory directory) async {
    for (final entity in await directory.list().toList()) {
      if (entity is! File) continue;
      try {
        if (entity.path.endsWith('.tmp')) {
          await entity.delete();
        } else if (entity.path.endsWith('.backup')) {
          final target = File(
            entity.path.substring(0, entity.path.length - '.backup'.length),
          );
          if (await target.exists()) {
            await entity.delete();
          } else {
            await entity.rename(target.path);
          }
        }
      } catch (_) {
        // A leftover file that cannot be cleaned up must not block startup.
      }
    }
  }

  void _rememberFolder(String? folder) {
    if (folder == null) return;
    if (_folders.any((existing) => QuizFolder.sameName(existing, folder))) {
      return;
    }
    _folders.add(folder);
  }

  String _requireFolderName(String name) {
    final folder = QuizFolder.normalize(name);
    if (folder == null) {
      throw ArgumentError.value(name, 'folder', 'Unsupported folder name.');
    }
    return folder;
  }

  Directory _folderDirectory(Directory root, String? folder) => folder == null
      ? root
      : Directory('${root.path}/${_requireFolderName(folder)}');

  String _baseName(String path) => path.split(Platform.pathSeparator).last;

  Future<Directory> _root() async {
    final directory = storageDirectory;
    if (directory != null) return directory;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/quiz_packs');
  }
}
