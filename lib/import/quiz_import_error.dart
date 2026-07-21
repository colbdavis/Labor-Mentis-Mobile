import '../models/quiz_pack.dart';

class QuizImportIssue {
  const QuizImportIssue(this.path, this.message, {this.isWarning = false});

  final String path;
  final String message;
  final bool isWarning;

  @override
  String toString() => '${isWarning ? 'Warning' : 'Error'} at $path: $message';
}

class QuizParseResult {
  const QuizParseResult({
    this.pack,
    this.errors = const [],
    this.warnings = const [],
  });

  final QuizPack? pack;
  final List<QuizImportIssue> errors;
  final List<QuizImportIssue> warnings;
  bool get isValid => pack != null && errors.isEmpty;
}
