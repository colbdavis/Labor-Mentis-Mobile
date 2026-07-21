class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    this.options = const [],
    this.correctOption,
    this.acceptedAnswers = const [],
    this.pairs = const [],
  });

  final String prompt;
  final List<String> options;
  final int? correctOption;
  final List<String> acceptedAnswers;
  final List<MatchPair> pairs;
}

class MatchPair {
  const MatchPair(this.left, this.right);

  final String left;
  final String right;
}
