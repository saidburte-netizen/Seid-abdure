import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

const _routes = [
  '/',
  '/settings',
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
      // ignore: avoid_print
      print('COLOR $route ${(green * 100 / total).toStringAsFixed(1)}%');
    });
  }
}

Future<AuthController> _createController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
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
