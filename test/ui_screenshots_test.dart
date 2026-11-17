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
/// These are generated on every test run so CI can upload them as the
/// `ui-screenshots` artifact. They are not golden comparisons: a design change
/// must not fail the build just because a pixel moved, but a reviewer can still
/// see every main screen.
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
  testWidgets('write UI screenshots at 360x800 light English', (tester) async {
    final out = Directory('build/ui_screenshots')..createSync(recursive: true);
    final controller = await _controller(tester);
    _setAdmin(controller);

    for (final entry in _screens.entries) {
      await _pump(tester, controller, entry.key);
      await _capture(tester, out, entry.value);
    }

    // Cash has several tabs; capture each one.
    await _pump(tester, controller, '/cash');
    final tabs = find.byType(TabBarView);
    if (tabs.evaluate().isNotEmpty) {
      final tabController = DefaultTabController.of(tester.element(tabs.first));
      for (var i = 0; i < tabController.length; i++) {
        tabController.animateTo(i);
        await tester.pump(const Duration(milliseconds: 350));
        await _capture(tester, out, 'cash-tab-${i + 1}');
      }
    } else {
      await _capture(tester, out, 'cash');
    }

    // The Customers list lives in the last Sales tab.
    await _pump(tester, controller, '/sales');
    final salesTabs = find.byType(TabBarView);
    if (salesTabs.evaluate().isNotEmpty) {
      final tabController = DefaultTabController.of(
        tester.element(salesTabs.first),
      );
      tabController.animateTo(tabController.length - 1);
      await tester.pump(const Duration(milliseconds: 350));
      await _capture(tester, out, 'customers-list');
    }

    // Rentals invoices and the prominent Receive payment form.
    await _pump(tester, controller, '/rentals');
    final rentalsTabs = find.byType(TabBarView);
    if (rentalsTabs.evaluate().isNotEmpty) {
      final rentalsTabController = DefaultTabController.of(
        tester.element(rentalsTabs.first),
      );
      rentalsTabController.animateTo(3);
      await tester.pumpAndSettle();
      await _capture(tester, out, 'rentals-invoices');
      final pay = find.text('Receive payment');
      if (pay.evaluate().isNotEmpty) {
        await tester.ensureVisible(pay.first);
        await tester.tap(pay.first);
        await tester.pumpAndSettle();
        await _capture(tester, out, 'rentals-payment-form');
        final cancel = find.text('Cancel');
        if (cancel.evaluate().isNotEmpty) {
          await tester.tap(cancel.first);
          await tester.pumpAndSettle();
        }
      }
    }

    // HR employee form with the minimum name-only fields.
    await _pump(tester, controller, '/people');
    final hrAdd = find.byTooltip('Add');
    if (hrAdd.evaluate().isNotEmpty) {
      await tester.tap(hrAdd.first);
      await tester.pump(const Duration(milliseconds: 450));
      await _capture(tester, out, 'hr-employee-form');
    }

    // One add-record form, opened from the first writable list screen that
    // exposes the gold Add action.
    var capturedForm = false;
    for (final route in const [
      '/people',
      '/rentals',
      '/payroll',
      '/credit',
      '/production',
      '/cash',
    ]) {
      await _pump(tester, controller, route);
      final add = find.byTooltip('Add');
      if (add.evaluate().isEmpty) continue;
      await tester.tap(add.first);
      await tester.pump(const Duration(milliseconds: 450));
      await _capture(tester, out, 'add-record-form');
      capturedForm = true;
      break;
    }
    if (!capturedForm) {
      // ignore: avoid_print
      print('SCREENSHOT | add button not found on any writable screen');
    }

    controller.dispose();
    // ignore: avoid_print
    print('SCREENSHOT | wrote ${out.listSync().length} files to ${out.path}');
  });
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
  // ignore: avoid_print
  print('SCREENSHOT | $name.png');
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
