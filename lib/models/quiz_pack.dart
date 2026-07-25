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
    this.folder,
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

  /// Folder holding this pack. On a parsed pack it is only the folder the file
  /// suggests; on a catalog pack it is where the file is actually stored.
  /// Null means the pack is unfiled.
  final String? folder;

  /// [folder] is required so that filing a pack under no folder is always an
  /// explicit choice rather than an omitted argument.
  QuizPack asImported({required String? folder}) => QuizPack(
    id: id,
    version: version,
    title: title,
    category: category,
    description: description,
    mode: mode,
    questions: questions,
    folder: folder,
    isImported: true,
  );
}
