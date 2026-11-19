import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

Future<AuthController> _admin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(sampleSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  controller
    ..status = AuthStatus.ready
    ..userId = 'round4-user'
    ..fullName = 'Round 4 Admin'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'test-branch',
        branchName: 'Test branch',
        branchCode: 'TEST',
        roleCode: 'admin',
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'test-branch';
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  AuthController controller,
  String route,
) async {
  await tester.pumpWidget(
    BakeryApp(
      key: ValueKey(route),
      client: controller.client,
      authController: controller,
      signInGateway: FakeSignInGateway(admin: true),
      initialLocation: route,
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Products screen has search, filters and the gold add button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/products');

    expect(find.byTooltip('Add product'), findsOneWidget);
    expect(find.text('Search products'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    expect(find.text('Add product'), findsWidgets);
    expect(find.text('Add item to inventory'), findsOneWidget);
    expect(find.text('Opening stock (optional)'), findsOneWidget);
    expect(find.text('Add photo (optional)'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('existing products expose a direct edit action', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/products');

    final card = find
        .ancestor(of: find.text('Chocolate cake'), matching: find.byType(Card))
        .first;
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Edit')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit product'), findsOneWidget);
    final name = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        )
        .first;
    expect(
      tester.widget<TextFormField>(name).controller!.text,
      'Chocolate cake',
    );
    controller.dispose();
  });

  testWidgets('Stock screen has overview filters and quick actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/stock');

    expect(find.byTooltip('Add item'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Low stock'), findsWidgets);
    expect(find.byIcon(Icons.more_vert), findsWidgets);

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Item type'), findsOneWidget);
    expect(find.text('Minimum stock'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('New sale shows search, category chips and product cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/pos');

    expect(find.text('Search products'), findsOneWidget);
    expect(find.text('Chocolate cake'), findsWidgets);
    expect(find.textContaining('250'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    controller.dispose();
  });

  testWidgets('Rent invoices show status chips, filters and receive payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/rentals');

    final tabBarFinder = find.byType(TabBar);
    final tabController = DefaultTabController.of(tester.element(tabBarFinder));
    tabController.animateTo(3);
    await tester.pumpAndSettle();
    expect(find.text('New invoice'), findsOneWidget);
    expect(find.text('Unpaid'), findsWidgets);
    expect(find.text('Partial'), findsWidgets);
    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('Receive payment'), findsWidgets);
    expect(find.text('Payment history'), findsWidgets);
    controller.dispose();
  });

  testWidgets('Employee form opens with name and no identity demands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/people');

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New Employee'), findsOneWidget);
    expect(find.textContaining('Full name'), findsWidgets);
    controller.dispose();
  });

  testWidgets('Dashboard shows the stock on hand card and view all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _admin(tester);
    await _pump(tester, controller, '/');

    await tester.scrollUntilVisible(
      find.text('Stock on hand'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Stock on hand'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    final allText = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .toList();
    expect(
      allText.any((text) => text.contains('Pieces')),
      isTrue,
      reason: 'Visible text: ${allText.join(' | ')}',
    );
    controller.dispose();
  });
}
