import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/game_mode.dart';
import '../models/quiz_pack.dart';
import '../models/quiz_question.dart';
import 'quiz_import_error.dart';

class QuizYamlParser {
  static const maxSourceBytes = 1024 * 1024;
  static const _commonFields = {
    'schema_version',
    'id',
    'version',
    'title',
    'category',
    'description',
    'mode',
    'questions',
  };

  QuizParseResult parse(String source) {
    final errors = <QuizImportIssue>[];
    final warnings = <QuizImportIssue>[];
    if (utf8.encode(source).length > maxSourceBytes) {
      return QuizParseResult(
        errors: [const QuizImportIssue(r'$', 'File exceeds the 1 MB limit.')],
      );
    }
    dynamic document;
    try {
      document = loadYaml(source);
    } on YamlException catch (error) {
      return QuizParseResult(
        errors: [QuizImportIssue(r'$', 'Invalid YAML: ${error.message}')],
      );
    }
    if (document is! YamlMap) {
      return QuizParseResult(
        errors: [const QuizImportIssue(r'$', 'The YAML root must be a map.')],
      );
    }
    final root = _stringMap(document, r'$', errors);
    if (root == null) return QuizParseResult(errors: errors);
    for (final key in root.keys.where((key) => !_commonFields.contains(key))) {
      warnings.add(QuizImportIssue(key, 'Unknown field.', isWarning: true));
    }

    final schema = root['schema_version'];
    if (schema is! int || schema != 1) {
      errors.add(
        const QuizImportIssue('schema_version', 'Must be the integer 1.'),
      );
    }
    final id = _text(root['id'], 'id', errors, max: 80);
    if (id != null && !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id)) {
      errors.add(
        const QuizImportIssue(
          'id',
          'Use only lowercase letters, numbers, and hyphens.',
        ),
      );
    }
    final version = root['version'];
    if (version is! int || version < 1) {
      errors.add(
        const QuizImportIssue('version', 'Must be a positive integer.'),
      );
    }
    final title = _text(root['title'], 'title', errors, max: 200);
    final category = _text(root['category'], 'category', errors, max: 200);
    final description = root['description'] == null
        ? null
        : _text(root['description'], 'description', errors, max: 500);
    final mode = _mode(root['mode'], errors);
    final rawQuestions = root['questions'];
    if (rawQuestions is! YamlList && rawQuestions is! List) {
      errors.add(
        const QuizImportIssue(
          'questions',
          'Must be a list containing 1 to 500 questions.',
        ),
      );
    } else if (rawQuestions.isEmpty || rawQuestions.length > 500) {
      errors.add(
        const QuizImportIssue(
          'questions',
          'Must contain between 1 and 500 questions.',
        ),
      );
    }

