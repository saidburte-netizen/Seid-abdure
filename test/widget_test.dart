import 'package:bakery_management/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows setup instructions when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BakeryApp()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('SUPABASE_URL and SUPABASE_ANON_KEY'),
      findsOneWidget,
    );
  });
}
