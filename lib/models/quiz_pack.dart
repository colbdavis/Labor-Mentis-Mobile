import 'game_mode.dart';
import 'quiz_question.dart';

class QuizPack {
  const QuizPack({
    required this.id,
    required this.version,
    required this.title,
    required this.category,
    required this.mode,
    required this.questions,
    this.description,
    this.isImported = false,
  });

  final String id;
  final int version;
  final String title;
  final String category;
  final String? description;
  final GameMode mode;
  final List<QuizQuestion> questions;
  final bool isImported;

  QuizPack asImported() => QuizPack(
    id: id,
    version: version,
    title: title,
    category: category,
    description: description,
    mode: mode,
    questions: questions,
    isImported: true,
  );
}
