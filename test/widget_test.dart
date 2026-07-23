import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/app_theme.dart';
import 'package:labor_mentis_mobile/main.dart';

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

  test('defines matching Dracula light and dark themes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.dark.useMaterial3, isTrue);
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xff282a36));
    expect(AppTheme.dark.colorScheme.primary, const Color(0xffbd93f9));
  });
}
