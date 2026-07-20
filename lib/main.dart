import 'package:flutter/material.dart';

void main() => runApp(const LaborMentisApp());

const _indigo = Color(0xff4f46e5);
const _mint = Color(0xff0f766e);

class LaborMentisApp extends StatelessWidget {
  const LaborMentisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labor Mentis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff8fafc),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

enum GameMode { multipleChoice, trueFalse, text, matching }

extension GameModeDetails on GameMode {
  String get label => switch (this) {
    GameMode.multipleChoice => 'Multiple choice',
    GameMode.trueFalse => 'True or false',
    GameMode.text => 'Text answer',
    GameMode.matching => 'Match the pairs',
  };

  String get description => switch (this) {
    GameMode.multipleChoice => 'Choose the right answer from four options.',
    GameMode.trueFalse => 'Decide whether each statement is correct.',
    GameMode.text => 'Write a short answer.',
    GameMode.matching => 'Match each item with its corresponding pair.',
  };

  IconData get icon => switch (this) {
    GameMode.multipleChoice => Icons.quiz_outlined,
    GameMode.trueFalse => Icons.check_circle_outline,
    GameMode.text => Icons.short_text_rounded,
    GameMode.matching => Icons.account_tree_outlined,
  };

  Color get color => switch (this) {
    GameMode.multipleChoice => _indigo,
    GameMode.trueFalse => _mint,
    GameMode.text => const Color(0xffc2410c),
    GameMode.matching => const Color(0xffa21caf),
  };
}

class QuizPack {
  const QuizPack({
    required this.id,
    required this.title,
    required this.category,
    required this.mode,
    required this.questions,
  });

  final String id;
  final String title;
  final String category;
  final GameMode mode;
  final List<QuizQuestion> questions;
}

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

