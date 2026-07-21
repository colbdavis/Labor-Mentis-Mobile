import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/import/quiz_yaml_parser.dart';
import 'package:labor_mentis_mobile/models/game_mode.dart';

void main() {
  final parser = QuizYamlParser();

  group('QuizYamlParser', () {
    for (final entry in <GameMode, String>{
      GameMode.multipleChoice: '''
mode: multiple_choice
questions:
  - prompt: Capital of Portugal?
    options: [Madrid, Lisbon]
    correct: Lisbon
''',
      GameMode.trueFalse: '''
mode: true_false
questions:
  - prompt: Water is wet.
    correct: true
''',
      GameMode.text: '''
mode: text
questions:
  - prompt: Symbol for gold?
    accepted_answers: [Au]
''',
      GameMode.matching: '''
mode: matching
questions:
  - prompt: Match them.
    pairs:
      - {left: Dante, right: Divine Comedy}
      - {left: Manzoni, right: The Betrothed}
''',
    }.entries) {
      test('parses ${entry.key.yamlValue}', () {
        final result = parser.parse('''
schema_version: 1
id: valid-pack
version: 1
title: Valid pack
category: Tests
${entry.value}
''');
        expect(result.errors, isEmpty);
        expect(result.pack?.mode, entry.key);
      });
    }

    test('reports malformed YAML with a field path', () {
      final result = parser.parse('questions: [');
      expect(result.errors.single.path, r'$');
      expect(result.errors.single.message, contains('Invalid YAML'));
    });

    test('rejects strings used as booleans', () {
      final result = parser.parse('''
schema_version: 1
id: boolean-pack
version: 1
title: Boolean pack
category: Tests
mode: true_false
questions:
  - prompt: A statement
    correct: "true"
''');
      expect(
        result.errors.any((error) => error.path == 'questions[0].correct'),
        isTrue,
      );
    });

    test('rejects duplicate matching values', () {
      final result = parser.parse('''
schema_version: 1
id: matching-pack
version: 1
title: Matching pack
category: Tests
mode: matching
questions:
  - prompt: Match.
    pairs:
      - {left: Same, right: One}
      - {left: Same, right: Two}
''');
      expect(
        result.errors.any((error) => error.path == 'questions[0].pairs'),
        isTrue,
      );
    });

    test('reports unknown fields as warnings', () {
      final result = parser.parse('''
schema_version: 1
id: warning-pack
version: 1
title: Warning pack
category: Tests
mode: text
future_field: value
questions:
  - prompt: Answer.
    accepted_answers: [yes]
''');
      expect(result.isValid, isTrue);
      expect(result.warnings.single.path, 'future_field');
    });

    test('validates required pack fields', () {
      final result = parser.parse('schema_version: 2\nmode: unknown\n');
      final paths = result.errors.map((error) => error.path);
      expect(
        paths,
        containsAll([
          'schema_version',
          'id',
          'version',
          'title',
          'category',
          'mode',
          'questions',
        ]),
      );
    });

    test('rejects an answer longer than 200 characters', () {
      final longAnswer = 'a' * 201;
      final result = parser.parse('''
schema_version: 1
id: long-answer
version: 1
title: Long answer
category: Tests
mode: text
questions:
  - prompt: Answer.
    accepted_answers: [$longAnswer]
''');
      expect(
        result.errors.any(
          (error) => error.path == 'questions[0].accepted_answers[0]',
        ),
        isTrue,
      );
    });

    test('rejects more than 500 questions before parsing them', () {
      final questions = List.filled(501, '  - prompt: Too many').join('\n');
      final result = parser.parse('''
schema_version: 1
id: too-many
version: 1
title: Too many
category: Tests
mode: true_false
questions:
$questions
''');
      expect(result.errors.any((error) => error.path == 'questions'), isTrue);
    });
  });
}
