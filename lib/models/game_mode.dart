import 'package:flutter/material.dart';

const indigo = Color(0xff4f46e5);
const mint = Color(0xff0f766e);

enum GameMode { multipleChoice, trueFalse, text, matching }

extension GameModeDetails on GameMode {
  String get yamlValue => switch (this) {
    GameMode.multipleChoice => 'multiple_choice',
    GameMode.trueFalse => 'true_false',
    GameMode.text => 'text',
    GameMode.matching => 'matching',
  };

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
    GameMode.multipleChoice => indigo,
    GameMode.trueFalse => mint,
    GameMode.text => const Color(0xffc2410c),
    GameMode.matching => const Color(0xffa21caf),
  };
}
