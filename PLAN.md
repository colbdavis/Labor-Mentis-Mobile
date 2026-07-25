# YAML Quiz Import Plan

This file is the implementation guide for YAML quiz import.

- **Part 1** describes import version 1: one file, one pack. It is implemented.
- **Part 2** describes import version 2: folders and multi-file import.

The user-facing schema contract lives in [docs/YAML_QUIZ_GUIDE.md](docs/YAML_QUIZ_GUIDE.md)
and must stay in sync with `lib/import/quiz_yaml_parser.dart`.

---

# Part 1 — Import version 1 (implemented)

## Goal

Allow users to import AI-generated or hand-written YAML quiz packs from local
storage. Imported packs work fully offline, use the same game modes as the
built-in packs, survive app restarts, and never crash the app when a file is
invalid.

One game mode per quiz pack:

- `multiple_choice`
- `true_false`
- `text`
- `matching`

Mixed-mode packs can be considered later. Keeping one mode per pack matches the
`QuizPack` model and makes validation and gameplay easier to understand.

## YAML format (schema version 1)

Every file represents one quiz pack. IDs must remain stable between revisions so
that an updated file can replace an older version without losing its score
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
```

Answers are compared after trimming surrounding whitespace and converting both
strings to lowercase. Accent removal, fuzzy matching, and regular expressions
are intentionally excluded.

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
```

## Validation rules

Validation happens before a pack appears in the catalog. A rejected file must
show a useful error and must not alter previously imported data.

### File-level rules

- File extension must be `.yaml` or `.yml`.
- File size must not exceed 1 MB.
- The YAML root must be a map, not a list or scalar.
- `schema_version` must be the integer `1`.
- `id` must contain only lowercase letters, numbers, and hyphens, with a maximum
  length of 80 characters.
- `version` must be a positive integer.
- `title` and `category` must be non-empty strings.
- `mode` must be one of the four supported values.
- `questions` must contain between 1 and 500 items.
- Unknown fields produce warnings, not errors, so future additions remain easier
  to introduce.

### Question-level rules

- Every question needs a non-empty `prompt`.
- Text fields have length limits: 500 characters for prompts, 200 for answers.
- Multiple choice requires between 2 and 6 unique options. `correct` must match
  exactly one option.
- True or false requires a YAML boolean for `correct`, not the strings `"true"`
  or `"false"`.
- Text answer requires at least one non-empty, unique accepted answer.
- Matching requires between 2 and 20 pairs. Values on each side must be unique
  so that every match is unambiguous.
- Fields belonging to another mode are reported as warnings.

### Safety rules

- Read file bytes locally; never resolve URLs or remote references.
- Check the byte-size limit before parsing YAML.
- Do not execute content or interpret HTML/Markdown during import.
- Limit parsed collections and string lengths to avoid unusually expensive files.
- Catch YAML syntax errors and convert them into user-facing messages.

## What shipped

- `lib/models/` holds the extracted data models; built-in packs live in
  `lib/data/built_in_quiz_packs.dart`.
- `lib/import/quiz_yaml_parser.dart` turns YAML text into a `QuizPack` or a list
  of `QuizImportIssue` errors and warnings, with field paths such as
  `questions[2].correct`.
- `lib/import/quiz_catalog.dart` merges built-in and imported packs, and stores
  validated YAML files in the app's private support directory using atomic
  writes (temporary file, rename, backup rollback on failure).
- The import button picks one file, checks the size, decodes UTF-8, parses,
  shows a confirmation preview, and saves.
- Duplicate policy: built-in IDs cannot be overwritten; a matching ID asks the
  user to confirm an update, a reinstall, or a downgrade.
- Score history is keyed by pack ID, not by filename.

---

# Part 2 — Import version 2: folders and multi-file import

## Goal

Two related gaps in version 1:

1. Every imported pack lands in one flat list. A user with twenty imported packs
   cannot group them by course, subject, or exam.
2. Importing twenty packs means opening the file picker twenty times and
   confirming twenty dialogs.

Version 2 adds **folders** for imported packs and **multi-file import** in a
single picker selection with one review step.

Non-goals for this version, to keep the app small:

- Nested folders. One level only.
- Folders for built-in packs. They stay in their own section.
- Folder-based scoring. The score screen keeps grouping by `category`, which is
  content metadata, whereas a folder is a personal filing choice.
