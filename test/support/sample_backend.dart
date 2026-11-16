import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase client that answers every request locally with believable rows.
///
/// Layout and screenshot tests need real list cards, not an empty state, but
/// they must never reach the network. This client returns three rows for any
/// relation and a populated [v_dashboard_kpis] row.
SupabaseClient sampleSupabaseClient() {
  return SupabaseClient(
    'https://sample.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final accept = request.headers['accept'] ?? '';
      if (request.method == 'POST') {
        return _json('[]', request);
      }
      if (path.endsWith('/rpc/fn_generate_alerts')) {
        return _json('null', request);
      }
      if (path.contains('v_dashboard_kpis')) {
        final row = {
          'today_sales': 12500,
          'cash_balance': 48350,
          'low_stock_items': 4,
          'overdue_receivables': 2300,
          'rent_due': 8000,
          'staff_present_today': 12,
        };
        return _json(
          accept.contains('pgrst.object') ? jsonEncode(row) : jsonEncode([row]),
          request,
        );
      }
      if (request.method != 'GET') {
        return _json('[]', request);
      }
      final rows = _sampleRows();
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
    'unit_price': 220,
    'cost_price': 160,
    'opening_balance': 800,
    'due_date': '2026-11-20',
    'rent_due': 6500,
    'sale_date': '2026-11-15',
    'created_at': '2026-11-02T10:00:00Z',
    'branch_id': 'test-branch',
    'period_month': '2026-10-01',
  },
  {
    'id': '00000000-0000-0000-0000-000000000003',
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
