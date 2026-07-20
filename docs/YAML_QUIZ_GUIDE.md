# Creating YAML Quiz Packs

Labor Mentis quiz packs are plain-text YAML files. You can write them in any
text editor or generate a draft with an AI tool, then review and import them
locally.

> This document defines the planned version 1 import format. The YAML importer
> is not implemented in the current prototype yet.

## Quick start

1. Create a UTF-8 text file with the extension `.yaml` or `.yml`.
2. Copy one of the examples below.
3. Give the pack a unique, stable `id`.
4. Choose exactly one `mode` for the whole pack.
5. Save the file and import it from the app when YAML import is available.

YAML uses indentation to represent structure. Use spaces, not tabs. Two spaces
per level is recommended.

## Common fields

Every pack needs these fields:

| Field | Type | Description |
| --- | --- | --- |
| `schema_version` | integer | Use `1`. |
| `id` | string | Stable identifier: lowercase letters, numbers, and hyphens only. |
| `version` | integer | Start at `1`; increase it when updating the same pack. |
| `title` | string | Name shown in the app. |
| `category` | string | Group used in the catalog and score summary. |
| `mode` | string | One of `multiple_choice`, `true_false`, `text`, or `matching`. |
| `questions` | list | The quiz questions. |

`description` is optional.

## Multiple choice

Use `multiple_choice` for questions with one correct answer. The value of
`correct` must exactly match one item in `options`.

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

Use between 2 and 6 unique options per question.

## True or false

Use the YAML values `true` and `false` without quotation marks.

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

Do not write `"true"` or `"false"`: quoted values are text, not booleans.

## Text answer

Use `text` for short answers. Add all accepted answers to
`accepted_answers`. Answers are checked after removing leading and trailing
spaces and ignoring uppercase/lowercase differences.

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
```

Do not use this mode for long essays, open-ended opinions, or answers that
need AI evaluation.

## Matching pairs

Use `matching` to connect items in two columns. Each value on the left and on
the right must be unique inside one question.

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

Use between 2 and 20 pairs in a question.

## Updating a pack

Keep `id` unchanged when you correct or extend an existing pack. Increase the
`version` number each time:

```yaml
id: geography-world-capitals
version: 2
```

Use a new `id` only when the pack is a separate quiz. Stable IDs let Labor
Mentis keep score history associated with the right pack.

## Common mistakes

- Using tabs instead of spaces for indentation.
- Omitting a required field such as `mode` or `questions`.
- Mixing question fields from different modes.
- Giving a multiple-choice `correct` value that is not in `options`.
- Repeating an option or a matching-pair value.
- Putting a colon inside unquoted text. Quote it instead:

```yaml
prompt: "Which format uses a key: value structure?"
```

## AI prompt template

You can give this prompt to an AI tool when generating a pack:

```text
Create a valid YAML quiz pack for Labor Mentis schema version 1.

Topic: [TOPIC]
Audience: [AUDIENCE]
Category: [CATEGORY]
Mode: [multiple_choice | true_false | text | matching]
Number of questions: [NUMBER]

Return only YAML. Use English. Include schema_version, a lowercase-hyphenated
stable id, version 1, title, category, mode, and questions. Follow the mode
rules exactly. Do not use Markdown fences or explanations.
```

Always review generated questions and answers before importing them. AI output
can contain factual errors, ambiguous wording, or invalid YAML.

## Limits and safety

The planned importer accepts only local `.yaml` and `.yml` files. It will not
download content, follow links, execute code, or contact an AI service. Files
must be no larger than 1 MB and may contain up to 500 questions.

For the complete implementation and validation plan, see
[PLAN.md](../PLAN.md).
