import 'package:bakery_management/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard displays the bakery title and module links', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BakeryApp()));
    await tester.pumpAndSettle();

    expect(find.text('Bread & Cake Management'), findsOneWidget);
    expect(find.text('Sales & POS'), findsOneWidget);

    await tester.tap(find.text('Sales & POS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not available yet'), findsOneWidget);
  });
}
