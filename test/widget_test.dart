import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/app_theme.dart';
import 'package:labor_mentis_mobile/import/quiz_catalog.dart';
import 'package:labor_mentis_mobile/import/quiz_yaml_parser.dart';
import 'package:labor_mentis_mobile/main.dart';
import 'package:labor_mentis_mobile/models/quiz_pack.dart';

const _importedPack = '''
schema_version: 1
id: imported-pack
version: 1
title: Imported pack
category: Tests
mode: true_false
questions:
  - prompt: A statement.
    correct: true
''';

void main() {
  testWidgets('a default quiz can be opened from the catalog', (tester) async {
    await tester.pumpWidget(const LaborMentisApp());

    expect(find.text('Included quizzes'), findsOneWidget);
    expect(find.text('World capitals'), findsOneWidget);

    await tester.tap(find.text('World capitals'));
    await tester.pumpAndSettle();

    expect(find.text('What is the capital of Portugal?'), findsOneWidget);
    expect(find.text('Lisbon'), findsOneWidget);
  });

  testWidgets('imported packs are grouped into their folder', (tester) async {
    late final QuizCatalog catalog;
    // File system work needs the real clock, not the widget test's fake one.
    await tester.runAsync(() async {
      final storage = await Directory.systemTemp.createTemp('home_page_test');
      addTearDown(() => storage.delete(recursive: true));
      catalog = QuizCatalog(storageDirectory: storage);
      await catalog.load();
      final pack = QuizYamlParser().parse(_importedPack).pack as QuizPack;
      await catalog.save(_importedPack, pack, folder: 'Biology 101');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            catalog: catalog,
            loading: false,
            onOpenQuiz: (_) {},
            onImport: () {},
            onManageQuiz: (_) {},
            onManageFolder: (_) {},
            onCreateFolder: () {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Imported pack'), 200);

    expect(find.text('My quizzes'), findsOneWidget);
    expect(find.text('Biology 101'), findsOneWidget);
    expect(find.text('1 quiz'), findsOneWidget);

    await tester.tap(find.text('Biology 101'));
    await tester.pumpAndSettle();

    expect(find.text('Imported pack'), findsNothing);
  });

  test('defines matching Dracula light and dark themes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xff282a36));
    expect(AppTheme.dark.colorScheme.primary, const Color(0xffbd93f9));
  });
}
