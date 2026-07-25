import 'dart:convert';
import 'dart:typed_data';

import '../models/quiz_pack.dart';
import 'quiz_import_error.dart';
import 'quiz_yaml_parser.dart';

/// A file chosen in the system picker, already read into memory.
class PickedQuizFile {
  const PickedQuizFile(this.name, this.bytes, {this.size});

  final String name;
  final Uint8List? bytes;

  /// Size reported by the picker, checked before the bytes are used.
  final int? size;

  int get byteCount => size ?? bytes?.length ?? 0;
}

enum QuizImportStatus {
  /// The pack ID is not installed yet.
  newPack,

  /// Installed at a lower version.
  update,

  /// Installed at the same version.
  reinstall,

  /// Installed at a higher version.
  downgrade,

  /// Rejected before it could be reviewed.
  failed,
}

/// One picked file after validation, ready to be shown in the review sheet.
class QuizImportCandidate {
  QuizImportCandidate({
    required this.fileName,
    required this.status,
    this.pack,
    this.source,
    this.installedVersion,
    this.errors = const [],
    this.warnings = const [],
    required this.selected,
  });

  final String fileName;
  final QuizImportStatus status;
  final QuizPack? pack;
  final String? source;
  final int? installedVersion;
  final List<QuizImportIssue> errors;
  final List<QuizImportIssue> warnings;

  /// Whether the user wants to import this file. Downgrades start unselected.
  bool selected;

  bool get canImport => status != QuizImportStatus.failed;

  String get statusLabel => switch (status) {
    QuizImportStatus.newPack => 'New',
    QuizImportStatus.update => 'Update $installedVersion → ${pack?.version}',
    QuizImportStatus.reinstall => 'Already installed',
    QuizImportStatus.downgrade =>
      'Downgrade $installedVersion → ${pack?.version}',
    QuizImportStatus.failed => 'Not imported',
  };
}

/// Turns picked files into reviewable candidates. This step touches no UI and
/// writes nothing to disk, so the whole batch can be tested with byte lists.
class QuizBatchImporter {
  QuizBatchImporter({QuizYamlParser? parser})
    : _parser = parser ?? QuizYamlParser();

  static const maxFiles = 25;
  static final RegExp _extension = RegExp(r'\.ya?ml$', caseSensitive: false);

  final QuizYamlParser _parser;

  /// [installed] returns the pack already in the catalog for an ID, and
  /// [isBuiltIn] reports IDs that must never be overwritten.
  List<QuizImportCandidate> prepare(
    List<PickedQuizFile> files, {
    required QuizPack? Function(String id) installed,
    required bool Function(String id) isBuiltIn,
  }) {
    final candidates = <QuizImportCandidate>[];
    final seenIds = <String>{};
    for (final file in files.take(maxFiles)) {
      candidates.add(_prepareOne(file, seenIds, installed, isBuiltIn));
    }
    for (final file in files.skip(maxFiles)) {
      candidates.add(
        _failed(file.name, 'Select at most $maxFiles files at a time.'),
      );
    }
    return candidates;
  }

  QuizImportCandidate _prepareOne(
    PickedQuizFile file,
    Set<String> seenIds,
    QuizPack? Function(String id) installed,
    bool Function(String id) isBuiltIn,
  ) {
    if (!_extension.hasMatch(file.name)) {
      return _failed(file.name, 'Choose a .yaml or .yml file.');
    }
    if (file.byteCount > QuizYamlParser.maxSourceBytes) {
      return _failed(file.name, 'The file exceeds the 1 MB limit.');
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return _failed(file.name, 'The file could not be read.');
    }
    String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return _failed(file.name, 'The file must contain valid UTF-8 text.');
    }
    final result = _parser.parse(source);
    if (!result.isValid) {
      return QuizImportCandidate(
        fileName: file.name,
        status: QuizImportStatus.failed,
        errors: result.errors,
        warnings: result.warnings,
        selected: false,
      );
    }
    final pack = result.pack as QuizPack;
    if (isBuiltIn(pack.id)) {
      return _failed(
        file.name,
        'The ID “${pack.id}” belongs to a built-in quiz.',
        path: 'id',
      );
    }
    if (!seenIds.add(pack.id)) {
      return _failed(
        file.name,
        'Another selected file already uses the ID “${pack.id}”.',
        path: 'id',
      );
    }
    final existing = installed(pack.id);
    final status = existing == null
        ? QuizImportStatus.newPack
        : pack.version > existing.version
        ? QuizImportStatus.update
        : pack.version == existing.version
        ? QuizImportStatus.reinstall
        : QuizImportStatus.downgrade;
    return QuizImportCandidate(
      fileName: file.name,
      status: status,
      pack: pack,
      source: source,
      installedVersion: existing?.version,
      warnings: result.warnings,
      // Replacing a newer pack with an older one is never automatic.
      selected: status != QuizImportStatus.downgrade,
    );
  }

  QuizImportCandidate _failed(
    String fileName,
    String message, {
    String path = 'file',
  }) => QuizImportCandidate(
    fileName: fileName,
    status: QuizImportStatus.failed,
    errors: [QuizImportIssue(path, message)],
    selected: false,
  );
}
