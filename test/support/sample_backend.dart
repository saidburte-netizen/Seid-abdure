import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase client that answers every request locally with believable rows.
///
/// Layout and screenshot tests need real list cards, not an empty state, but
/// they must never reach the network. This client returns three rows for any
/// relation and a populated [v_dashboard_kpis] row.
///
/// Pass [onWrite] to script insert/update/RPC responses, for example to prove
/// a form stays open when the database rejects a save.
SupabaseClient sampleSupabaseClient({
  http.Response Function(http.Request request)? onWrite,
  List<Map<String, dynamic>> Function(String path)? rowsFor,
}) {
  return SupabaseClient(
    'https://sample.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final accept = request.headers['accept'] ?? '';
      if (request.method == 'POST') {
        return onWrite?.call(request) ?? _json('[]', request);
      }
      if (path.endsWith('/rpc/fn_generate_alerts')) {
        return _json('null', request);
      }
      if (path.contains('v_dashboard_kpis') ||
          path.contains('v_dashboard_overview')) {
        final row = {
          'today_sales': 12500,
          'cash_balance': 48350,
          'low_stock_items': 4,
          'overdue_receivables': 2300,
          'rent_due': 8000,
          'rent_collected': 5000,
          'staff_present_today': 12,
          'payables_due': 2000,
          'stock_value': 9000,
        };
        return _json(
          accept.contains('pgrst.object') ? jsonEncode(row) : jsonEncode([row]),
          request,
        );
      }
      if (request.method != 'GET') {
        return _json('[]', request);
      }
      final rows = <Map<String, dynamic>>[
        ..._sampleRows(),
        ...(rowsFor?.call(path) ?? const <Map<String, dynamic>>[]),
      ];
      if (accept.contains('pgrst.object')) {
        return _json(jsonEncode(rows.first), request);
      }
      return _json(jsonEncode(rows), request);
    }),
  );
}

http.Response _json(String body, http.Request request) => http.Response(
  body,
  200,
  headers: const {'content-type': 'application/json'},
  request: request,
);

List<Map<String, dynamic>> _sampleRows() => [
  {
    'id': '00000000-0000-0000-0000-000000000001',
    'invoice_no': 'RIN-001',
    'lease_id': 'lease-1',
    'tenant_id': 'tenant-1',
    'property_id': 'property-1',
    'paid_amount': 500,
    'period_start': '2026-11-01',
    'period_end': '2026-11-30',
    'payment_date': '2026-11-10',
    'method': 'cash',
    'reference': 'REF-001',
    'item_id': 'item-1',
    'unit_code': 'pcs',
    'unit_name': 'Pieces',
    'item_type': 'finished_good',
    'is_low': false,
    'image_url': '',
    'code': 'CUS-001',
    'sku': 'CHC-001',
    'full_name': 'Abebe Kebede',
    'name': 'Chocolate cake',
    'title': 'Chocolate cake',
    'description': 'Sample record',
    'phone': '+251 911 000 001',
    'email': 'abebe@example.com',
    'status': 'active',
    'is_active': true,
    'amount': 1250,
    'total_amount': 1250,
    'balance': 500,
    'quantity': 12,
    'min_stock': 5,
    'price': 250,
    'unit_price': 250,
    'cost_price': 180,
    'opening_balance': 1000,
    'due_date': '2026-11-25',
    'rent_due': 8000,
    'sale_date': '2026-11-16',
    'created_at': '2026-11-01T10:00:00Z',
    'branch_id': 'test-branch',
    'period_month': '2026-11-01',
  },
  {
    'id': '00000000-0000-0000-0000-000000000002',
    'invoice_no': 'RIN-002',
    'lease_id': 'lease-2',
    'tenant_id': 'tenant-2',
    'property_id': 'property-2',
    'paid_amount': 0,
    'period_start': '2026-10-01',
    'period_end': '2026-10-31',
    'payment_date': '2026-11-05',
    'method': 'telebirr',
    'reference': 'REF-002',
    'item_id': 'item-2',
    'unit_code': 'kg',
    'unit_name': 'Kilograms',
    'item_type': 'raw_material',
    'is_low': true,
    'image_url': '',
    'code': 'CUS-002',
    'sku': 'VNL-002',
    'full_name': 'Hanna Tesfaye',
    'name': 'Vanilla cake',
    'title': 'Vanilla cake',
    'description': 'Sample record',
    'phone': '+251 911 000 002',
    'email': 'hanna@example.com',
    'status': 'pending',
    'is_active': true,
    'amount': 980,
    'total_amount': 980,
    'balance': 300,
    'quantity': 3,
    'min_stock': 5,
    'price': 220,
    'unit_price': 220,
    'cost_price': 160,
    'opening_balance': 800,
    'due_date': '2026-10-20',
    'rent_due': 6500,
    'sale_date': '2026-11-15',
    'created_at': '2026-11-02T10:00:00Z',
    'branch_id': 'test-branch',
    'period_month': '2026-10-01',
  },
  {
    'id': '00000000-0000-0000-0000-000000000003',
    'invoice_no': 'RIN-003',
    'lease_id': 'lease-3',
    'tenant_id': 'tenant-3',
    'property_id': 'property-3',
    'paid_amount': 450,
    'period_start': '2026-09-01',
    'period_end': '2026-09-30',
    'payment_date': '2026-11-01',
    'method': 'bank',
    'reference': 'REF-003',
    'item_id': 'item-3',
    'unit_code': 'pcs',
    'unit_name': 'Pieces',
    'item_type': 'finished_good',
    'is_low': false,
    'image_url': '',
    'code': 'CUS-003',
    'sku': 'BRD-003',
    'full_name': 'Dawit Bekele',
    'name': 'Sourdough loaf',
    'title': 'Sourdough loaf',
    'description': 'Sample record',
    'phone': '+251 911 000 003',
    'email': 'dawit@example.com',
    'status': 'completed',
    'is_active': true,
    'amount': 450,
    'total_amount': 450,
    'balance': 0,
    'quantity': 28,
    'min_stock': 10,
    'price': 120,
    'unit_price': 120,
    'cost_price': 70,
    'opening_balance': 1200,
    'due_date': '2026-12-01',
    'rent_due': 7200,
    'sale_date': '2026-11-14',
    'created_at': '2026-11-03T10:00:00Z',
    'branch_id': 'test-branch',
    'period_month': '2026-09-01',
  },
];
