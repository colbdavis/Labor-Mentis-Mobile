# Labor Mentis — Contributor Guidance

Labor Mentis is an **offline, Android-first Flutter** quiz and minigame engine.
This file is the working brief for any human or AI agent contributing to the
repository. Keep it accurate when the project's structure or conventions change.

## What this app is

- A local-first quiz app with four playable modes: **multiple choice**,
  **true/false**, **text answer**, and **matching pairs**.
- Ships with built-in quiz packs and can **import user-supplied YAML quiz packs**
  from local storage. Imported packs are validated, stored in the app's private
  directory, and survive restarts.
- A **Scores** screen computes the overall average and groups results by category.
- No account, server, analytics, or network access is required for any feature.

## Tech stack

- **Flutter 3.44.x (stable)** / **Dart 3.12.x**, Material 3, `ThemeMode.system`.
- Runtime dependencies (kept deliberately minimal): `yaml`, `file_picker`,
  `path_provider`, `cupertino_icons`.
- Dev: `flutter_test`, `flutter_lints` (see `analysis_options.yaml`).
- Targets Android (API 36); can also run on Linux desktop for quick iteration.
- Environment setup and SDK locations are documented in `flutter-guide.md`.

## Project layout

```text
lib/
  main.dart                       App entry, all screen widgets, game logic
  app_theme.dart                  Light/dark ColorSchemes (Dracula-derived)
  models/
    game_mode.dart                GameMode enum + label/icon/color/yamlValue
    quiz_pack.dart                QuizPack model (stable id + version)
    quiz_question.dart            Question model shared by all modes
    quiz_result.dart              Per-session result model
  data/
    built_in_quiz_packs.dart      Compile-time built-in packs
  import/
    quiz_yaml_parser.dart         YAML text -> QuizPack or structured errors
    quiz_import_error.dart        Import issue/error types
    quiz_catalog.dart             ChangeNotifier merging built-in + imported packs
test/
  widget_test.dart                Smoke test opening a built-in quiz
  quiz_yaml_parser_test.dart      Parser/validation tests
docs/YAML_QUIZ_GUIDE.md           User-facing YAML schema documentation
PLAN.md                           Implementation guide for YAML quiz import
flutter-guide.md                  Local dev environment / SDK / device notes
```

State is deliberately simple: `QuizCatalog extends ChangeNotifier` is the only
shared controller. There is no state-management framework, database, code
generator, or DI container — do not add one without a concrete, discussed need.

## Commands

Run from the project root:

```zsh
flutter pub get              # After changing pubspec.yaml
flutter run                  # Build & run on a selected device (r=reload, R=restart, q=quit)
flutter analyze              # Static analysis — must be clean
flutter test                 # Run all tests
dart format lib test         # Format Dart source
flutter build apk --debug    # Debug APK -> build/app/outputs/flutter-apk/app-debug.apk
```

Before considering a change complete: `dart format lib test`, then
`flutter analyze` (no new issues) and `flutter test` (all passing).

## Product principles

Keep Labor Mentis small, understandable, and useful offline.

- **KISS**: prefer the simplest solution that satisfies the current requirement.
- **Minimalist**: do not introduce architecture layers, frameworks, packages, or
  abstractions before there is a concrete need for them.
- **Local-first**: core gameplay, quiz content, scores, and imports must work
  without an account, a server, analytics, or an internet connection.
- **Security-first**: treat imported content as untrusted; validate it before
  use, apply size and structure limits, never execute imported content, and do
  not resolve remote resources during import.
- **Lightweight**: preserve the Android-first nature of the app. Avoid
  dependencies and assets that undermine the APK-size target.

## Code quality

- Write straightforward Dart and Flutter code that a beginner can navigate.
- Prefer clear names and small functions over clever or compressed code.
- Match the surrounding style: Material 3 widgets, `switch` expressions for
  per-mode variation (see `game_mode.dart`), colors resolved from the active
  `ColorScheme` rather than hard-coded where possible.
- Keep UI text, documentation, identifiers, and code comments in English.
- Add comments only where they explain a non-obvious decision, invariant, or
  security constraint. Do not restate what the code already says.
- Keep existing app behavior intact unless the requested change explicitly
  changes it.
- Format changed Dart code and add focused tests when behavior is added or
  changed.

## Quiz content and import work

- Treat `PLAN.md` as the implementation guide for YAML quiz import, and
  `docs/YAML_QUIZ_GUIDE.md` as the user-facing schema contract. Keep both in
  sync with the parser in `lib/import/`.
- Implement in small, independently verifiable steps; do not skip validation,
  error handling, or tests to reach the file-picker UI faster.
- Keep YAML as Labor Mentis' native, human- and AI-friendly content format.
- Support a game mode only when its schema, validation rules, and gameplay
  behavior are all defined and tested.
- Keep stable pack **IDs** and **versions** so imported content and score
  history can evolve safely. Score history is keyed by pack ID, not filename.
- Import safety is non-negotiable: enforce the file-size limit before parsing,
  read bytes locally only, reject remote references, cap collection and string
  sizes, and turn YAML syntax errors into actionable user-facing messages.

## Licensing

- Labor Mentis is independently developed and licensed under MIT (see `LICENSE`).
- Do not copy GPL-licensed source code or assets into this repository without an
  explicit licensing decision by the project owner.
