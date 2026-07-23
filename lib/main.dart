import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'import/quiz_catalog.dart';
import 'import/quiz_import_error.dart';
import 'import/quiz_yaml_parser.dart';
import 'models/game_mode.dart';
import 'models/quiz_pack.dart';
import 'models/quiz_question.dart';
import 'models/quiz_result.dart';

void main() => runApp(const LaborMentisApp());

Color _modeColor(BuildContext context, GameMode mode) {
  final colors = Theme.of(context).colorScheme;
  return switch (mode) {
    GameMode.multipleChoice => colors.primary,
    GameMode.trueFalse => colors.tertiary,
    GameMode.text =>
      colors.brightness == Brightness.dark
          ? const Color(0xffffb86c)
          : const Color(0xff9a4f00),
    GameMode.matching => colors.secondary,
  };
}

class LaborMentisApp extends StatelessWidget {
  const LaborMentisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labor Mentis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final List<QuizResult> _results = [];
  final QuizCatalog _catalog = QuizCatalog();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_catalogChanged);
    _catalog.load().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog.removeListener(_catalogChanged);
    _catalog.dispose();
    super.dispose();
  }

  void _openQuiz(QuizPack pack) async {
    final result = await Navigator.of(
      context,
    ).push<QuizResult>(MaterialPageRoute(builder: (_) => QuizPage(pack: pack)));
    if (result != null && mounted) {
      setState(() => _results.add(result));
    }
  }

  Future<void> _importQuiz() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'yml'],
      allowMultiple: false,
      withData: true,
    );
    if (selection == null || !mounted) return;
    final file = selection.files.single;
    if (!RegExp(r'\.ya?ml$', caseSensitive: false).hasMatch(file.name)) {
      await _showIssues([
        const QuizImportIssue('file', 'Choose a .yaml or .yml file.'),
      ]);
      return;
    }
    if (file.size > QuizYamlParser.maxSourceBytes) {
      await _showIssues([
        const QuizImportIssue('file', 'File exceeds the 1 MB limit.'),
      ]);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      await _showIssues([
        const QuizImportIssue('file', 'The selected file could not be read.'),
      ]);
      return;
    }
    String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      await _showIssues([
        const QuizImportIssue(
          'file',
          'The file must contain valid UTF-8 text.',
        ),
      ]);
      return;
    }
    final result = QuizYamlParser().parse(source);
    if (!result.isValid) {
      await _showIssues([...result.errors, ...result.warnings]);
      return;
    }
    final pack = result.pack as QuizPack;
    if (_catalog.isBuiltInId(pack.id)) {
      await _showIssues([
        const QuizImportIssue(
          'id',
          'This ID belongs to a built-in quiz and cannot be overwritten.',
        ),
      ]);
      return;
    }
    final existing = _catalog.find(pack.id);
    final accepted = await _confirmImport(pack, existing, result.warnings);
    if (accepted != true || !mounted) return;
    try {
      await _catalog.save(source, pack);
    } catch (error) {
      if (mounted) {
        await _showIssues([
          QuizImportIssue('file', 'Could not save the quiz: $error'),
        ]);
      }
    }
  }

  Future<bool?> _confirmImport(
    QuizPack pack,
    QuizPack? existing,
    List<QuizImportIssue> warnings,
  ) {
    final versionMessage = existing == null
        ? null
        : pack.version > existing.version
        ? 'This updates version ${existing.version} to ${pack.version}.'
        : pack.version < existing.version
        ? 'Warning: this downgrades version ${existing.version} to ${pack.version}.'
        : 'Version ${pack.version} is already installed. This will replace it.';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Import quiz?' : 'Replace quiz?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pack.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                'Category: ${pack.category}\nMode: ${pack.mode.label}\nQuestions: ${pack.questions.length}\nID: ${pack.id}\nVersion: ${pack.version}',
              ),
              if (versionMessage != null) ...[
                const SizedBox(height: 12),
                Text(versionMessage),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${warnings.length} warning(s) found.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(existing == null ? 'Import' : 'Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _showIssues(List<QuizImportIssue> issues) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quiz could not be imported'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(
            issues.map((issue) => issue.toString()).join('\n\n'),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _manageQuiz(QuizPack pack) async {
    if (!pack.isImported) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pack.title),
        content: Text(
          'Imported quiz\nID: ${pack.id}\nVersion: ${pack.version}\n${pack.questions.length} questions',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove imported quiz?'),
          content: Text('Remove “${pack.title}” from this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true) await _catalog.remove(pack.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tab == 0
            ? HomePage(
                packs: _catalog.packs,
                loading: _loading,
                onOpenQuiz: _openQuiz,
                onImport: _importQuiz,
                onManageQuiz: _manageQuiz,
              )
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
  const HomePage({
    required this.packs,
    required this.loading,
    required this.onOpenQuiz,
    required this.onImport,
    required this.onManageQuiz,
    super.key,
  });

  final List<QuizPack> packs;
  final bool loading;
  final ValueChanged<QuizPack> onOpenQuiz;
  final VoidCallback onImport;
  final ValueChanged<QuizPack> onManageQuiz;

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
        if (loading) const LinearProgressIndicator(),
        ...packs.map(
          (pack) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: QuizPackCard(
              pack: pack,
              onTap: () => onOpenQuiz(pack),
              onManage: pack.isImported ? () => onManageQuiz(pack) : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onImport,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 36, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Small today, expandable tomorrow',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Play the included quizzes and import your own YAML files.',
                  style: TextStyle(
                    color: colors.onPrimaryContainer.withValues(alpha: .8),
                  ),
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
  const QuizPackCard({
    required this.pack,
    required this.onTap,
    this.onManage,
    super.key,
  });

  final QuizPack pack;
  final VoidCallback onTap;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final mode = pack.mode;
    final modeColor = _modeColor(context, mode);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: modeColor.withValues(alpha: .12),
                foregroundColor: modeColor,
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
                        color: modeColor,
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
              if (pack.isImported)
                IconButton(
                  tooltip: 'Manage imported quiz',
                  onPressed: onManage,
                  icon: const Icon(Icons.more_vert),
                )
              else
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
    final color = _modeColor(context, widget.pack.mode);
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
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, border) = switch (state) {
      _AnswerState.correct => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        colors.tertiary,
      ),
      _AnswerState.wrong => (
        colors.errorContainer,
        colors.onErrorContainer,
        colors.error,
      ),
      _AnswerState.disabled => (
        Colors.transparent,
        colors.onSurfaceVariant,
        colors.outlineVariant,
      ),
      _AnswerState.idle => (colors.surface, colors.onSurface, colors.outline),
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
    final colors = Theme.of(context).colorScheme;
    final color = correct ? colors.tertiary : colors.error;
    final foreground = correct
        ? colors.onTertiaryContainer
        : colors.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct ? colors.tertiaryContainer : colors.errorContainer,
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
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
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
                  color: _modeColor(context, result.pack.mode),
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
    final matchingColor = _modeColor(context, GameMode.matching);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pack.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressHeader(index: 0, total: 1, color: matchingColor),
                    const SizedBox(height: 28),
                    Text(
                      'COLLEGA LE COPPIE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: matchingColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _question.prompt,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                                      ? colors.secondaryContainer
                                      : null,
                                ),
                                child: Text(pair.left),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
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
    final colors = Theme.of(context).colorScheme;
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
          'Your scores',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('Results from this session.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OVERALL SCORE',
                style: TextStyle(
                  color: colors.onTertiaryContainer.withValues(alpha: .8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: colors.onTertiaryContainer,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                total == 0
                    ? 'Complete a quiz to get started.'
                    : '$correct correct answers out of $total',
                style: TextStyle(
                  color: colors.onTertiaryContainer.withValues(alpha: .8),
                ),
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
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
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