const _packs = [
  QuizPack(
    id: 'geography-capitals-1',
    title: 'World capitals',
    category: 'Geography',
    mode: GameMode.multipleChoice,
    questions: [
      QuizQuestion(
        prompt: 'What is the capital of Portugal?',
        options: ['Madrid', 'Lisbon', 'Porto', 'Barcelona'],
        correctOption: 1,
      ),
      QuizQuestion(
        prompt: 'Which city is the capital of Canada?',
        options: ['Toronto', 'Vancouver', 'Ottawa', 'Montréal'],
        correctOption: 2,
      ),
      QuizQuestion(
        prompt: 'What is the capital of Australia?',
        options: ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
        correctOption: 2,
      ),
    ],
  ),
  QuizPack(
    id: 'science-true-false-1',
    title: 'Essential science',
    category: 'Science',
    mode: GameMode.trueFalse,
    questions: [
      QuizQuestion(
        prompt: 'Water boils at 100 °C at sea level.',
        correctOption: 0,
      ),
      QuizQuestion(prompt: 'The Sun is a planet.', correctOption: 1),
      QuizQuestion(prompt: 'Plants absorb carbon dioxide.', correctOption: 0),
    ],
  ),
  QuizPack(
    id: 'italian-words-1',
    title: 'Italian words',
    category: 'Italian language',
    mode: GameMode.text,
    questions: [
      QuizQuestion(
        prompt: 'What is the plural of “uovo”?',
        acceptedAnswers: ['uova'],
      ),
      QuizQuestion(
        prompt: 'What do you call a word with the opposite meaning?',
        acceptedAnswers: ['contrario', 'antonimo'],
      ),
      QuizQuestion(
        prompt: 'Complete the Italian expression: “né carne né …”',
        acceptedAnswers: ['pesce'],
      ),
    ],
  ),
  QuizPack(
    id: 'literature-matching-1',
    title: 'Authors and works',
    category: 'Literature',
    mode: GameMode.matching,
    questions: [
      QuizQuestion(
        prompt: 'Match each author with their work.',
        pairs: [
          MatchPair('Dante', 'Divina Commedia'),
          MatchPair('Manzoni', 'I Promessi Sposi'),
          MatchPair('Leopardi', 'L’infinito'),
        ],
      ),
    ],
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final List<QuizResult> _results = [];

  void _openQuiz(QuizPack pack) async {
    final result = await Navigator.of(
      context,
    ).push<QuizResult>(MaterialPageRoute(builder: (_) => QuizPage(pack: pack)));
    if (result != null && mounted) {
      setState(() => _results.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tab == 0
            ? HomePage(onOpenQuiz: _openQuiz)
            : ScoresPage(results: _results),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Scores',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({required this.onOpenQuiz, super.key});

  final ValueChanged<QuizPack> onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          'Labor Mentis',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Learn by playing, even offline.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _WelcomeCard(),
        const SizedBox(height: 28),
        Text(
          'Included quizzes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Each pack uses a different game mode.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        ..._packs.map(
          (pack) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: QuizPackCard(pack: pack, onTap: () => onOpenQuiz(pack)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YAML import will be added in the next step.'),
            ),
          ),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Import a YAML quiz'),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _indigo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 36, color: Colors.white),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Small today, expandable tomorrow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Play the included quizzes and import your own files in the future.',
                  style: TextStyle(color: Color(0xffe0e7ff)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuizPackCard extends StatelessWidget {
  const QuizPackCard({required this.pack, required this.onTap, super.key});

  final QuizPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = pack.mode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: mode.color.withValues(alpha: .12),
                foregroundColor: mode.color,
                child: Icon(mode.icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.category.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mode.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pack.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mode.label} · ${pack.questions.length} ${pack.questions.length == 1 ? 'sfida' : 'domande'}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({required this.pack, super.key});

  final QuizPack pack;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _questionIndex = 0;
  int _score = 0;
  bool _answered = false;
  bool _wasCorrect = false;
  bool _finished = false;
  int? _selectedOption;
  final _textController = TextEditingController();

  QuizQuestion get _question => widget.pack.questions[_questionIndex];

  void _answerOption(int answer) {
    if (_answered) return;
    setState(() {
      _selectedOption = answer;
      _wasCorrect = answer == _question.correctOption;
      _answered = true;
      if (_wasCorrect) _score++;
    });
  }

  void _answerText() {
    if (_answered) return;
    final answer = _textController.text.trim().toLowerCase();
    setState(() {
      _wasCorrect = _question.acceptedAnswers.any(
        (accepted) => accepted.toLowerCase() == answer,
      );
      _answered = true;
      if (_wasCorrect) _score++;
    });
  }

  void _continue() {
    if (_questionIndex == widget.pack.questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _questionIndex++;
      _answered = false;
      _wasCorrect = false;
      _selectedOption = null;
      _textController.clear();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pack.mode == GameMode.matching) {
      return MatchingPage(pack: widget.pack);
    }
    if (_finished) {
      return QuizSummaryPage(
        result: QuizResult(
          pack: widget.pack,
          correct: _score,
          total: widget.pack.questions.length,
        ),
      );
    }
    final color = widget.pack.mode.color;
    final options = widget.pack.mode == GameMode.trueFalse
        ? const ['True', 'False']
        : _question.options;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pack.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(
                index: _questionIndex,
                total: widget.pack.questions.length,
                color: color,
              ),
              const SizedBox(height: 28),
              Text(
                widget.pack.mode.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _question.prompt,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.pack.mode == GameMode.text) ...[
                TextField(
                  controller: _textController,
                  enabled: !_answered,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _answerText(),
                  decoration: const InputDecoration(
                    labelText: 'La tua risposta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _answered ? null : _answerText,
                  child: const Text('Check answer'),
                ),
              ] else ...[
                ...List.generate(
                  options.length,
                  (index) => _AnswerButton(
                    label: options[index],
                    state: _answerStateFor(index),
                    onTap: () => _answerOption(index),
                  ),
                ),
              ],
              const Spacer(),
              if (_answered) ...[
                _Feedback(
                  correct: _wasCorrect,
                  correctAnswer: _correctAnswerText(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _continue,
                  icon: Icon(
                    _questionIndex == widget.pack.questions.length - 1
                        ? Icons.flag_outlined
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    _questionIndex == widget.pack.questions.length - 1
                        ? 'Vedi risultato'
                        : 'Continue',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _AnswerState _answerStateFor(int index) {
    if (!_answered) return _AnswerState.idle;
    if (index == _question.correctOption) return _AnswerState.correct;
    if (index == _selectedOption) return _AnswerState.wrong;
    return _AnswerState.disabled;
  }

  String _correctAnswerText() => widget.pack.mode == GameMode.text
      ? _question.acceptedAnswers.first
      : widget.pack.mode == GameMode.trueFalse
      ? const ['True', 'False'][_question.correctOption!]
      : _question.options[_question.correctOption!];
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.index,
    required this.total,
    required this.color,
  });

  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DOMANDA ${index + 1} DI $total',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text('${((index + 1) / total * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (index + 1) / total,
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

enum _AnswerState { idle, correct, wrong, disabled }

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _AnswerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (state) {
      _AnswerState.correct => (
        const Color(0xffdcfce7),
        const Color(0xff166534),
        const Color(0xff22c55e),
      ),
      _AnswerState.wrong => (
        const Color(0xfffee2e2),
        const Color(0xff991b1b),
        const Color(0xffef4444),
      ),
      _AnswerState.disabled => (
        Colors.transparent,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Theme.of(context).colorScheme.outlineVariant,
      ),
      _AnswerState.idle => (
        Colors.white,
        Theme.of(context).colorScheme.onSurface,
        Theme.of(context).colorScheme.outline,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: state == _AnswerState.idle ? onTap : null,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(18),
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          disabledForegroundColor: foreground,
        ),
        child: Text(label),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.correctAnswer});

  final bool correct;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xff166534) : const Color(0xff991b1b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(correct ? Icons.check_circle : Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correct
                  ? 'Corretto. Ottimo lavoro!'
                  : 'Correct answer: $correctAnswer',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizSummaryPage extends StatelessWidget {
  const QuizSummaryPage({required this.result, super.key});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final percentage = (result.correct / result.total * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  percentage >= 70
                      ? Icons.celebration_outlined
                      : Icons.emoji_objects_outlined,
                  size: 64,
                  color: result.pack.mode.color,
                ),
                const SizedBox(height: 20),
                Text(
                  '$percentage%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.correct} correct answers out of ${result.total}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(result),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Back to quizzes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchingPage extends StatefulWidget {
  const MatchingPage({required this.pack, super.key});

  final QuizPack pack;

  @override
  State<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  String? _selectedLeft;
  final Map<String, String> _matches = {};
  bool _finished = false;
  bool _wasCorrect = false;

  QuizQuestion get _question => widget.pack.questions.first;

  void _selectLeft(String value) {
    if (!_finished && !_matches.containsKey(value)) {
      setState(() => _selectedLeft = value);
    }
  }

  void _selectRight(String right) {
    if (_selectedLeft == null || _finished) return;
    setState(() {
      _matches[_selectedLeft!] = right;
      _selectedLeft = null;
    });
  }

  void _finish() {
    setState(() {
      _wasCorrect = _question.pairs.every(
        (pair) => _matches[pair.left] == pair.right,
      );
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return QuizSummaryPage(
        result: QuizResult(
          pack: widget.pack,
          correct: _wasCorrect ? 1 : 0,
          total: 1,
        ),
      );
    }
    final availableRight = _question.pairs
        .map((pair) => pair.right)
        .where((right) => !_matches.values.contains(right))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.pack.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProgressHeader(
                index: 0,
                total: 1,
                color: Color(0xffa21caf),
              ),
              const SizedBox(height: 28),
              Text(
                'COLLEGA LE COPPIE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xffa21caf),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _question.prompt,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              ..._question.pairs.map((pair) {
                final selected = _selectedLeft == pair.left;
                final match = _matches[pair.left];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectLeft(pair.left),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0xfffae8ff)
                                : null,
                          ),
                          child: Text(pair.left),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 18),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: null,
                          child: Text(match ?? 'Choose below'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_selectedLeft != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ora scegli il collegamento:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableRight
                      .map(
                        (right) => ActionChip(
                          label: Text(right),
                          onPressed: () => _selectRight(right),
                        ),
                      )
                      .toList(),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _matches.length == _question.pairs.length
                    ? _finish
                    : null,
                child: const Text('Check matches'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScoresPage extends StatelessWidget {
  const ScoresPage({required this.results, super.key});

  final List<QuizResult> results;

  @override
  Widget build(BuildContext context) {
    final total = results.fold(0, (sum, item) => sum + item.total);
    final correct = results.fold(0, (sum, item) => sum + item.correct);
    final percentage = total == 0 ? 0 : (correct / total * 100).round();
    final byCategory = <String, List<QuizResult>>{};
    for (final result in results) {
      byCategory.putIfAbsent(result.pack.category, () => []).add(result);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          'I tuoi punteggi',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('Risultati di questa sessione.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _mint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MEDIA COMPLESSIVA',
                style: TextStyle(
                  color: Color(0xffccfbf1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                total == 0
                    ? 'Completa un quiz per iniziare.'
                    : '$correct correct answers out of $total',
                style: const TextStyle(color: Color(0xffccfbf1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'By category',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No quizzes completed. Go to “Play” to get started.'),
            ),
          )
        else
          ...byCategory.entries.map((entry) {
            final categoryResults = entry.value;
            final categoryTotal = categoryResults.fold(
              0,
              (sum, result) => sum + result.total,
            );
            final categoryCorrect = categoryResults.fold(
              0,
              (sum, result) => sum + result.correct,
            );
            final categoryPercentage = (categoryCorrect / categoryTotal * 100)
                .round();
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _indigo.withValues(alpha: .12),
                  foregroundColor: _indigo,
                  child: const Icon(Icons.folder_outlined),
                ),
                title: Text(entry.key),
                subtitle: Text(
                  '${categoryResults.length} ${categoryResults.length == 1 ? 'quiz completed' : 'quizzes completed'}',
                ),
                trailing: Text(
                  '$categoryPercentage%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
