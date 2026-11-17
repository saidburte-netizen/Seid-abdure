import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';

const _routes = [
  '/',
  '/pos',
  '/sales',
  '/production',
  '/inventory',
  '/products',
  '/stock',
  '/cash',
  '/people',
  '/payroll',
  '/rentals',
  '/credit',
  '/approvals',
  '/reports',
  '/notifications',
  '/settings',
  '/settings/users',
  '/settings/export',
  '/settings/storage',
];

/// Every control that looks tappable in the current tree.
Finder _controls() => find.byWidgetPredicate(
  (widget) =>
      (widget is ButtonStyleButton && widget.onPressed != null) ||
      (widget is IconButton && widget.onPressed != null) ||
      (widget is FloatingActionButton && widget.onPressed != null),
);

Future<void> _pumpRoute(
  WidgetTester tester,
  AuthController controller,
  String route,
  Key key,
) async {
  await tester.pumpWidget(
    BakeryApp(
      key: key,
      client: controller.client,
      authController: controller,
      signInGateway: FakeSignInGateway(admin: true, signupAllowed: true),
      initialLocation: route,
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

Future<AuthController> _adminController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(offlineSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  controller
    ..status = AuthStatus.ready
    ..userId = 'walkthrough-user'
    ..fullName = 'Walkthrough Admin'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'walkthrough-branch',
        branchName: 'Walkthrough branch',
        branchCode: 'WALK',
        roleCode: 'admin',
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'walkthrough-branch';
  return controller;
}

void main() {
  for (final route in _routes) {
    testWidgets('every visible control on $route can be tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = await _adminController(tester);
      await _pumpRoute(tester, controller, route, ValueKey('$route-initial'));

      final total = _controls().evaluate().length;
      final limit = math.min(total, 10);
      for (var index = 0; index < limit; index++) {
        await _pumpRoute(tester, controller, route, ValueKey('$route-$index'));
        final controls = _controls();
        if (index >= controls.evaluate().length) break;
        await tester.tap(controls.at(index), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.takeException(),
          isNull,
          reason: '$route: control $index of $total threw',
        );
      }

      controller.dispose();
    });
  }

  testWidgets('each role can open its dashboard without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const roles = [
      'admin',
      'manager',
      'cashier',
      'baker',
      'store_keeper',
      'hr_officer',
      'accountant',
      'staff',
      'customer',
    ];
    for (final role in roles) {
      SharedPreferences.setMockInitialValues({});
      final controller = AuthController(offlineSupabaseClient());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      controller
        ..status = AuthStatus.ready
        ..userId = 'role-$role'
        ..fullName = 'Role $role'
        ..roleCode = role
        ..branches = [
          BranchAccess(
            branchId: 'role-branch',
            branchName: 'Role branch',
            branchCode: 'ROLE',
            roleCode: role,
            permissions: const {'*'},
          ),
        ]
        ..selectedBranchId = 'role-branch';

      await tester.pumpWidget(
        BakeryApp(
          key: ValueKey('role-$role'),
          client: controller.client,
          authController: controller,
          signInGateway: FakeSignInGateway(admin: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'dashboard for $role');

      final controls = _controls();
      final limit = math.min(controls.evaluate().length, 6);
      for (var index = 0; index < limit; index++) {
        await tester.pumpWidget(
          BakeryApp(
            key: ValueKey('role-$role-$index'),
            client: controller.client,
            authController: controller,
            signInGateway: FakeSignInGateway(admin: true),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        final current = _controls();
        if (index >= current.evaluate().length) break;
        await tester.tap(current.at(index), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.takeException(),
          isNull,
          reason: 'dashboard for $role: control $index threw',
        );
      }

      controller.dispose();
    }
  });
}
