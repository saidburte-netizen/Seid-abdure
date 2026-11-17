import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

/// Writes real 360x800 PNGs to `build/ui_screenshots/`.
///
/// Every file below is captured from a running widget after an assertion that
/// the requested content is actually on screen. CI fails when any of them is
/// missing, so the uploaded artifact is proof rather than a decorative sheet.
const _required = <String>{
  'home-grid',
  'products-list',
  'add-product-form',
  'new-sale',
  'stock',
  'dashboard-stock-card',
  'rentals-invoices',
  'receive-payment-form',
  'hr-employee-form',
  'cash-account-form',
};

const _screens = <String, String>{
  '/': 'home-dashboard',
  '/pos': 'new-sale',
  '/sales': 'sales',
  '/inventory': 'inventory',
  '/cash': 'cash',
  '/products': 'products',
  '/stock': 'stock',
  '/rentals': 'rentals',
  '/people': 'people-hr',
  '/payroll': 'payroll',
  '/settings': 'settings',
};

void main() {
  testWidgets('write required UI screenshots at 360x800 light English', (
    tester,
  ) async {
    final out = Directory('build/ui_screenshots')..createSync(recursive: true);
    for (final file in out.listSync()) {
      if (file is File && file.path.endsWith('.png')) file.deleteSync();
    }

    final controller = await _controller(tester);
    _setAdmin(controller);

    // Home grid must visibly include Products and Stock tiles.
    await _pump(tester, controller, '/');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    await _capture(tester, out, 'home-grid');

    // Dashboard Stock on hand card.
    await _pump(tester, controller, '/');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -340));
    await tester.pumpAndSettle();
    expect(find.text('Stock on hand'), findsOneWidget);
    await _capture(tester, out, 'dashboard-stock-card');

    // Products list with the gold Add product button.
    await _pump(tester, controller, '/products');
    expect(find.text('Add product'), findsOneWidget);
    await _capture(tester, out, 'products-list');

    // Add product form.
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    expect(find.text('Add product'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _capture(tester, out, 'add-product-form');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // New sale with a product visible.
    await _pump(tester, controller, '/pos');
    expect(find.text('Chocolate cake'), findsWidgets);
    await _capture(tester, out, 'new-sale');

    // Stock screen with item names and amounts.
    await _pump(tester, controller, '/stock');
    expect(find.text('Chocolate cake'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
    await _capture(tester, out, 'stock');

    // Rentals invoices with Receive payment on the invoice row.
    await _pump(tester, controller, '/rentals');
    await _setTab(tester, 3);
    final payFinder = find.text('Receive payment').first;
    final payScrollable = find
        .ancestor(of: payFinder, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(payFinder, 200, scrollable: payScrollable);
    await tester.pumpAndSettle();
    expect(find.text('Rent invoices'), findsWidgets);
    expect(find.text('Receive payment'), findsWidgets);
    await _capture(tester, out, 'rentals-invoices');

    // Receive payment form.
    final pay = find.text('Receive payment').first;
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();
    expect(find.text('Receive payment'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _capture(tester, out, 'receive-payment-form');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // HR employee form with the name-only minimum fields.
    await _pump(tester, controller, '/people');
    await tester.tap(find.byTooltip('Add').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Full name'), findsWidgets);
    await _capture(tester, out, 'hr-employee-form');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Cash account form on the Accounts tab.
    await _pump(tester, controller, '/cash');
    await _setTab(tester, 1);
    await tester.tap(find.byTooltip('Add').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await _capture(tester, out, 'cash-account-form');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Keep the wider set of context screenshots used by reviewers.
    for (final entry in _screens.entries) {
      if (_required.contains(entry.value)) continue;
      await _pump(tester, controller, entry.key);
      await _capture(tester, out, entry.value);
    }
    await _pump(tester, controller, '/cash');
    for (var i = 0; i < 4; i++) {
      await _setTab(tester, i);
      await _capture(tester, out, 'cash-tab-${i + 1}');
    }

    for (final name in _required) {
      expect(
        File('${out.path}/$name.png').existsSync(),
        isTrue,
        reason: 'Required screenshot $name.png is missing',
      );
    }
    final names =
        out
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.png'))
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    for (final name in names) {
      // ignore: avoid_print
      print('SCREENSHOT | $name');
    }
    // ignore: avoid_print
    print('SCREENSHOT | wrote ${names.length} files to ${out.path}');
    controller.dispose();
  });
}

Future<void> _setTab(WidgetTester tester, int index) async {
  final bar = find.byType(TabBar).first;
  final controller = DefaultTabController.of(tester.element(bar));
  controller.index = index;
  await tester.pumpAndSettle();
}

Future<AuthController> _controller(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    (call) async => null,
  );
  final controller = AuthController(sampleSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  AuthController controller,
  String route,
) async {
  await controller.setLocale('en');
  await controller.setThemeMode(ThemeMode.light);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('capture'),
      child: BakeryApp(
        key: ValueKey(route),
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: route,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _capture(WidgetTester tester, Directory out, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    File('${out.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
  });
}

void _setAdmin(AuthController controller) {
  controller
    ..status = AuthStatus.ready
    ..userId = 'test-user'
    ..userEmail = 'admin@example.com'
    ..fullName = 'Test Admin'
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
}
