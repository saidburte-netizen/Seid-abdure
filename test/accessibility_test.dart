import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';

/// Routes that must remain usable and overflow-free at 200% text scale.
const _routes = [
  '/',
  '/pos',
  '/sales',
  '/production',
  '/inventory',
  '/cash',
  '/people',
  '/payroll',
  '/rentals',
  '/credit',
  '/approvals',
  '/reports',
  '/notifications',
  '/settings',
  '/settings/profile',
  '/settings/security',
  '/settings/business',
  '/settings/branches',
  '/settings/accounts',
  '/settings/users',
  '/settings/role-permissions',
  '/settings/master-data',
  '/settings/audit',
  '/settings/export',
  '/settings/storage',
  '/settings/branding',
  '/settings/about',
  '/settings/help',
  '/settings/privacy',
  '/module/production',
  '/module/sales',
  '/module/pos',
  '/module/inventory',
  '/module/cash',
  '/module/people',
  '/module/payroll',
  '/module/rentals',
  '/module/credit',
  '/module/approvals',
  '/module/reports',
  '/module/notifications',
  '/module/settings',
  '/module/audit',
  '/module/media',
  '/module/unknown',
  '/sign-in',
  '/loading',
  '/profile-missing',
  '/branch-setup',
  '/auth-error',
  '/access-denied',
];

void main() {
  for (final route in _routes) {
    testWidgets('200% text scale keeps $route overflow-free', (tester) async {
      final errors = await _pumpRoute(
        tester,
        route,
        textScale: 2.0,
        size: const Size(390, 844),
      );
      expect(
        errors,
        isEmpty,
        reason:
            '$route rendered layout errors at 200% text scale:\n'
            '${errors.join('\n')}',
      );
    });
  }

  for (final route in ['/', '/pos', '/sales']) {
    testWidgets('200% text scale keeps $route overflow-free on a small phone', (
      tester,
    ) async {
      final errors = await _pumpRoute(
        tester,
        route,
        textScale: 2.0,
        size: const Size(320, 568),
      );
      expect(
        errors,
        isEmpty,
        reason:
            '$route rendered layout errors at 200% text scale on 320x568:\n'
            '${errors.join('\n')}',
      );
    });
  }

  for (final locale in const ['am', 'om']) {
    for (final route in ['/', '/pos', '/settings']) {
      testWidgets('$locale keeps $route overflow-free at 200%', (tester) async {
        final errors = await _pumpRoute(
          tester,
          route,
          textScale: 2.0,
          size: const Size(390, 844),
          locale: locale,
        );
        expect(errors, isEmpty, reason: '$locale $route: ${errors.join('\n')}');
      });
    }
  }

  testWidgets('overflow detector catches a real overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            child: Row(children: [SizedBox(width: 300, child: Text('wide'))]),
          ),
        ),
      ),
    );
    final error = tester.takeException();
    expect(
      error,
      isNotNull,
      reason: 'The overflow detector must catch a deliberately broken Row.',
    );
    expect(error.toString(), contains('overflowed'));
  });

  for (final route in ['/', '/pos', '/sales', '/inventory', '/settings']) {
    testWidgets('icon buttons expose labels and 48dp targets on $route', (
      tester,
    ) async {
      await _pumpRoute(tester, route, textScale: 1.0);
      final buttons = find.byType(IconButton);
      for (var i = 0; i < buttons.evaluate().length; i++) {
        final button = buttons.evaluate().elementAt(i).widget as IconButton;
        expect(
          button.tooltip != null ||
              button.icon is Image ||
              (button.icon is Icon &&
                  (button.icon as Icon).semanticLabel != null),
          isTrue,
          reason: 'IconButton $i on $route has no tooltip/semantic label.',
        );
        final size = tester.getSize(buttons.at(i));
        expect(
          size.width,
          greaterThanOrEqualTo(48.0),
          reason: 'IconButton $i on $route is narrower than 48dp.',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'IconButton $i on $route is shorter than 48dp.',
        );
      }
    });
  }
}

Future<List<String>> _pumpRoute(
  WidgetTester tester,
  String route, {
  required double textScale,
  Size size = const Size(390, 844),
  String? locale,
}) async {
  final errors = <String>[];

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues(
    locale == null ? <String, Object>{} : <String, Object>{'locale': locale},
  );
  final controller = AuthController(offlineSupabaseClient());
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
        permissions: const {
          'pos.use',
          'sales.view',
          'production.manage',
          'inventory.view',
          'inventory.manage',
          'cash.view',
          'cash.manage',
          'hr.view',
          'hr.manage',
          'payroll.manage',
          'rentals.manage',
          'credit.manage',
          'expenses.approve',
          'expenses.manage',
          'reports.view',
          'settings.manage',
          'branches.manage',
          'users.manage',
          'audit.view',
          'units.manage',
          'categories.manage',
        },
      ),
    ]
    ..selectedBranchId = 'test-branch';

  await tester.pumpWidget(
    BakeryApp(
      client: controller.client,
      authController: controller,
      signInGateway: FakeSignInGateway(admin: true),
      initialLocation: route,
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
  // Any exception reported through the binding (for example a build error)
  // must fail the test as well.
  final pending = tester.takeException();
  if (pending != null) {
    errors.add(pending.toString());
  }
  return errors;
}
