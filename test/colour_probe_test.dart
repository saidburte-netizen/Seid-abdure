import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

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
  '/access-denied',
];

const _authRoutes = [
  '/sign-in',
  '/loading',
  '/profile-missing',
  '/branch-setup',
  '/auth-error',
];

void main() {
  for (final route in _routes) {
    testWidgets('probe $route', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await _createController(tester);
      _setAdmin(controller);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: BakeryApp(
            client: controller.client,
            authController: controller,
            initialLocation: route,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      var green = 0;
      var total = 0;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        for (var i = 0; i < data!.lengthInBytes; i += 4) {
          final r = data.getUint8(i);
          final g = data.getUint8(i + 1);
          final b = data.getUint8(i + 2);
          final a = data.getUint8(i + 3);
          if (a < 8) continue;
          total++;
          if (g > r * 1.18 && g > b * 1.12 && g > 25) green++;
        }
        image.dispose();
      });
      final share = green * 100 / total;
      // ignore: avoid_print
      print(
        'COLOR | ${route.padRight(30)} | ${share.toStringAsFixed(1).padLeft(5)}% | '
        '${share >= 52 && share <= 68 ? 'PASS' : 'FAIL'} |',
      );
      expect(
        share,
        inInclusiveRange(52.0, 68.0),
        reason: 'Green share for $route must stay between 52% and 68%.',
      );
    });
  }

  for (final route in _authRoutes) {
    testWidgets('probe auth $route', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await _createController(tester);
      switch (route) {
        case '/sign-in':
          controller.status = AuthStatus.signedOut;
        case '/loading':
          controller.status = AuthStatus.loading;
        case '/profile-missing':
          controller.status = AuthStatus.needsMembership;
        case '/branch-setup':
          controller
            ..status = AuthStatus.ready
            ..roleCode = 'admin'
            ..branches = const []
            ..selectedBranchId = null;
        case '/auth-error':
          controller.status = AuthStatus.error;
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: BakeryApp(
            client: controller.client,
            authController: controller,
            initialLocation: route,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      var green = 0;
      var total = 0;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        for (var i = 0; i < data!.lengthInBytes; i += 4) {
          final r = data.getUint8(i);
          final g = data.getUint8(i + 1);
          final b = data.getUint8(i + 2);
          final a = data.getUint8(i + 3);
          if (a < 8) continue;
          total++;
          if (g > r * 1.18 && g > b * 1.12 && g > 25) green++;
        }
        image.dispose();
      });
      final share = green * 100 / total;
      // ignore: avoid_print
      print(
        'COLOR | ${route.padRight(30)} | ${share.toStringAsFixed(1).padLeft(5)}% | '
        '${share >= 52 && share <= 68 ? 'PASS' : 'FAIL'} |',
      );
      expect(
        share,
        inInclusiveRange(52.0, 68.0),
        reason: 'Green share for $route must stay between 52% and 68%.',
      );
    });
  }
}

Future<AuthController> _createController(WidgetTester tester) async {
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
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  final controller = AuthController(client);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return controller;
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
}
