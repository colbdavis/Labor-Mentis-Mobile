# Labor Mentis — Contributor Guidance

## Product principles

Keep Labor Mentis small, understandable, and useful offline.

- Follow **KISS**: prefer the simplest solution that satisfies the current
  requirement.
- Stay **minimalist**: do not introduce architecture layers, frameworks,
  packages, or abstractions before there is a concrete need for them.
- Be **local-first**: core gameplay, quiz content, scores, and imports must work
  without an account, a server, analytics, or an internet connection.
- Be **security-first**: treat imported content as untrusted; validate it before
  use, apply size and structure limits, never execute imported content, and do
  not resolve remote resources during import.
- Preserve the Android-first, lightweight nature of the app. Avoid dependencies
  and assets that undermine the APK-size target.

## Code quality

- Write straightforward Dart and Flutter code that a beginner can navigate.
- Prefer clear names and small functions over clever or compressed code.
- Keep UI text, documentation, identifiers, and code comments in English.
- Add comments only where they explain a non-obvious decision, invariant, or
  security constraint. Do not restate what the code already says.
- Keep the existing app behavior intact unless the requested change explicitly
  changes it.
- Format changed Dart code and add focused tests when behavior is added or
  changed.

## Quiz content and import work

- Treat `PLAN.md` as the implementation guide for YAML quiz import.
- Implement that plan in small, independently verifiable steps; do not skip
  validation, error handling, or tests to reach the file-picker UI faster.
- Keep YAML as Labor Mentis' native, human- and AI-friendly content format.
- Support a game mode only when its schema, validation rules, and gameplay
  behavior are all defined and tested.
- Keep stable pack IDs and versions so imported content and score history can
  evolve safely.

## Licensing

- Labor Mentis is independently developed and licensed under MIT.
- Do not copy GPL-licensed source code or assets into this repository without an
  explicit licensing decision by the project owner.
