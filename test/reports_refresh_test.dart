import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/core/events/data_revision.dart';

import 'support/fake_backend.dart';

SupabaseClient _changingKpiClient(num Function() todaySales) {
  return SupabaseClient(
    'https://offline.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final accept = request.headers['accept'] ?? '';
      http.Response json(String body) => http.Response(
        body,
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      );

      if (path.endsWith('/rpc/fn_generate_alerts')) return json('null');
      if (request.method != 'GET') return json('[]');
      if (path.contains('v_dashboard_kpis')) {
        final row = {
          'today_sales': todaySales(),
          'cash_balance': 48350,
          'low_stock_items': 4,
          'overdue_receivables': 2300,
          'rent_due': 8000,
          'staff_present_today': 12,
        };
        return json(
          accept.contains('pgrst.object') ? jsonEncode(row) : jsonEncode([row]),
        );
      }
      return json('[]');
    }),
  );
}

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
          'reports.view',
          'cash.view',
          'sales.view',
          'inventory.view',
          'settings.manage',
        },
      ),
    ]
    ..selectedBranchId = 'test-branch';
}

void main() {
  testWidgets('dashboard shows and refreshes all live business KPIs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var todaySales = 111.0;
    final client = _changingKpiClient(() => todaySales);
    final controller = AuthController(client);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    _setPortal(controller);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      BakeryApp(
        client: client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Today's sales"), findsOneWidget);
    expect(find.text('Cash balance'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Rent due'), findsOneWidget);
    expect(find.text('Staff present'), findsOneWidget);
    expect(find.textContaining('111.00'), findsOneWidget);

    todaySales = 222.0;
    DataRevision.bump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('222.00'), findsOneWidget);
    expect(find.textContaining('111.00'), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('a report reloads and changes after DataRevision.bump', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var todaySales = 111.0;
    final client = _changingKpiClient(() => todaySales);
    final controller = AuthController(client);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    _setPortal(controller);

    await tester.pumpWidget(
      BakeryApp(
        client: client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/reports',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('111.00'), findsWidgets);

    todaySales = 222.0;
    DataRevision.bump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('222.00'), findsWidgets);
    expect(find.textContaining('111.00'), findsNothing);
    controller.dispose();
  });
}
