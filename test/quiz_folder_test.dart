import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/import/quiz_folder.dart';

void main() {
  group('QuizFolder', () {
    test('accepts plain names and trims them', () {
      expect(QuizFolder.normalize('Biology 101'), 'Biology 101');
      expect(QuizFolder.normalize('  Exam_Prep-2  '), 'Exam_Prep-2');
      expect(QuizFolder.normalize('a' * QuizFolder.maxNameLength), isNotNull);
    });

    test('rejects names that could escape the storage directory', () {
      final rejected = [
        '..',
        '.',
        '../secrets',
        'a/b',
        r'a\b',
        '/absolute',
        '.hidden',
        'two${String.fromCharCode(10)}lines',
        'nul${String.fromCharCode(0)}byte',
      ];
      for (final name in rejected) {
        expect(QuizFolder.normalize(name), isNull, reason: 'accepted $name');
      }
    });

    test('rejects empty, oversized, and non-name values', () {
      expect(QuizFolder.normalize(null), isNull);
      expect(QuizFolder.normalize(''), isNull);
      expect(QuizFolder.normalize('   '), isNull);
      expect(QuizFolder.normalize('-leading-hyphen'), isNull);
      expect(QuizFolder.normalize('émoji ✨'), isNull);
      expect(
        QuizFolder.normalize('a' * (QuizFolder.maxNameLength + 1)),
        isNull,
      );
    });

    test('compares names case-insensitively', () {
      expect(QuizFolder.sameName('Biology', 'biology'), isTrue);
      expect(QuizFolder.sameName(null, null), isTrue);
      expect(QuizFolder.sameName('Biology', null), isFalse);
      expect(QuizFolder.sameName('Biology', 'Chemistry'), isFalse);
    });
  });
}