- Importing archives (`.zip`) or whole directory trees. Android's document
  picker returns files, and unpacking archives is a much larger attack surface.

## Concepts

A **folder** is a plain name that groups imported packs, for example
`Biology 101`. A pack belongs to at most one folder. A pack with no folder is
shown under **Unfiled**.

The folder is *storage location*, not content: it is the subdirectory the pack's
YAML file is stored in. This is deliberate, because it means:

- no new metadata file, index, or database;
- moving a pack is a file rename;
- renaming a folder is a directory rename;
- the state on disk cannot disagree with the state in memory.

A YAML file may *suggest* a folder with the optional `folder` field. The
suggestion only prefills the destination during import; the location on disk
remains the single source of truth afterwards.

### Storage layout

```text
<app support>/quiz_packs/
  chemistry-symbols.yaml            # Unfiled
  Biology 101/
    cell-structure.yaml
    genetics-basics.yaml
  Exam Prep/
    world-capitals-drill.yaml
```

Version 1 stored every file directly under `quiz_packs/`. Those files are read
as Unfiled packs, so there is no migration step and no upgrade path to break.

### Folder name rules

Folder names become directory names built from untrusted YAML input, so they are
validated before any path is constructed:

- 1 to 40 characters after trimming.
- Letters, numbers, spaces, hyphens, and underscores only.
- Must start with a letter or a number. This rejects `.`, `..`, and hidden
  names, and combined with the character set it rejects `/`, `\`, null bytes,
  control characters, and every traversal sequence.
- Names are compared case-insensitively, so `Biology` and `biology` are the same
  folder. A device with a case-insensitive filesystem must not be able to create
  two folders that collide.
- At most 50 folders.

Rejection is an error, not a silent fallback to Unfiled: a file that asks for
`../../secrets` must be reported, never quietly filed somewhere else.

## Schema change

`folder` is added as an optional pack field in schema version 1. It is additive,
so files without it keep importing exactly as before, and older files remain
valid.

```yaml
schema_version: 1
id: cell-structure
version: 1
title: Cell Structure
category: Biology
folder: Biology 101
mode: multiple_choice
```

`schema_version` stays `1`. Bumping it would reject every existing file for an
optional field, which is worse than the alternative: a version 1 app reading a
file with `folder` reports one "Unknown field" warning and imports the pack.

## Multi-file import flow

```text
Tap import
  → pick 1..25 files
  → for each file: extension, size, UTF-8, parse, ID conflicts
  → review sheet: per-file outcome + destination folder
  → confirm
  → save each accepted file
  → result summary
```

Per-file preparation is a pure step with no UI and no disk writes, so it can be
tested with plain byte lists. Each file produces one candidate with a status:

| Status | Meaning |
| --- | --- |
| `newPack` | The ID is not installed yet. |
| `update` | Installed at a lower version. |
| `reinstall` | Installed at the same version. |
| `downgrade` | Installed at a higher version. |
| `failed` | Rejected: bad extension, too large, not UTF-8, invalid YAML, built-in ID, or an ID repeated inside the same selection. |

The review sheet lists every candidate with its status and lets the user
deselect any of them. `newPack`, `update`, and `reinstall` are selected by
default; `downgrade` is listed but deselected, so overwriting a newer pack is
always a deliberate choice. `failed` rows are not selectable and show their
first error.

Batch limits, checked before any parsing:

- at most 25 files per selection;
- the existing 1 MB limit per file;
- files are prepared one at a time, so peak memory stays close to one file.

Partial success is the expected outcome: valid files import, rejected files are
reported. Each file is still written atomically on its own, so a failure halfway
through the batch cannot corrupt an earlier pack.

### Destination

The review sheet has one destination selector for the whole batch:

- **From each file** (default): use each file's `folder` field, or Unfiled.
- **Unfiled**.
- Any existing folder.
- **New folder…**, which asks for a name and validates it immediately.

One selector for the batch is enough for the common case ("import this course's
files into this folder") and avoids a per-row folder picker.

## Library screen

Imported packs move out of the flat list into their own section:

```text
Included quizzes
  <built-in packs>

My quizzes
  ▸ Biology 101 (4)
  ▸ Exam Prep (2)
  ▸ Unfiled (1)
