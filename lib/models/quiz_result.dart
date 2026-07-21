import 'quiz_pack.dart';

class QuizResult {
  const QuizResult({
    required this.pack,
    required this.correct,
    required this.total,
  });

  final QuizPack pack;
  final int correct;
  final int total;
}