    final questions = <QuizQuestion>[];
    if (mode != null && rawQuestions is List && rawQuestions.length <= 500) {
      for (var index = 0; index < rawQuestions.length; index++) {
        final question = _question(
          rawQuestions[index],
          index,
          mode,
          errors,
          warnings,
        );
        if (question != null) questions.add(question);
      }
    }
    if (errors.isNotEmpty ||
        id == null ||
        version is! int ||
        title == null ||
        category == null ||
        mode == null) {
      return QuizParseResult(errors: errors, warnings: warnings);
    }
    return QuizParseResult(
      pack: QuizPack(
        id: id,
        version: version,
        title: title,
        category: category,
        description: description,
        mode: mode,
        questions: questions,
      ),
      warnings: warnings,
    );
  }

  QuizQuestion? _question(
    dynamic value,
    int index,
    GameMode mode,
    List<QuizImportIssue> errors,
    List<QuizImportIssue> warnings,
  ) {
    final path = 'questions[$index]';
    if (value is! Map) {
      errors.add(QuizImportIssue(path, 'Must be a map.'));
      return null;
    }
    final map = _stringMap(value, path, errors);
    if (map == null) return null;
    final allowed = switch (mode) {
      GameMode.multipleChoice => {'prompt', 'options', 'correct'},
      GameMode.trueFalse => {'prompt', 'correct'},
      GameMode.text => {'prompt', 'accepted_answers'},
      GameMode.matching => {'prompt', 'pairs'},
    };
    for (final key in map.keys.where((key) => !allowed.contains(key))) {
      warnings.add(
        QuizImportIssue(
          '$path.$key',
          'Field is not used by ${mode.yamlValue}.',
          isWarning: true,
        ),
      );
    }
    final prompt = _text(map['prompt'], '$path.prompt', errors, max: 500);
    if (prompt == null) return null;
    switch (mode) {
      case GameMode.multipleChoice:
        final options = _textList(
          map['options'],
          '$path.options',
          errors,
          min: 2,
          max: 6,
        );
        final correct = _text(
          map['correct'],
          '$path.correct',
          errors,
          max: 200,
        );
        if (options == null || correct == null) return null;
        final matches = [
          for (var i = 0; i < options.length; i++)
            if (options[i] == correct) i,
        ];
        if (matches.length != 1) {
          errors.add(
            QuizImportIssue('$path.correct', 'Must exactly match one option.'),
          );
          return null;
        }
        return QuizQuestion(
          prompt: prompt,
          options: options,
          correctOption: matches.single,
        );
      case GameMode.trueFalse:
        if (map['correct'] is! bool) {
          errors.add(
            QuizImportIssue(
              '$path.correct',
              'Must be a YAML boolean (true or false).',
            ),
          );
          return null;
        }
        return QuizQuestion(
          prompt: prompt,
          correctOption: map['correct'] == true ? 0 : 1,
        );
      case GameMode.text:
        final answers = _textList(
          map['accepted_answers'],
          '$path.accepted_answers',
          errors,
          min: 1,
          max: 20,
        );
        return answers == null
            ? null
            : QuizQuestion(prompt: prompt, acceptedAnswers: answers);
      case GameMode.matching:
        final rawPairs = map['pairs'];
        if (rawPairs is! List || rawPairs.length < 2 || rawPairs.length > 20) {
          errors.add(
            QuizImportIssue(
              '$path.pairs',
              'Must contain between 2 and 20 pairs.',
            ),
          );
          return null;
        }
        final pairs = <MatchPair>[];
        for (var i = 0; i < rawPairs.length; i++) {
          final pairPath = '$path.pairs[$i]';
          if (rawPairs[i] is! Map) {
            errors.add(QuizImportIssue(pairPath, 'Must be a map.'));
            continue;
          }
          final pair = _stringMap(rawPairs[i], pairPath, errors);
          if (pair == null) continue;
          final left = _text(pair['left'], '$pairPath.left', errors, max: 200);
          final right = _text(
            pair['right'],
            '$pairPath.right',
            errors,
            max: 200,
          );
          if (left != null && right != null) pairs.add(MatchPair(left, right));
        }
        if (_duplicates(pairs.map((pair) => pair.left)) ||
            _duplicates(pairs.map((pair) => pair.right))) {
          errors.add(
            QuizImportIssue(
              '$path.pairs',
              'Values on each side must be unique.',
            ),
          );
          return null;
        }
        return pairs.length == rawPairs.length
            ? QuizQuestion(prompt: prompt, pairs: pairs)
            : null;
    }
  }

  Map<String, dynamic>? _stringMap(
    dynamic value,
    String path,
    List<QuizImportIssue> errors,
  ) {
    final result = <String, dynamic>{};
    for (final entry in (value as Map).entries) {
      if (entry.key is! String) {
        errors.add(QuizImportIssue(path, 'Field names must be strings.'));
        return null;
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String? _text(
    dynamic value,
    String path,
    List<QuizImportIssue> errors, {
    required int max,
  }) {
    if (value is! String || value.trim().isEmpty) {
      errors.add(QuizImportIssue(path, 'Must be a non-empty string.'));
      return null;
    }
    if (value.length > max) {
      errors.add(QuizImportIssue(path, 'Must not exceed $max characters.'));
      return null;
    }
    return value.trim();
  }

  List<String>? _textList(
    dynamic value,
    String path,
    List<QuizImportIssue> errors, {
    required int min,
    required int max,
  }) {
    if (value is! List || value.length < min || value.length > max) {
      errors.add(
        QuizImportIssue(path, 'Must contain between $min and $max items.'),
      );
      return null;
    }
    final result = <String>[];
    for (var i = 0; i < value.length; i++) {
      final item = _text(value[i], '$path[$i]', errors, max: 200);
      if (item != null) result.add(item);
    }
    if (_duplicates(result)) {
      errors.add(QuizImportIssue(path, 'Items must be unique.'));
    }
    return result.length == value.length && !_duplicates(result)
        ? result
        : null;
  }

  bool _duplicates(Iterable<String> values) {
    final list = values.toList();
    return list.toSet().length != list.length;
  }

  GameMode? _mode(dynamic value, List<QuizImportIssue> errors) {
    final mode = switch (value) {
      'multiple_choice' => GameMode.multipleChoice,
      'true_false' => GameMode.trueFalse,
      'text' => GameMode.text,
      'matching' => GameMode.matching,
      _ => null,
    };
    if (mode == null) {
      errors.add(
        const QuizImportIssue(
          'mode',
          'Must be multiple_choice, true_false, text, or matching.',
        ),
      );
    }
    return mode;
  }
}
