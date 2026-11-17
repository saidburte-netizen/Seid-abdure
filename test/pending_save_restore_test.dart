import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/core/persistence/pending_save_store.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

void _setPortal(AuthController controller) {
  controller
    ..status = AuthStatus.ready
    ..userId = 'test-user'
    ..fullName = 'Test User'
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

Future<AuthController> _controller(WidgetTester tester) async {
  final controller = AuthController(sampleSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  _setPortal(controller);
  return controller;
}

void main() {
  testWidgets('resume keeps an open dialog and its typed values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await _controller(tester);
    await tester.pumpWidget(
      BakeryApp(
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/rentals',
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New Property'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('New Property'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('process death restores the screen and says it was not saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PendingSaveStore.instance.begin(
      route: '/rentals',
      module: 'Rentals',
      target: 'properties',
    );
    final controller = await _controller(tester);
    await tester.pumpWidget(
      BakeryApp(
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/',
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Your previous entry was not saved. Please enter it again.'),
      findsWidgets,
    );
    expect(await PendingSaveStore.instance.read(), isNull);
    controller.dispose();
  });
}
