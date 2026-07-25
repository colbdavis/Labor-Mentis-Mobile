/// Rules for the folders that group imported quiz packs.
///
/// A folder name is also the name of a directory inside the app's private
/// storage, and it can come from an imported YAML file. It is therefore
/// validated before any path is built from it. The allowed character set alone
/// rejects `.`, `..`, `/`, `\`, and control characters, so no separate
/// traversal check is needed.
class QuizFolder {
  static const maxNameLength = 40;
  static const maxFolders = 50;

  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]*$');

  /// Returns the trimmed folder name, or null when it cannot be used.
  static String? normalize(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) return null;
    return _allowed.hasMatch(trimmed) ? trimmed : null;
  }

  static bool isValid(String? name) => normalize(name) != null;

  /// Folders are compared case-insensitively so that a case-insensitive
  /// filesystem cannot end up with two directories for the same folder.
  static bool sameName(String? a, String? b) =>
      a?.toLowerCase() == b?.toLowerCase();

  static int compare(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
}
