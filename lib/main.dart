import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'import/quiz_batch_import.dart';
import 'import/quiz_catalog.dart';
import 'import/quiz_folder.dart';
import 'import/quiz_import_error.dart';
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
      if (!mounted) return;
      setState(() => _loading = false);
      final issues = [..._catalog.startupErrors];
      if (issues.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${issues.length} stored file(s) could not be loaded.'),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () => _showIssues(issues, title: 'Stored quizzes'),
          ),
        ),
      );
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
      allowMultiple: true,
      withData: true,
    );
    if (selection == null || !mounted) return;
    final candidates = QuizBatchImporter().prepare(
      [
        for (final file in selection.files)
          PickedQuizFile(file.name, file.bytes, size: file.size),
      ],
      installed: _catalog.find,
      isBuiltIn: _catalog.isBuiltInId,
    );
    if (candidates.isEmpty) return;
    final destination = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ImportReviewSheet(
        candidates: candidates,
        folders: _catalog.folders,
        onCreateFolder: _createFolder,
      ),
    );
    if (destination == null || !mounted) return;
    await _saveCandidates(candidates, destination);
  }

  Future<void> _saveCandidates(
    List<QuizImportCandidate> candidates,
    String destination,
  ) async {
    final failures = <QuizImportIssue>[];
    var imported = 0;
    for (final candidate in candidates) {
      final pack = candidate.pack;
      final source = candidate.source;
      if (!candidate.selected || pack == null || source == null) continue;
      final folder = switch (destination) {
        ImportReviewSheet.fromFile => pack.folder,
        ImportReviewSheet.unfiled => null,
        _ => destination,
      };
      try {
        await _catalog.save(source, pack, folder: folder);
        imported++;
      } catch (error) {
        failures.add(
          QuizImportIssue(candidate.fileName, 'Could not save: $error'),
        );
      }
    }
    if (!mounted) return;
    final rejected = candidates.where((entry) => !entry.canImport).toList();
    final skipped = candidates
        .where((entry) => entry.canImport && !entry.selected)
        .length;
    if (rejected.isEmpty && failures.isEmpty) {
      _notify('${_quizCount(imported)} imported.');
      return;
    }
    await _showIssues([
      QuizImportIssue('summary', '${_quizCount(imported)} imported.'),
      if (skipped > 0)
        QuizImportIssue('summary', '$skipped file(s) were not selected.'),
      for (final candidate in rejected)
        QuizImportIssue(
          candidate.fileName,
          candidate.errors
              .map((issue) => '${issue.path}: ${issue.message}')
              .join('\n'),
        ),
      ...failures,
    ], title: 'Import finished');
  }

  Future<void> _showIssues(
    List<QuizImportIssue> issues, {
    String title = 'Quiz could not be imported',
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(pack.title),
              subtitle: Text(
                'Imported quiz · ID: ${pack.id} · Version ${pack.version}\n'
                '${pack.folder ?? 'Unfiled'} · ${pack.questions.length} questions',
              ),
              isThreeLine: true,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to folder'),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from this device'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'move') {
      await _moveQuiz(pack);
    } else {
      await _removeQuiz(pack);
    }
  }

  Future<void> _moveQuiz(QuizPack pack) async {
    final choice = await _chooseFolder(current: pack.folder);
    if (choice == null || !mounted) return;
    await _catalog.move(pack.id, choice.folder);
  }

  Future<void> _removeQuiz(QuizPack pack) async {
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
    if (confirmed == true && mounted) await _catalog.remove(pack.id);
  }

  Future<_FolderChoice?> _chooseFolder({String? current}) async {
    final choice = await showDialog<_FolderChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Unfiled'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, const _FolderChoice(null)),
          ),
          for (final folder in _catalog.folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder),
              trailing: QuizFolder.sameName(folder, current)
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, _FolderChoice(folder)),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('New folder…'),
            onTap: () => Navigator.pop(context, const _FolderChoice.create()),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    if (!choice.isCreate) return choice;
    if (!mounted) return null;
    final created = await _createFolder();
    return created == null ? null : _FolderChoice(created);
  }

  /// Creates a folder and returns its name as the catalog spells it.
  Future<String?> _createFolder() async {
    final name = await _askFolderName(title: 'New folder');
    if (name == null || !mounted) return null;
    try {
      await _catalog.createFolder(name);
      return _catalog.canonicalFolder(name);
    } catch (error) {
      _notify('Could not create the folder: $error');
      return null;
    }
  }

  Future<void> _manageFolder(String folder) async {
    final packs = _catalog.packsInFolder(folder);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(folder),
              subtitle: Text('${_quizCount(packs.length)} in this folder'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename folder'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_delete_outlined),
              title: const Text('Delete folder'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      await _renameFolder(folder);
    } else {
      await _deleteFolder(folder, packs.length);
    }
  }

  Future<void> _renameFolder(String folder) async {
    final name = await _askFolderName(title: 'Rename folder', initial: folder);
    if (name == null || !mounted) return;
    try {
      await _catalog.renameFolder(folder, name);
    } catch (error) {
      if (mounted) _notify('Could not rename the folder: $error');
    }
  }

  Future<void> _deleteFolder(String folder, int packCount) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “$folder”?'),
        content: Text(
          packCount == 0
              ? 'This folder is empty.'
              : 'It holds ${_quizCount(packCount)}. They can stay on this '
                    'device as unfiled quizzes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (packCount > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, 'packs'),
              child: const Text('Delete quizzes too'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'folder'),
            child: Text(packCount == 0 ? 'Delete' : 'Keep quizzes'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _catalog.deleteFolder(folder, deletePacks: choice == 'packs');
  }

  Future<String?> _askFolderName({required String title, String? initial}) =>
      showDialog<String>(
        context: context,
        builder: (context) => _FolderNameDialog(title: title, initial: initial),
      );

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _quizCount(int count) => '$count ${count == 1 ? 'quiz' : 'quizzes'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tab == 0
            ? HomePage(
                catalog: _catalog,
                loading: _loading,
                onOpenQuiz: _openQuiz,
                onImport: _importQuiz,
                onManageQuiz: _manageQuiz,
                onManageFolder: _manageFolder,
                onCreateFolder: _createFolder,
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
    required this.catalog,
    required this.loading,
    required this.onOpenQuiz,
    required this.onImport,
    required this.onManageQuiz,
    required this.onManageFolder,
    required this.onCreateFolder,
    super.key,
  });

  final QuizCatalog catalog;
  final bool loading;
  final ValueChanged<QuizPack> onOpenQuiz;
  final VoidCallback onImport;
  final ValueChanged<QuizPack> onManageQuiz;
  final ValueChanged<String> onManageFolder;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builtIn = catalog.packs.where((pack) => !pack.isImported).toList();
    final folders = catalog.folders;
    final unfiled = catalog.packsInFolder(null);
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
        ...builtIn.map(
          (pack) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: QuizPackCard(pack: pack, onTap: () => onOpenQuiz(pack)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'My quizzes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New folder'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Imported packs, grouped into folders you choose.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (folders.isEmpty && unfiled.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nothing imported yet.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final folder in folders)
          QuizFolderSection(
            name: folder,
            packs: catalog.packsInFolder(folder),
            onOpenQuiz: onOpenQuiz,
            onManageQuiz: onManageQuiz,
            onManageFolder: () => onManageFolder(folder),
          ),
        if (unfiled.isNotEmpty)
          QuizFolderSection(
            name: 'Unfiled',
            packs: unfiled,
            onOpenQuiz: onOpenQuiz,
            onManageQuiz: onManageQuiz,
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Import YAML quizzes'),
        ),
      ],
    );
  }
}

