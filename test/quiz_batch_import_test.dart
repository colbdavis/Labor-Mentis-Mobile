import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/import/quiz_batch_import.dart';
import 'package:labor_mentis_mobile/models/game_mode.dart';
import 'package:labor_mentis_mobile/models/quiz_pack.dart';
import 'package:labor_mentis_mobile/models/quiz_question.dart';

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

PickedQuizFile file(String name, String source, {int? size}) =>
    PickedQuizFile(name, Uint8List.fromList(utf8.encode(source)), size: size);

QuizPack installedPack(String id, int version) => QuizPack(
  id: id,
  version: version,
  title: 'Installed',
  category: 'Tests',
  mode: GameMode.trueFalse,
  questions: const [QuizQuestion(prompt: 'A statement.', correctOption: 0)],
  isImported: true,
);

void main() {
  final importer = QuizBatchImporter();

  List<QuizImportCandidate> prepare(
    List<PickedQuizFile> files, {
    Map<String, QuizPack> installed = const {},
    Set<String> builtIn = const {},
  }) => importer.prepare(
    files,
    installed: (id) => installed[id],
    isBuiltIn: builtIn.contains,
  );

  group('QuizBatchImporter', () {
    test('reports one status per file', () {
      final candidates = prepare(
        [
          file('new.yaml', yaml('new-pack')),
          file('update.yml', yaml('known-pack', version: 3)),
          file('same.yaml', yaml('same-pack', version: 2)),
          file('older.yaml', yaml('newer-pack', version: 1)),
        ],
        installed: {
          'known-pack': installedPack('known-pack', 2),
          'same-pack': installedPack('same-pack', 2),
          'newer-pack': installedPack('newer-pack', 5),
        },
      );

      expect(candidates.map((entry) => entry.status), [
        QuizImportStatus.newPack,
        QuizImportStatus.update,
        QuizImportStatus.reinstall,
        QuizImportStatus.downgrade,
      ]);
      expect(candidates.map((entry) => entry.selected), [
        true,
        true,
        true,
        // A downgrade is listed but never imported without an explicit choice.
        false,
      ]);
    });

    test('keeps the folder suggested by the file', () {
      final candidates = prepare([
        file('a.yaml', yaml('filed-pack', folder: 'Biology 101')),
        file('b.yaml', yaml('unfiled-pack')),
      ]);

      expect(candidates.first.pack?.folder, 'Biology 101');
      expect(candidates.last.pack?.folder, isNull);
    });

    test('rejects bad files without affecting the rest of the batch', () {
      final candidates = prepare(
        [
          file('notes.txt', yaml('text-file')),
          file('huge.yaml', yaml('huge-pack'), size: 2 * 1024 * 1024),
          PickedQuizFile('unreadable.yaml', null),
          file('broken.yaml', 'questions: ['),
          file('builtin.yaml', yaml('built-in-pack')),
          file('good.yaml', yaml('good-pack')),
        ],
        builtIn: {'built-in-pack'},
      );

      expect(candidates.take(5).every((entry) => !entry.canImport), isTrue);
      expect(candidates.last.status, QuizImportStatus.newPack);
      expect(candidates[1].errors.single.message, contains('1 MB'));
      expect(candidates[4].errors.single.message, contains('built-in'));
    });

    test('rejects a pack ID repeated inside one selection', () {
      final candidates = prepare([
        file('first.yaml', yaml('same-id')),
        file('second.yaml', yaml('same-id', version: 2)),
      ]);

      expect(candidates.first.status, QuizImportStatus.newPack);
      expect(candidates.last.status, QuizImportStatus.failed);
      expect(candidates.last.errors.single.message, contains('same-id'));
    });

    test('rejects files beyond the per-selection limit', () {
      final files = [
        for (var i = 0; i <= QuizBatchImporter.maxFiles; i++)
          file('pack$i.yaml', yaml('pack-$i')),
      ];

      final candidates = prepare(files);

      expect(candidates, hasLength(files.length));
      expect(candidates.last.status, QuizImportStatus.failed);
      expect(
        candidates.last.errors.single.message,
        contains('${QuizBatchImporter.maxFiles} files'),
      );
      expect(
        candidates.take(QuizBatchImporter.maxFiles).every((e) => e.canImport),
        isTrue,
      );
    });

    test('rejects bytes that are not valid UTF-8', () {
      final candidates = prepare([
        PickedQuizFile('bad.yaml', Uint8List.fromList([0xc3, 0x28])),
      ]);

      expect(candidates.single.errors.single.message, contains('UTF-8'));
    });
  });
}
