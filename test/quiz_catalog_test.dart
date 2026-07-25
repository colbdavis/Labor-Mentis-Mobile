import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/import/quiz_catalog.dart';
import 'package:labor_mentis_mobile/import/quiz_yaml_parser.dart';
import 'package:labor_mentis_mobile/models/quiz_pack.dart';

String yaml(String id, {int version = 1, String? folder}) =>
    '''
schema_version: 1
id: $id
version: $version
title: Pack $id
category: Tests
${folder == null ? '' : 'folder: $folder'}
mode: true_false
questions:
  - prompt: A statement.
    correct: true
''';

void main() {
  final parser = QuizYamlParser();
  late Directory storage;
  late QuizCatalog catalog;

  QuizPack pack(String source) => parser.parse(source).pack as QuizPack;

  Future<void> reload() async {
    catalog = QuizCatalog(storageDirectory: storage);
    await catalog.load();
  }

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('quiz_catalog_test');
    catalog = QuizCatalog(storageDirectory: storage);
    await catalog.load();
  });

  tearDown(() async {
    if (await storage.exists()) await storage.delete(recursive: true);
  });

  group('QuizCatalog folders', () {
    test('stores a filed pack in its folder and reloads it', () async {
      final source = yaml('filed-pack');
      await catalog.save(source, pack(source), folder: 'Biology 101');

      expect(
        File('${storage.path}/Biology 101/filed-pack.yaml').existsSync(),
        isTrue,
      );

      await reload();
      expect(catalog.folders, ['Biology 101']);
      expect(catalog.packsInFolder('Biology 101').single.id, 'filed-pack');
      expect(catalog.packsInFolder(null), isEmpty);
    });

    test('reads version 1 flat files as unfiled packs', () async {
      File(
        '${storage.path}/legacy-pack.yaml',
      ).writeAsStringSync(yaml('legacy-pack'));

      await reload();
      expect(catalog.packsInFolder(null).single.id, 'legacy-pack');
      expect(catalog.folders, isEmpty);
      expect(catalog.startupErrors, isEmpty);
    });

    test('moves a pack between folders and back to unfiled', () async {
      final source = yaml('moving-pack');
      await catalog.save(source, pack(source), folder: 'Biology 101');

      await catalog.move('moving-pack', 'Exam Prep');
      expect(
        File('${storage.path}/Biology 101/moving-pack.yaml').existsSync(),
        isFalse,
      );
      expect(
        File('${storage.path}/Exam Prep/moving-pack.yaml').existsSync(),
        isTrue,
      );

      await catalog.move('moving-pack', null);
      expect(File('${storage.path}/moving-pack.yaml').existsSync(), isTrue);

      await reload();
      expect(catalog.packsInFolder(null).single.id, 'moving-pack');
    });

    test('reimporting into another folder leaves no stale copy', () async {
      final source = yaml('one-pack');
      await catalog.save(source, pack(source), folder: 'Biology 101');
      final updated = yaml('one-pack', version: 2);
      await catalog.save(updated, pack(updated), folder: 'Exam Prep');

      await reload();
      expect(catalog.importedPacks, hasLength(1));
      expect(catalog.importedPacks.single.version, 2);
      expect(catalog.packsInFolder('Exam Prep'), hasLength(1));
      expect(catalog.startupErrors, isEmpty);
    });

    test('renames a folder and keeps its packs', () async {
      final source = yaml('renamed-pack');
      await catalog.save(source, pack(source), folder: 'Biology');

      await catalog.renameFolder('Biology', 'Biology 102');

      expect(catalog.folders, ['Biology 102']);
      expect(catalog.packsInFolder('Biology 102'), hasLength(1));
      await reload();
      expect(catalog.packsInFolder('Biology 102').single.id, 'renamed-pack');
    });

    test('refuses to rename a folder onto another one', () async {
      await catalog.createFolder('Biology');
      await catalog.createFolder('Chemistry');

      expect(
        () => catalog.renameFolder('Biology', 'Chemistry'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleting a folder keeps its packs as unfiled by default', () async {
      final source = yaml('kept-pack');
      await catalog.save(source, pack(source), folder: 'Biology');

      await catalog.deleteFolder('Biology');

      expect(catalog.folders, isEmpty);
      await reload();
      expect(catalog.packsInFolder(null).single.id, 'kept-pack');
    });

    test('deleting a folder with its packs removes the files', () async {
      final source = yaml('doomed-pack');
      await catalog.save(source, pack(source), folder: 'Biology');

      await catalog.deleteFolder('Biology', deletePacks: true);

      expect(catalog.importedPacks, isEmpty);
      await reload();
      expect(catalog.importedPacks, isEmpty);
      expect(Directory('${storage.path}/Biology').existsSync(), isFalse);
    });

    test('reuses the existing spelling of a folder name', () async {
      await catalog.createFolder('Biology');
      final source = yaml('cased-pack');
      await catalog.save(source, pack(source), folder: 'BIOLOGY');

      expect(catalog.folders, ['Biology']);
      expect(catalog.packsInFolder('Biology'), hasLength(1));
    });

    test('rejects a folder name that is not usable as a directory', () async {
      final source = yaml('unsafe-pack');

      expect(
        () => catalog.save(source, pack(source), folder: '../escape'),
        throwsA(isA<ArgumentError>()),
      );
      expect(storage.listSync(), isEmpty);
    });

    test('keeps only the first file when an ID appears twice', () async {
      Directory('${storage.path}/Biology').createSync();
      File(
        '${storage.path}/twin-pack.yaml',
      ).writeAsStringSync(yaml('twin-pack'));
      File(
        '${storage.path}/Biology/twin-pack.yaml',
      ).writeAsStringSync(yaml('twin-pack', version: 9));

      await reload();

      expect(catalog.importedPacks, hasLength(1));
      expect(catalog.importedPacks.single.version, 1);
      expect(catalog.startupErrors, hasLength(1));
    });

    test('ignores directories whose names are not valid folders', () async {
      Directory('${storage.path}/.hidden').createSync();
      File(
        '${storage.path}/.hidden/hidden-pack.yaml',
      ).writeAsStringSync(yaml('hidden-pack'));

      await reload();

      expect(catalog.importedPacks, isEmpty);
      expect(catalog.folders, isEmpty);
      expect(catalog.startupErrors, hasLength(1));
    });

    test('cleans up leftovers from an interrupted save', () async {
      File('${storage.path}/orphan.yaml.tmp').writeAsStringSync('broken');
      File(
        '${storage.path}/restored-pack.yaml.backup',
      ).writeAsStringSync(yaml('restored-pack'));

      await reload();

      expect(File('${storage.path}/orphan.yaml.tmp').existsSync(), isFalse);
      expect(catalog.importedPacks.single.id, 'restored-pack');
    });
  });
}
