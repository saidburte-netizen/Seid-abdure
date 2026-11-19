import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';

SupabaseClient _reportsClient({void Function(Uri)? onSalesRequest}) {
  return SupabaseClient(
    'https://offline.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final accept = request.headers['accept'] ?? '';
      http.Response json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      );

      if (request.method != 'GET') return json(const []);
      if (path.endsWith('/v_dashboard_kpis') ||
          path.endsWith('/v_dashboard_overview')) {
        final row = {
          'today_sales': 1200,
          'cash_balance': 5000,
          'low_stock_items': 1,
          'overdue_receivables': 0,
          'rent_due': 600,
          'rent_collected': 400,
          'staff_present_today': 4,
          'payables_due': 200,
          'stock_value': 2160,
        };
        return json(accept.contains('pgrst.object') ? row : [row]);
      }
      if (path.endsWith('/v_daily_sales')) {
        return json([
          {
            'sale_day': '2026-11-16',
            'sales_count': 1,
            'total_sales': 1200,
            'paid': 1000,
          },
        ]);
      }
      if (path.endsWith('/v_product_sales')) {
        return json([
          {
            'product_name': 'Chocolate cake',
            'quantity_sold': 4,
            'revenue': 1200,
          },
        ]);
      }
      if (path.endsWith('/v_stock_valuation')) {
        return json([
          {
            'store_name': 'Shop',
            'item_name': 'Chocolate cake',
            'quantity': 12,
            'stock_value': 2160,
          },
        ]);
      }
      if (path.endsWith('/v_cash_account_balances')) {
        return json([
          {'name': 'Cash drawer', 'account_type': 'cash', 'balance': 5000},
        ]);
      }
      if (path.endsWith('/v_rent_status')) {
        return json([
          {
            'invoice_no': 'RIN-001',
            'tenant_name': 'Abebe Kebede',
            'property_name': 'Shop',
            'amount': 1000,
            'paid_amount': 400,
            'balance': 600,
            'due_date': '2026-11-25',
            'status': 'partial',
          },
        ]);
      }
      if (path.endsWith('/v_expense_summary')) {
        return json([
          {'month': '2026-11-01', 'category': 'Utilities', 'total': 300},
        ]);
      }
      if (path.endsWith('/v_customer_balances')) {
        return json([
          {'full_name': 'Abebe Kebede', 'balance_owed': 600},
        ]);
      }
      if (path.endsWith('/v_supplier_balances')) {
        return json([
          {'name': 'Sugar supplier', 'balance_we_owe': 200},
        ]);
      }
      if (path.endsWith('/v_payroll_summary')) {
        return json([
          {
            'period_month': '2026-11-01',
            'employees': 3,
            'gross': 7000,
            'net': 5000,
          },
        ]);
      }
      if (path.endsWith('/stock_movements')) {
        return json([
          {
            'id': 'movement-1',
            'item_id': 'item-1',
            'store_id': 'store-1',
            'movement_type': 'purchase',
            'quantity': 5,
            'created_at': '2026-11-16T10:00:00Z',
            'reference_type': 'purchase',
            'reference_id': 'po-1',
            'notes': '',
          },
        ]);
      }
      if (path.endsWith('/items')) {
        return json([
          {
            'id': 'item-1',
            'name': 'Chocolate cake',
            'item_type': 'finished_good',
            'unit_id': 'unit-1',
          },
        ]);
      }
      if (path.endsWith('/stores')) {
        return json([
          {'id': 'store-1', 'name': 'Shop'},
        ]);
      }
      if (path.endsWith('/units')) {
        return json([
          {'id': 'unit-1', 'name': 'Pieces', 'code': 'pcs'},
        ]);
      }
      if (path.endsWith('/sales')) {
        onSalesRequest?.call(request.url);
        return json([
          {
            'id': 'sale-1',
            'receipt_no': 'RCP-001',
            'sale_date': '2026-11-16',
            'total_amount': 1200,
            'paid_amount': 1000,
            'payment_status': 'partial',
            'status': 'completed',
          },
        ]);
      }
      if (path.endsWith('/rent_invoices')) {
        return json([
          {
            'id': 'invoice-1',
            'invoice_no': 'RIN-001',
            'tenant_id': 'tenant-1',
            'property_id': 'property-1',
            'amount': 1000,
            'paid_amount': 400,
            'due_date': '2026-11-25',
            'status': 'partial',
          },
        ]);
      }
      if (path.endsWith('/rent_payments')) {
        return json([
          {
            'id': 'payment-1',
            'invoice_id': 'invoice-1',
            'payment_date': '2026-11-16',
            'amount': 400,
            'method': 'cash',
            'reference': 'REF-001',
          },
        ]);
      }
      if (path.endsWith('/leases')) {
        return json([
          {
            'id': 'lease-1',
            'lease_no': 'L-001',
            'property_id': 'property-1',
            'tenant_id': 'tenant-1',
            'start_date': '2026-01-01',
            'end_date': '2026-12-31',
            'rent_amount': 1000,
            'billing_frequency': 'monthly',
            'status': 'active',
          },
        ]);
      }
      if (path.endsWith('/tenants')) {
        return json([
          {'id': 'tenant-1', 'full_name': 'Abebe Kebede'},
        ]);
      }
      if (path.endsWith('/properties')) {
        return json([
          {'id': 'property-1', 'name': 'Shop', 'code': 'SHOP'},
        ]);
      }
      return json(const []);
    }),
  );
}