```

- Folders are expandable sections, sorted case-insensitively, with Unfiled last.
- A folder header shows its name and pack count, and a menu with **Rename** and
  **Delete**.
- Deleting a folder moves its packs to Unfiled by default; removing the packs
  themselves is a separate, explicitly confirmed choice.
- The per-pack manage sheet gains **Move to folder…**.
- Empty folders remain visible, so creating a folder before importing works.

## Implementation steps

Each step is independently verifiable: `dart format lib test`, then
`flutter analyze` and `flutter test`.

### Step 1 — Folder name rules

Add `lib/import/quiz_folder.dart` with the validation described above:
`QuizFolder.normalize(String?)` returning the cleaned name or `null`, plus
case-insensitive comparison and the folder-count limit.

Done when unit tests cover the accepted character set, length bounds, and the
rejection of `..`, `.`, `a/b`, `\`, leading dots and spaces, empty strings, and
control characters.

### Step 2 — Model and parser

- `QuizPack` gains `final String? folder`.
- `asImported({required String? folder})` sets the location explicitly, so
  "move to Unfiled" cannot be confused with "keep the current folder".
- The parser accepts `folder`, validates it with `QuizFolder`, and reports an
  invalid value as an error at path `folder`.

Done when parser tests cover a valid folder, a rejected folder, and a file
without the field.

### Step 3 — Folder-aware catalog

Rework `QuizCatalog` storage:

- `load()` walks `quiz_packs/` and one level of subdirectories, validating each
  directory name and skipping anything else. Leftover `.tmp` and `.backup` files
  are cleaned up.
- A pack ID found twice keeps the first copy and reports a startup issue, so a
  duplicated file cannot silently shadow another folder's pack.
- `save(source, pack, folder:)` writes into the destination directory with the
  existing atomic write, then deletes the pack's previous file if it moved.
- New operations: `move(id, folder)`, `createFolder`, `renameFolder`,
  `deleteFolder({deletePacks})`.
- The constructor accepts an optional storage directory so the catalog can be
  tested against a temporary directory instead of `path_provider`.

Done when catalog tests cover saving into a folder, reloading, moving between
folders, renaming, deleting with and without packs, duplicate IDs, and the
version 1 flat layout still loading as Unfiled.

### Step 4 — Batch preparation

Add `lib/import/quiz_batch_import.dart` with `PickedQuizFile`,
`QuizImportCandidate`, `QuizImportStatus`, and a `QuizBatchImporter.prepare`
that turns picked bytes into candidates. No UI, no file system.

Done when tests cover each status, the per-file failures, a duplicate ID inside
one selection, and the 25-file limit.

### Step 5 — Import UI

- Switch the picker to `allowMultiple: true`.
- Add the review sheet with per-file rows, the destination selector, and the new
  folder dialog.
- Save the selected candidates in order and show a summary of imported, skipped,
  and failed files, with copyable error details.

Done when importing several files at once works on a device, including a
selection that mixes valid and invalid files.

### Step 6 — Library UI

Group imported packs by folder, add the folder menu and **Move to folder…**, and
keep the built-in section unchanged.

Done when a widget test opens a built-in quiz as before and folder sections
render for imported packs.

### Step 7 — Documentation and release checks

- Document `folder` and multi-file import in `docs/YAML_QUIZ_GUIDE.md`, and
  mention the field in the AI prompt template.
- Update `CLAUDE.md` when the file layout changes.
- Manual checks: import 25 files at once; import a mixed valid/invalid
  selection; rename a folder containing packs; delete a folder both ways; move a
  pack; restart the app and confirm placement survives; confirm airplane-mode
  operation; verify the release APK size target still holds.

## Security notes

Folders are the only new untrusted-input surface in this version.

- A folder name is validated before it is used to build any path, and an invalid
  name is rejected rather than corrected.
- Only one level of nesting is read, and only directory names that pass
  validation are opened.
- Pack IDs are already restricted to lowercase letters, numbers, and hyphens, so
  the filename `<id>.yaml` cannot escape its directory either.
- No new dependency is required: `file_picker` already supports multi-selection
  and `dart:io` already handles directories.

## Definition of done for import v2

- A single picker selection imports up to 25 YAML files with one review step.
- Invalid files in a batch are reported without blocking the valid ones.
- Imported packs can be filed into folders, moved, and refiled.
- Folders can be created, renamed, and deleted without deleting their packs.
- Placement survives an app restart with no metadata file.
- The optional `folder` YAML field is documented, validated, and safe.
- Scores stay keyed by pack ID and grouped by category.
