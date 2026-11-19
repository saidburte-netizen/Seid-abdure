import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/screens/payroll_screen.dart';
import 'package:brade_and_cake_house/screens/pos_screen.dart';
import 'package:brade_and_cake_house/screens/reports_screen.dart';
import 'package:brade_and_cake_house/screens/stock_screen.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

/// Proves the Nexa-style shortcuts are wired to the real screens.
void main() {
  testWidgets('bottom navigation opens the four daily hubs', (tester) async {
    final controller = await _pump(tester, '/');

    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('New sale'), findsWidgets);
    expect(find.text('Stock'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
    expect(find.text('More'), findsOneWidget);

    await _tapAndSettle(tester, find.byKey(const Key('nav-sell')));
    expect(find.byType(PosScreen), findsOneWidget);

    await _tapAndSettle(tester, find.byKey(const Key('nav-stock')));
    expect(find.byType(StockScreen), findsOneWidget);

    await _tapAndSettle(tester, find.byKey(const Key('nav-reports')));
    expect(find.byType(ReportsScreen), findsOneWidget);

    await _tapAndSettle(tester, find.byKey(const Key('nav-home')));
    expect(find.byKey(const Key('dashboard-scroll')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('dashboard quick actions open the real create and pay screens', (
    tester,
  ) async {
    final controller = await _pump(tester, '/');

    expect(find.text('Quick actions'), findsOneWidget);
    await _tapAndSettle(tester, find.byKey(const Key('quick-new-sale')));
    expect(find.byType(PosScreen), findsOneWidget);

    await _pump(tester, '/', controller: controller);
    await _tapAndSettle(tester, find.byKey(const Key('quick-add-product')));
    expect(find.text('Add product'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);

    await _pump(tester, '/', controller: controller);
    await tester.drag(
      find.byKey(const Key('quick-actions')),
      const Offset(-280, 0),
    );
    await tester.pump();
    await _tapAndSettle(tester, find.byKey(const Key('quick-reports')));
    expect(find.byType(ReportsScreen), findsOneWidget);
    controller.dispose();
  });

  testWidgets('search and All modules reach every permitted screen', (
    tester,
  ) async {
    final controller = await _pump(tester, '/');

    await _tapAndSettle(tester, find.byTooltip('Search pages'));
    expect(find.text('All modules'), findsWidgets);
    await tester.enterText(find.byKey(const Key('module-search')), 'payroll');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('module-payroll')), findsOneWidget);
    await _tapAndSettle(tester, find.byKey(const Key('module-payroll')));
    expect(find.byType(PayrollScreen), findsOneWidget);

    await _pump(tester, '/', controller: controller);
    await _tapAndSettle(tester, find.byKey(const Key('open-all-modules')));
    expect(find.text('All modules'), findsWidgets);
    await tester.enterText(find.byKey(const Key('module-search')), 'rentals');
    await tester.pump(const Duration(milliseconds: 200));
    await _tapAndSettle(tester, find.byKey(const Key('module-rentals')));
    expect(find.text('Rent invoices'), findsWidgets);
    controller.dispose();
  });

  testWidgets('mobile list screens expose the Nexa-style add button', (
    tester,
  ) async {
    final controller = await _pump(tester, '/products');
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _tapAndSettle(tester, find.byType(FloatingActionButton));
    expect(find.byType(AlertDialog), findsOneWidget);

    await _pump(tester, '/stock', controller: controller);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await _tapAndSettle(tester, find.byType(FloatingActionButton));
    expect(find.byType(AlertDialog), findsOneWidget);
    controller.dispose();
  });

  testWidgets('the bottom bar stays off forms and settings detail pages', (
    tester,
  ) async {
    final controller = await _pump(tester, '/products/new');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('app-bottom-nav')), findsNothing);

    await _pump(tester, '/settings/profile', controller: controller);
    expect(find.byKey(const Key('app-bottom-nav')), findsNothing);
    controller.dispose();
  });
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<AuthController> _pump(
  WidgetTester tester,
  String route, {
  AuthController? controller,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final auth = controller ?? AuthController(sampleSupabaseClient());
  if (controller == null) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    auth
      ..status = AuthStatus.ready
      ..userId = 'ease-user'
      ..userEmail = 'admin@example.com'
      ..fullName = 'Ease Admin'
      ..roleCode = 'admin'
      ..branches = [
        BranchAccess(
          branchId: 'ease-branch',
          branchName: 'Ease branch',
          branchCode: 'EASE',
          roleCode: 'admin',
          permissions: const {'*'},
        ),
      ]
      ..selectedBranchId = 'ease-branch';
    await auth.setLocale('en');
  }

  await tester.pumpWidget(
    BakeryApp(
      key: ValueKey('$route-${DateTime.now().microsecondsSinceEpoch}'),
      client: auth.client,
      authController: auth,
      signInGateway: FakeSignInGateway(admin: true),
      initialLocation: route,
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return auth;
}
