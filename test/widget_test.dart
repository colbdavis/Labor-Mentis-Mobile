import 'package:flutter_test/flutter_test.dart';
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
}
