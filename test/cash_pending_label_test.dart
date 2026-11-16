import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

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
        permissions: const {
          'cash.view',
          'cash.manage',
          'reports.view',
          'sales.view',
          'inventory.view',
        },
      ),
    ]
    ..selectedBranchId = 'test-branch';
}

void main() {
  testWidgets('pending cash rows are labelled and explained', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = sampleSupabaseClient();
    final controller = AuthController(client);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    _setPortal(controller);

    await tester.pumpWidget(
      BakeryApp(
        client: client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/cash',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsWidgets);
    expect(
      find.text(
        'Cash balance includes approved entries. Pending entries wait for approval.',
      ),
      findsOneWidget,
    );
    controller.dispose();
  });
}
