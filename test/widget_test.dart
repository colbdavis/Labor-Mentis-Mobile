import 'package:flutter_test/flutter_test.dart';
import 'package:labor_mentis_mobile/main.dart';

void main() {
  testWidgets('a default quiz can be opened from the catalog', (tester) async {
    await tester.pumpWidget(const LaborMentisApp());

    expect(find.text('Quiz inclusi'), findsOneWidget);
    expect(find.text('Capitali del mondo'), findsOneWidget);

    await tester.tap(find.text('Capitali del mondo'));
    await tester.pumpAndSettle();

    expect(find.text('Qual è la capitale del Portogallo?'), findsOneWidget);
    expect(find.text('Lisbona'), findsOneWidget);
  });
}