/// One expandable folder of imported packs. Passing no [onManageFolder] marks
/// the section as the Unfiled group, which cannot be renamed or deleted.
class QuizFolderSection extends StatefulWidget {
  const QuizFolderSection({
    required this.name,
    required this.packs,
    required this.onOpenQuiz,
    required this.onManageQuiz,
    this.onManageFolder,
    super.key,
  });

  final String name;
  final List<QuizPack> packs;
  final ValueChanged<QuizPack> onOpenQuiz;
  final ValueChanged<QuizPack> onManageQuiz;
  final VoidCallback? onManageFolder;

  @override
  State<QuizFolderSection> createState() => _QuizFolderSectionState();
}

class _QuizFolderSectionState extends State<QuizFolderSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final manage = widget.onManageFolder;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              manage == null ? Icons.inbox_outlined : Icons.folder_outlined,
              color: colors.primary,
            ),
            title: Text(
              widget.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${widget.packs.length} ${widget.packs.length == 1 ? 'quiz' : 'quizzes'}',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (manage != null)
                  IconButton(
                    tooltip: 'Manage folder',
                    onPressed: manage,
                    icon: const Icon(Icons.more_vert),
                  ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
          if (_expanded && widget.packs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (final pack in widget.packs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: QuizPackCard(
                        pack: pack,
                        onTap: () => widget.onOpenQuiz(pack),
                        onManage: () => widget.onManageQuiz(pack),
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

/// Result of the folder picker: null means the user cancelled, while a choice
/// carrying a null folder means Unfiled.
class _FolderChoice {
  const _FolderChoice(this.folder) : isCreate = false;
  const _FolderChoice.create() : folder = null, isCreate = true;

  final String? folder;
  final bool isCreate;
}

/// Shows every picked file with its outcome and lets the user deselect files
/// and pick one destination for the whole batch. Returns the chosen
/// destination, or null when the import is cancelled.
class ImportReviewSheet extends StatefulWidget {
  const ImportReviewSheet({
    required this.candidates,
    required this.folders,
    required this.onCreateFolder,
    super.key,
  });

  // Folder names cannot contain '*', so these cannot collide with a folder.
  static const fromFile = '*from-file';
  static const unfiled = '*unfiled';
  static const _newFolder = '*new-folder';

  final List<QuizImportCandidate> candidates;
  final List<String> folders;
  final Future<String?> Function() onCreateFolder;

  @override
  State<ImportReviewSheet> createState() => _ImportReviewSheetState();
}

class _ImportReviewSheetState extends State<ImportReviewSheet> {
  late final List<String> _folders = [...widget.folders];
  String _destination = ImportReviewSheet.fromFile;

  Future<void> _changeDestination(String? value) async {
    if (value == null) return;
    if (value != ImportReviewSheet._newFolder) {
      setState(() => _destination = value);
      return;
    }
    final created = await widget.onCreateFolder();
    if (!mounted || created == null) return;
    setState(() {
      if (!_folders.any((folder) => QuizFolder.sameName(folder, created))) {
        _folders.add(created);
      }
      _destination = created;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final importable = widget.candidates.where((entry) => entry.canImport);
    final selected = importable.where((entry) => entry.selected).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review import',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.candidates.length} file(s) selected.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final candidate in widget.candidates) _row(candidate),
                ],
              ),
            ),
            if (importable.isNotEmpty) ...[
              const Divider(),
              Text('Destination folder', style: theme.textTheme.labelLarge),
              DropdownButton<String>(
                isExpanded: true,
                value: _destination,
                onChanged: _changeDestination,
                items: [
                  const DropdownMenuItem(
                    value: ImportReviewSheet.fromFile,
                    child: Text('From each file'),
                  ),
                  const DropdownMenuItem(
                    value: ImportReviewSheet.unfiled,
                    child: Text('Unfiled'),
                  ),
                  for (final folder in _folders)
                    DropdownMenuItem(value: folder, child: Text(folder)),
                  const DropdownMenuItem(
                    value: ImportReviewSheet._newFolder,
                    child: Text('New folder…'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: selected == 0
                      ? null
                      : () => Navigator.pop(context, _destination),
                  child: Text('Import $selected'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(QuizImportCandidate candidate) {
    final colors = Theme.of(context).colorScheme;
    if (!candidate.canImport) {
      final issue = candidate.errors.firstOrNull;
      return ListTile(
        leading: Icon(Icons.error_outline, color: colors.error),
        title: Text(candidate.fileName),
        subtitle: Text(
          issue == null
              ? 'This file was rejected.'
              : '${issue.path}: ${issue.message}',
        ),
      );
    }
    final pack = candidate.pack;
    final details = [
      candidate.statusLabel,
      if (pack != null) '${pack.questions.length} questions',
      if (pack?.folder != null) 'folder: ${pack?.folder}',
      if (candidate.warnings.isNotEmpty)
        '${candidate.warnings.length} warning(s)',
    ];
    return CheckboxListTile(
      value: candidate.selected,
      onChanged: (value) => setState(() => candidate.selected = value ?? false),
      title: Text(pack?.title ?? candidate.fileName),
      subtitle: Text(details.join(' · ')),
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = QuizFolder.normalize(_controller.text);
    if (name == null) {
      setState(
        () => _error =
            'Use 1 to ${QuizFolder.maxNameLength} letters, numbers, spaces, '
            'hyphens, or underscores, starting with a letter or a number.',
      );
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: QuizFolder.maxNameLength,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
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
