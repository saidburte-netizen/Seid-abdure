import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/screens/pos_screen.dart';

http.Response _json(http.Request request, Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
  request: request,
);

void main() {
  testWidgets('POS accepts fractional quantities for small portions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://pos.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json(request, []);
        if (request.url.path.endsWith('/products')) {
          return _json(request, [
            {
              'id': 'cake-1',
              'name': 'Test cake',
              'sku': 'CAKE-1',
              'price': 10,
              'tax_rate': 0,
            },
          ]);
        }
        if (request.url.path.endsWith('/stores')) {
          return _json(request, [
            {'id': 'store-1', 'name': 'Main store'},
          ]);
        }
        if (request.url.path.endsWith('/cash_accounts')) {
          return _json(request, [
            {'id': 'cash-1', 'name': 'Cash'},
          ]);
        }
        return _json(request, []);
      }),
    );
    final controller = AuthController(client);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    controller
      ..status = AuthStatus.ready
      ..userId = 'cashier'
      ..roleCode = 'cashier'
      ..branches = [
        BranchAccess(
          branchId: 'branch-1',
          branchName: 'Main',
          branchCode: 'MAIN',
          roleCode: 'cashier',
          permissions: const {'*'},
        ),
      ]
      ..selectedBranchId = 'branch-1';
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/pos',
      routes: [
        GoRoute(
          path: '/pos',
          builder: (context, state) =>
              SessionScope(controller: controller, child: const PosScreen()),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Test cake'));
    await tester.pump();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    final quantity = find.byKey(const ValueKey('sale-quantity-cake-1'));
    await tester.enterText(quantity, '0.25');
    await tester.pump();

    expect(tester.widget<TextField>(quantity).controller!.text, '0.25');
    expect(
      find.textContaining('ETB 2.50'),
      findsNWidgets(2),
      reason: '0.25 × ETB 10.00 is shown as both subtotal and total',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    controller.dispose();
  });
}
