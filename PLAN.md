# YAML Quiz Import Plan

## Goal

Allow users to import AI-generated or hand-written YAML quiz packs from local
storage. Imported packs must work fully offline, use the same game modes as the
built-in packs, survive app restarts, and never crash the app when a file is
invalid.

The first version supports one game mode per quiz pack:

- `multiple_choice`
- `true_false`
- `text`
- `matching`

Mixed-mode packs can be considered later. Keeping one mode per pack matches the
current `QuizPack` model and makes validation and gameplay easier to understand.

## Proposed YAML format (schema version 1)

Every file represents one quiz pack. IDs must remain stable between revisions
so that an updated file can replace an older version without losing its score
history.

### Multiple choice

```yaml
schema_version: 1
id: geography-world-capitals
version: 1
title: World Capitals
category: Geography
description: A short quiz about national capitals.
mode: multiple_choice

questions:
  - prompt: What is the capital of Portugal?
    options:
      - Madrid
      - Lisbon
      - Porto
      - Barcelona
    correct: Lisbon

  - prompt: What is the capital of Australia?
    options:
      - Sydney
      - Melbourne
      - Canberra
      - Perth
    correct: Canberra
```

Using the answer text instead of a numeric index makes files easier for people
and AI tools to generate and review. During import, the app converts `correct`
to the internal option index.

### True or false

```yaml
schema_version: 1
id: science-basics
version: 1
title: Science Basics
category: Science
mode: true_false

questions:
  - prompt: Water boils at 100 °C at sea level.
    correct: true

  - prompt: The Sun is a planet.
    correct: false
```

### Text answer

```yaml
schema_version: 1
id: chemistry-symbols
version: 1
title: Chemical Symbols
category: Science
mode: text

questions:
  - prompt: What is the chemical symbol for gold?
    accepted_answers:
      - Au

  - prompt: What is the chemical symbol for sodium?
    accepted_answers:
      - Na
      - na
```

Version 1 compares answers after trimming surrounding whitespace and converting
both strings to lowercase. Accent removal, fuzzy matching, and regular
expressions are intentionally excluded from the first importer.

### Matching pairs

```yaml
schema_version: 1
id: literature-authors-and-works
version: 1
title: Authors and Works
category: Literature
mode: matching

questions:
  - prompt: Match each author with their work.
    pairs:
      - left: Dante
        right: Divine Comedy
      - left: Manzoni
        right: The Betrothed
      - left: Leopardi
        right: The Infinite
```

## Validation rules

Validation happens before a pack appears in the catalog. A rejected file must
show a useful error and must not alter previously imported data.

### File-level rules

- File extension must be `.yaml` or `.yml`.
- File size must not exceed 1 MB in version 1.
- The YAML root must be a map, not a list or scalar.
- `schema_version` must be the integer `1`.
- `id` must contain only lowercase letters, numbers, and hyphens, with a maximum
  length of 80 characters.
- `version` must be a positive integer.
- `title` and `category` must be non-empty strings.
- `mode` must be one of the four supported values.
- `questions` must contain between 1 and 500 items.
- Unknown fields should produce warnings, not errors, so future additions remain
  easier to introduce.

### Question-level rules

- Every question needs a non-empty `prompt`.
- Text fields should have reasonable length limits, for example 500 characters
  for prompts and 200 characters for answers.
- Multiple choice requires between 2 and 6 unique options. `correct` must match
  exactly one option.
- True or false requires a YAML boolean for `correct`, not the strings `"true"`
  or `"false"`.
- Text answer requires at least one non-empty, unique accepted answer.
- Matching requires between 2 and 20 pairs. Values in each side must be unique
  so that every match is unambiguous.
- Fields belonging to another mode should be reported as warnings.

### Safety rules

- Read file bytes locally; never resolve URLs or remote references.
- Check the byte-size limit before parsing YAML.
- Do not execute content or interpret HTML/Markdown during import.
- Limit parsed collections and string lengths to avoid unusually expensive files.
- Catch YAML syntax errors and convert them into user-facing messages.

## Implementation steps

### Step 1 — Extract the quiz data models

Move the current model types out of `lib/main.dart` without changing behavior:

```text
lib/
  models/
    game_mode.dart
    quiz_pack.dart
    quiz_question.dart
    quiz_result.dart
```

Keep the built-in packs in `lib/data/built_in_quiz_packs.dart`. This is a small
separation needed by the importer, not a new application architecture.

Done when:

- The existing four quiz modes still work.
- Existing widget tests still pass.
- No YAML dependency has been added yet.

### Step 2 — Parse YAML text into Dart values

Add the `yaml` package and create:

```text
lib/import/quiz_yaml_parser.dart
lib/import/quiz_import_error.dart
```

`QuizYamlParser.parse(String source)` should return either a valid `QuizPack` or
a structured list of errors. Keep file selection out of this class so it can be
tested with plain strings.