void main() {
  testWidgets('report buttons open full, stock, sales and rent data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final salesQueries = <Uri>[];
    final client = _reportsClient(onSalesRequest: salesQueries.add);
    final controller = AuthController(client);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    controller
      ..status = AuthStatus.ready
      ..userId = 'reports-user'
      ..fullName = 'Reports User'
      ..roleCode = 'admin'
      ..branches = [
        BranchAccess(
          branchId: 'test-branch',
          branchName: 'Test branch',
          branchCode: 'TEST',
          roleCode: 'admin',
          permissions: const {'reports.view', 'pos.use'},
        ),
      ]
      ..selectedBranchId = 'test-branch';

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BakeryApp(
        client: client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/reports',
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Full report'), findsOneWidget);
    expect(find.text('Daily sales'), findsOneWidget);
    expect(find.text('Chocolate cake'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Stock report'));
    await tester.pumpAndSettle();
    expect(find.text('Stock movements'), findsOneWidget);
    expect(find.text('Chocolate cake'), findsWidgets);
    expect(find.text('Purchase'), findsWidgets);
    expect(find.text('Shop'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sales report'));
    await tester.pumpAndSettle();
    expect(find.text('Record sale'), findsOneWidget);
    expect(find.text('RCP-001'), findsWidgets);
    expect(find.text('Total sales'), findsWidgets);

    // Timestamped same-day sales must stay inside the selected business day.
    final saleFilters = salesQueries.expand(
      (uri) => uri.queryParametersAll['sale_date'] ?? const <String>[],
    );
    expect(
      saleFilters.any((filter) => filter.startsWith('lt.')),
      isTrue,
      reason: 'Sales report must use an exclusive end of the selected day',
    );
    expect(
      saleFilters.any((filter) => filter.startsWith('lte.')),
      isFalse,
      reason: 'An inclusive date-only end hides sales stamped later that day',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rent report'));
    await tester.pumpAndSettle();
    expect(find.text('Next rent due'), findsWidgets);
    expect(find.text('Rent invoices'), findsWidgets);
    expect(find.text('RIN-001'), findsWidgets);
    expect(find.text('Rent payments'), findsWidgets);
    expect(find.text('REF-001'), findsWidgets);
    expect(find.text('Leases'), findsWidgets);
    expect(find.text('L-001'), findsWidgets);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
