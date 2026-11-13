import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/brand/brand.dart';

void main() {
  testWidgets('shows branded configuration screen without backend settings', (
    tester,
  ) async {
    await tester.pumpWidget(const BakeryApp());
    await tester.pumpAndSettle();

    expect(find.text(Brand.appName), findsWidgets);
    expect(find.textContaining('SUPABASE_URL'), findsWidgets);
  });

  test('brand identity is stable', () {
    expect(Brand.appName, 'Brade and Cake House');
    expect(Brand.slogan, 'hani brade and cake');
    expect(Brand.logoAsset, 'assets/branding/logo.png');
  });
}