Implementation order:

1. Parse common pack fields.
2. Map the YAML `mode` string to `GameMode`.
3. Parse multiple-choice questions.
4. Parse true/false questions.
5. Parse text-answer questions.
6. Parse matching questions.

Done when:

- Each example in this document parses into the current Dart models.
- Invalid types and missing fields return understandable errors.
- Parser tests do not need Android or a file picker.

### Step 3 — Add validation tests and fixtures

Create small fixtures under:

```text
test/fixtures/yaml/
  valid/
  invalid/
```

Test at least:

- One valid file for every mode.
- Malformed YAML.
- Unsupported `schema_version` and `mode`.
- Missing title, category, or questions.
- Correct multiple-choice answer absent from the options.
- String used instead of a true/false boolean.
- Empty accepted-answer list.
- Duplicate or incomplete matching pairs.
- Oversized collections and strings.

Done when parser behavior is deterministic and every validation error has a
short user-facing message plus a technical field path such as
`questions[2].correct`.

### Step 4 — Import a file on Android

Add a file-picker dependency only at this stage. Configure it to select one
`.yaml` or `.yml` file and request file bytes, allowing Android's system document
picker to handle storage access.

Connect the existing **Import a YAML quiz** button to this flow:

```text
Tap import
  → choose file
  → check size
  → decode UTF-8
  → parse and validate
  → show preview
  → confirm import
```

The preview should show title, category, mode, question count, pack ID, and
version. Syntax or validation errors should appear on a dedicated result sheet,
not only in a temporary snackbar.

Done when a valid file can be selected on an Android device and appears in the
catalog for the current app session.

### Step 5 — Merge built-in and imported packs

Replace the compile-time catalog list with a small in-memory catalog controller
that exposes:

- all built-in packs;
- all imported packs;
- lookup by stable pack ID;
- add, replace, and remove operations.

Duplicate policy:

- A new ID is added.
- The same ID with a higher `version` asks the user to confirm an update.
- The same ID and version asks whether to replace the existing copy.
- A lower version shows a downgrade warning and requires confirmation.
- Built-in packs cannot be overwritten; an imported ID conflicting with a
  built-in ID is rejected.

Done when all four imported modes launch through the existing game screens.

### Step 6 — Persist imported packs locally

After session-only importing works, add local persistence. Store the original,
validated YAML files inside the app's private support directory. On startup:

1. Load built-in packs.
2. Read locally stored YAML files.
3. Parse and validate each file again.
4. Add valid packs to the catalog.
5. Isolate invalid files and report them without blocking app startup.

Use atomic writes: write to a temporary file, validate it, then rename it to its
final filename. A failed import must leave the old version untouched.

Add a pack-management screen with **Details**, **Replace**, and **Remove**. File
removal must ask for confirmation. Score history should be keyed by pack ID, not
by the imported filename.

Done when imported packs remain available after closing and reopening the app.

### Step 7 — Improve import UX

- Show progress while reading and parsing.
- Clearly distinguish errors from warnings.
- Allow copying validation details for fixing an AI-generated file.
- Add a link to an in-app schema example.
- Provide a reusable prompt template users can give to an AI model.
- Show whether a pack is built in or imported.
- Display an update badge when a higher pack version is imported.

Keep import confirmation accessible: do not rely on color alone, use plain
labels, and ensure error text can be selected and read by screen readers.

### Step 8 — Release checks

- Test file selection on at least one recent Android version and one older
  supported version.
- Import files created by several text editors and AI tools.
- Test UTF-8 characters, apostrophes, emoji, and multiline YAML strings.
- Test cancellation at every import step.
- Test duplicate IDs, updates, downgrades, removal, and app restart.
- Confirm airplane-mode operation.
- Build a release APK and verify the final size remains below the project target.
- Document the schema and include copyable examples for all modes.

## Minimal dependencies

Introduce these only in the step where they are needed:

- `yaml`: parse YAML safely into Dart values.
- A maintained file-picker package: use Android's document picker.
- `path_provider`: locate the private application directory when persistence is
  implemented.

No database, state-management framework, code generator, network client, or
backend is required for the first YAML importer.

## Suggested first implementation slice

The smallest useful slice is Steps 1–3 plus multiple-choice support only. It
teaches the complete parsing and validation path without involving Android file
permissions. Once that parser is solid, add the other three modes and then the
system file picker.

## Definition of done for YAML import v1

- Users can select a local `.yaml` or `.yml` file.
- The app validates it without crashing or accessing the network.
- All four game modes in this document are supported.
- Valid packs appear alongside built-in packs and remain after restart.
- Invalid packs show actionable errors and do not modify stored data.
- Packs can be updated or removed.
- Scores remain associated with the stable pack ID across updates.
- The schema and AI-generation examples are documented in English.
