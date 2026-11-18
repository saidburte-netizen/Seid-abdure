import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../core/errors/friendly_error.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _reports = {
    'v_dashboard_kpis': 'Executive KPI summary',
    'v_daily_sales': 'Daily sales',
    'v_product_sales': 'Product sales',
    'v_expense_summary': 'Expense summary',
    'v_cash_account_balances': 'Cash account balances',
    'v_low_stock': 'Low stock',
    'v_stock_valuation': 'Stock valuation',
    'v_customer_balances': 'Customer balances',
    'v_supplier_balances': 'Supplier balances',
    'v_receivable_aging': 'Receivable aging',
    'v_payable_aging': 'Payable aging',
    'v_rent_status': 'Rent status',
    'v_payroll_summary': 'Payroll summary',
  };

  static const _customReports = <(String, String, IconData)>[
    ('full', 'Full report', Icons.dashboard_outlined),
    ('stock', 'Stock report', Icons.warehouse_outlined),
    ('sales', 'Sales report', Icons.point_of_sale_outlined),
    ('rent', 'Rent report', Icons.apartment_outlined),
  ];

  String _selected = 'full';
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();
  int _refreshSeed = 0;

  @override
  void initState() {
    super.initState();
    DataRevision.notifier.addListener(_reloadFromRevision);
  }

  @override
  void dispose() {
    DataRevision.notifier.removeListener(_reloadFromRevision);
    super.dispose();
  }

  void _reloadFromRevision() {
    if (!mounted) return;
    setState(() => _refreshSeed++);
  }

  bool get _isCustom => _customReports.any((report) => report.$1 == _selected);

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = picked;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'Reports & analytics'),
      kpiKinds: const [
        KpiKind.cashBalance,
        KpiKind.todaySales,
        KpiKind.lowStock,
      ],
      body: Column(
        children: [
          _toolbar(context),
          Expanded(child: _body(context, session)),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final report in _customReports)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(report.$3, size: 18),
                    label: Text(uiText(context, report.$2)),
                    selected: _selected == report.$1,
                    onSelected: (_) => setState(() => _selected = report.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _reports.containsKey(_selected)
                    ? _selected
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: uiText(context, 'More report views'),
                  prefixIcon: const Icon(Icons.analytics_outlined),
                  isDense: true,
                ),
                items: [
                  for (final entry in _reports.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selected = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: uiText(context, 'Refresh'),
              onPressed: () => setState(() => _refreshSeed++),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_isCustom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(from: true),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    '${uiText(context, 'From')}: ${formatDate(_from)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(from: false),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text('${uiText(context, 'To')}: ${formatDate(_to)}'),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _body(BuildContext context, AuthController session) {
    final key = ValueKey(
      '$_selected-${dateOnly(_from)}-${dateOnly(_to)}-$_refreshSeed',
    );
    return switch (_selected) {
      'full' => _FullReportView(key: key, session: session),
      'stock' => _StockReportView(
        key: key,
        session: session,
        from: _from,
        to: _to,
      ),
      'sales' => _SalesReportView(
        key: key,
        session: session,
        from: _from,
        to: _to,
      ),
      'rent' => _RentReportView(
        key: key,
        session: session,
        from: _from,
        to: _to,
      ),
      _ => CrudTab(
        key: key,
        spec: specFor(_selected),
        readPermission: 'reports.view',
        alwaysReadOnly: true,
      ),
    };
  }
}

class _FullReportData {
  const _FullReportData({
    required this.summary,
    required this.dailySales,
    required this.productSales,
    required this.stock,
    required this.cashflow,
    required this.rent,
    required this.expenses,
    required this.customers,
    required this.suppliers,
    required this.payroll,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> dailySales;
  final List<Map<String, dynamic>> productSales;
  final List<Map<String, dynamic>> stock;
  final List<Map<String, dynamic>> cashflow;
  final List<Map<String, dynamic>> rent;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> payroll;
}

class _FullReportView extends StatefulWidget {
  const _FullReportView({super.key, required this.session});

  final AuthController session;

  @override
  State<_FullReportView> createState() => _FullReportViewState();
}

class _FullReportViewState extends State<_FullReportView> {
  late Future<_FullReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _rows(
    String view, {
    String? order,
    int limit = 10,
  }) async {
    try {
      final query = widget.session.client.from(view).select();
      final data = order == null
          ? await query.limit(limit)
          : await query.order(order, ascending: false).limit(limit);
      return [for (final row in data) Map<String, dynamic>.from(row as Map)];
    } catch (_) {
      return const [];
    }
  }

  Future<_FullReportData> _load() async {
    Map<String, dynamic> summary = const {};
    try {
      final row = await widget.session.client
          .from('v_dashboard_overview')
          .select()
          .maybeSingle();
      if (row != null) summary = Map<String, dynamic>.from(row);
    } catch (_) {
      // The report still shows the sections that are available.
    }
    final results = await Future.wait([
      _rows('v_daily_sales', order: 'day'),
      _rows('v_product_sales'),
      _rows('v_stock_overview', order: 'is_low'),
      _rows('v_cashflow_daily', order: 'day'),
      _rows('v_rent_status'),
      _rows('v_expense_summary'),
      _rows('v_customer_balances'),
      _rows('v_supplier_balances'),
      _rows('v_payroll_summary'),
    ]);
    return _FullReportData(
      summary: summary,
      dailySales: results[0],
      productSales: results[1],
      stock: results[2],
      cashflow: results[3],
      rent: results[4],
      expenses: results[5],
      customers: results[6],
      suppliers: results[7],
      payroll: results[8],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_FullReportData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ErrorView(
          message: friendlyMessage(snapshot.error!),
          onRetry: () async {
            setState(() {
              _future = _load();
            });
          },
        );
      }
      final data = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SummaryGrid(
            summary: data.summary,
            labels: const {
              'today_sales': "Today's sales",
              'cash_balance': 'Cash balance',
              'low_stock_items': 'Low stock',
              'rent_due': 'Rent due',
              'rent_collected': 'Rent collected',
              'payables_due': 'Payables',
              'overdue_receivables': 'Overdue receivables',
              'stock_value': 'Stock value',
              'staff_present_today': 'Staff present',
            },
          ),
          _ReportTable(
            title: 'Daily sales',
            rows: data.dailySales,
            maxRows: 10,
          ),
          _ReportTable(
            title: 'Product sales',
            rows: data.productSales,
            maxRows: 10,
          ),
          _ReportTable(title: 'Stock on hand', rows: data.stock, maxRows: 10),
          _ReportTable(title: 'Cashflow', rows: data.cashflow, maxRows: 10),
          _ReportTable(title: 'Rent status', rows: data.rent, maxRows: 10),
          _ReportTable(
            title: 'Expense summary',
            rows: data.expenses,
            maxRows: 10,
          ),
          _ReportTable(
            title: 'Customer balances',
            rows: data.customers,
            maxRows: 10,
          ),
          _ReportTable(
            title: 'Supplier balances',
            rows: data.suppliers,
            maxRows: 10,
          ),
          _ReportTable(
            title: 'Payroll summary',
            rows: data.payroll,
            maxRows: 10,
          ),
        ],
      );
    },
  );
}

class _StockReportData {
  const _StockReportData({
    required this.rows,
    required this.totalIn,
    required this.totalOut,
  });

  final List<Map<String, dynamic>> rows;
  final num totalIn;
  final num totalOut;
}

class _StockReportView extends StatefulWidget {
  const _StockReportView({
    super.key,
    required this.session,
    required this.from,
    required this.to,
  });

  final AuthController session;
  final DateTime from;
  final DateTime to;

  @override
  State<_StockReportView> createState() => _StockReportViewState();
}

class _StockReportViewState extends State<_StockReportView> {
  late Future<_StockReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StockReportData> _load() async {
    final start = DateTime(
      widget.from.year,
      widget.from.month,
      widget.from.day,
    ).toIso8601String();
    final end = DateTime(
      widget.to.year,
      widget.to.month,
      widget.to.day,
    ).add(const Duration(days: 1)).toIso8601String();
    final movements = await widget.session.client
        .from('stock_movements')
        .select()
        .gte('created_at', start)
        .lt('created_at', end)
        .order('created_at', ascending: false)
        .limit(500);
    final items = await widget.session.client
        .from('items')
        .select('id,name,item_type,unit_id');
    final stores = await widget.session.client.from('stores').select('id,name');
    final units = await widget.session.client
        .from('units')
        .select('id,name,code');
    final itemNames = {
      for (final row in items) row['id'].toString(): asText(row['name']),
    };
    final itemUnits = {
      for (final row in items) row['id'].toString(): row['unit_id']?.toString(),
    };
    final storeNames = {
      for (final row in stores) row['id'].toString(): asText(row['name']),
    };
    final unitNames = {
      for (final row in units) row['id'].toString(): asText(row['name']),
    };
    var totalIn = 0.0;
    var totalOut = 0.0;
    final rows = <Map<String, dynamic>>[];
    for (final raw in movements) {
      final row = Map<String, dynamic>.from(raw as Map);
      final type = asText(row['movement_type']);
      final quantity = asNum(row['quantity']);
      final signed = _isStockIn(type)
          ? quantity
          : type == 'adjustment' || type == 'count'
          ? quantity
          : -quantity;
      if (signed >= 0) {
        totalIn += signed;
      } else {
        totalOut += signed.abs();
      }
      final itemId = row['item_id']?.toString() ?? '';
      final unitId = itemUnits[itemId];
      rows.add({
        'date': row['created_at'],
        'item': itemNames[itemId] ?? itemId,
        'type': type,
        'quantity': signed,
        'unit': unitNames[unitId] ?? '',
        'store': storeNames[row['store_id']?.toString()] ?? '',
        'reference': asText(row['reference_type']).isEmpty
            ? asText(row['notes'])
            : '${asText(row['reference_type'])} ${asText(row['reference_id'])}',
      });
    }
    return _StockReportData(rows: rows, totalIn: totalIn, totalOut: totalOut);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_StockReportData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ErrorView(
          message: friendlyMessage(snapshot.error!),
          onRetry: () async {
            setState(() {
              _future = _load();
            });
          },
        );
      }
      final data = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SummaryGrid(
            summary: {
              'stock_movements': data.rows.length,
              'stock_in': data.totalIn,
              'stock_out': data.totalOut,
            },
            labels: const {
              'stock_movements': 'Transactions',
              'stock_in': 'Stock in',
              'stock_out': 'Stock out',
            },
          ),
          _ReportTable(
            title: 'Stock movements',
            rows: data.rows,
            maxRows: 200,
            emptyMessage: 'No movements in this date range.',
          ),
        ],
      );
    },
  );
}

class _SalesReportData {
  const _SalesReportData({
    required this.rows,
    required this.total,
    required this.paid,
  });

  final List<Map<String, dynamic>> rows;
  final num total;
  final num paid;
}

class _SalesReportView extends StatefulWidget {
  const _SalesReportView({
    super.key,
    required this.session,
    required this.from,
    required this.to,
  });

  final AuthController session;
  final DateTime from;
  final DateTime to;

  @override
  State<_SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<_SalesReportView> {
  late Future<_SalesReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalesReportData> _load() async {
    final sales = await widget.session.client
        .from('sales')
        .select()
        .gte('sale_date', dateOnly(widget.from))
        .lte('sale_date', dateOnly(widget.to))
        .order('sale_date', ascending: false)
        .limit(500);
    var total = 0.0;
    var paid = 0.0;
    final rows = <Map<String, dynamic>>[];
    for (final raw in sales) {
      final row = Map<String, dynamic>.from(raw as Map);
      total += asNum(row['total_amount']);
      paid += asNum(row['paid_amount']);
      rows.add({
        'receipt_no': row['receipt_no'],
        'sale_date': row['sale_date'],
        'total_amount': row['total_amount'],
        'paid_amount': row['paid_amount'],
        'payment_status': row['payment_status'],
        'status': row['status'],
      });
    }
    return _SalesReportData(rows: rows, total: total, paid: paid);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_SalesReportData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ErrorView(
          message: friendlyMessage(snapshot.error!),
          onRetry: () async {
            setState(() {
              _future = _load();
            });
          },
        );
      }
      final data = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => context.push('/pos'),
                icon: const Icon(Icons.add),
                label: Text(uiText(context, 'Record sale')),
              ),
            ),
          ),
          _SummaryGrid(
            summary: {
              'total_sales': data.total,
              'paid': data.paid,
              'transactions': data.rows.length,
              'balance': data.total - data.paid,
            },
            labels: const {
              'total_sales': 'Total sales',
              'paid': 'Paid',
              'transactions': 'Transactions',
              'balance': 'Balance',
            },
          ),
          _ReportTable(
            title: 'Sales',
            rows: data.rows,
            maxRows: 200,
            emptyMessage: 'No sales in this date range.',
          ),
        ],
      );
    },
  );
}

class _RentReportData {
  const _RentReportData({
    required this.invoices,
    required this.payments,
    required this.leases,
    required this.nextDue,
    required this.overdue,
    required this.collected,
  });

  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> leases;
  final Map<String, dynamic>? nextDue;
  final num overdue;
  final num collected;
}

class _RentReportView extends StatefulWidget {
  const _RentReportView({
    super.key,
    required this.session,
    required this.from,
    required this.to,
  });

  final AuthController session;
  final DateTime from;
  final DateTime to;

  @override
  State<_RentReportView> createState() => _RentReportViewState();
}

class _RentReportViewState extends State<_RentReportView> {
  late Future<_RentReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RentReportData> _load() async {
    final invoices = await widget.session.client
        .from('rent_invoices')
        .select()
        .order('due_date');
    final payments = await widget.session.client
        .from('rent_payments')
        .select()
        .order('payment_date', ascending: false);
    final leases = await widget.session.client.from('leases').select();
    final tenants = await widget.session.client
        .from('tenants')
        .select('id,full_name');
    final properties = await widget.session.client
        .from('properties')
        .select('id,name,code');
    final tenantNames = {
      for (final row in tenants) row['id'].toString(): asText(row['full_name']),
    };
    final propertyNames = {
      for (final row in properties) row['id'].toString(): asText(row['name']),
    };
    final leaseRows = [
      for (final raw in leases) Map<String, dynamic>.from(raw as Map),
    ];
    final invoiceNames = {
      for (final raw in invoices)
        raw['id'].toString(): asText(raw['invoice_no']),
    };
    final today = DateTime.now();
    final open = <Map<String, dynamic>>[];
    var overdue = 0.0;
    for (final raw in invoices) {
      final row = Map<String, dynamic>.from(raw as Map);
      final balance = asNum(row['amount']) - asNum(row['paid_amount']);
      if (balance > 0.001) {
        open.add(row);
        final due = DateTime.tryParse(asText(row['due_date']));
        if (due != null &&
            due.isBefore(DateTime(today.year, today.month, today.day))) {
          overdue += balance;
        }
      }
    }
    open.sort((a, b) => asText(a['due_date']).compareTo(asText(b['due_date'])));
    final from = DateTime(widget.from.year, widget.from.month, widget.from.day);
    final to = DateTime(
      widget.to.year,
      widget.to.month,
      widget.to.day,
    ).add(const Duration(days: 1));
    var collected = 0.0;
    final paymentRows = <Map<String, dynamic>>[];
    for (final raw in payments) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.tryParse(asText(row['payment_date']));
      if (date != null && date.isBefore(from)) continue;
      if (date != null && !date.isBefore(to)) continue;
      collected += asNum(row['amount']);
      paymentRows.add({
        'payment_date': row['payment_date'],
        'amount': row['amount'],
        'method': row['method'],
        'invoice': invoiceNames[row['invoice_id']?.toString()] ?? '',
        'reference': row['reference'],
      });
    }
    final invoiceRows = [
      for (final raw in invoices)
        Map<String, dynamic>.from(raw as Map)
          ..['tenant_name'] = tenantNames[raw['tenant_id']?.toString()] ?? ''
          ..['balance'] = asNum(raw['amount']) - asNum(raw['paid_amount']),
    ];
    return _RentReportData(
      invoices: invoiceRows,
      payments: paymentRows,
      leases: [
        for (final row in leaseRows)
          {
            'lease_no': row['lease_no'],
            'property': propertyNames[row['property_id']?.toString()] ?? '',
            'tenant': tenantNames[row['tenant_id']?.toString()] ?? '',
            'start_date': row['start_date'],
            'end_date': row['end_date'],
            'rent_amount': row['rent_amount'],
            'billing_frequency': row['billing_frequency'],
            'status': row['status'],
          },
      ],
      nextDue: open.isEmpty ? null : open.first,
      overdue: overdue,
      collected: collected,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RentReportData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ErrorView(
          message: friendlyMessage(snapshot.error!),
          onRetry: () async {
            setState(() {
              _future = _load();
            });
          },
        );
      }
      final data = snapshot.data!;
      final next = data.nextDue;
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SummaryGrid(
            summary: {
              'next_due': next == null
                  ? 0
                  : asNum(next['amount']) - asNum(next['paid_amount']),
              'overdue': data.overdue,
              'collected': data.collected,
            },
            labels: const {
              'next_due': 'Next rent due',
              'overdue': 'Overdue rent',
              'collected': 'Rent collected',
            },
            captions: {
              'next_due': next == null
                  ? uiText(context, 'No rent due')
                  : formatDate(next['due_date']),
            },
          ),
          _ReportTable(
            title: 'Rent invoices',
            rows: data.invoices,
            maxRows: 200,
            emptyMessage: 'No rent invoices.',
          ),
          _ReportTable(
            title: 'Rent payments',
            rows: data.payments,
            maxRows: 200,
            emptyMessage: 'No payments yet.',
          ),
          _ReportTable(
            title: 'Leases',
            rows: data.leases,
            maxRows: 200,
            emptyMessage: 'No data for this report.',
          ),
        ],
      );
    },
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    this.labels = const {},
    this.captions = const {},
  });

  final Map<String, dynamic> summary;
  final Map<String, String> labels;
  final Map<String, String> captions;

  @override
  Widget build(BuildContext context) {
    final entries = summary.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            _StatTile(
              label: uiText(
                context,
                labels[entry.key] ?? prettyLabel(entry.key),
              ),
              value: _summaryValue(entry.key, entry.value),
              caption: captions[entry.key],
            ),
        ],
      ),
    );
  }

  String _summaryValue(String key, Object? value) {
    if (key.contains('items') ||
        key.contains('transactions') ||
        key.contains('count') ||
        key == 'staff_present_today') {
      return formatQuantity(value);
    }
    return formatMoney(value);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.title,
    required this.rows,
    this.maxRows = 10,
    this.emptyMessage = 'No data for this report.',
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final int maxRows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(uiText(context, emptyMessage)),
            ],
          ),
        ),
      );
    }
    final keys = rows.first.keys.take(8).toList();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final key in keys)
                  DataColumn(label: Text(_reportLabel(context, key))),
              ],
              rows: [
                for (final row in rows.take(maxRows))
                  DataRow(
                    cells: [
                      for (final key in keys)
                        DataCell(
                          Text(
                            _reportValue(key, row[key]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (rows.length > maxRows)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                '${rows.length} rows · showing $maxRows',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

String _reportLabel(BuildContext context, String key) {
  final labels = <String, String>{
    'day': 'Date',
    'date': 'Date',
    'created_at': 'Date',
    'sale_date': 'Sale date',
    'payment_date': 'Payment date',
    'due_date': 'Due date',
    'receipt_no': 'Receipt',
    'invoice_no': 'Invoice',
    'invoice': 'Invoice',
    'total_sales': 'Total sales',
    'total_amount': 'Total',
    'amount': 'Amount',
    'paid_amount': 'Paid',
    'paid': 'Paid',
    'balance': 'Balance',
    'status': 'Status',
    'payment_status': 'Status',
    'item': 'Item',
    'item_name': 'Item',
    'name': 'Name',
    'store': 'Store',
    'type': 'Type',
    'movement_type': 'Type',
    'quantity': 'Quantity',
    'unit': 'Unit',
    'unit_name': 'Unit',
    'reference': 'Reference',
    'tenant': 'Tenant',
    'tenant_name': 'Tenant',
    'property': 'Property',
    'lease_no': 'Lease',
    'rent_amount': 'Rent amount',
    'billing_frequency': 'Frequency',
    'start_date': 'Period start',
    'end_date': 'Period end',
    'employee_name': 'Employee',
    'gross_pay': 'Gross pay',
    'net_pay': 'Net pay',
    'customer_name': 'Customer',
    'supplier_name': 'Supplier',
    'category_name': 'Category',
    'total_in': 'Cash in',
    'total_out': 'Cash out',
    'net': 'Net cash',
  };
  return uiText(context, labels[key] ?? prettyLabel(key));
}

String _reportValue(String key, Object? value) {
  if (value == null) return '—';
  if (value is num) {
    if (key.contains('date') || key == 'day') return formatDate(value);
    if (key.contains('quantity') ||
        key.contains('items') ||
        key.contains('count')) {
      return formatQuantity(value);
    }
    return formatMoney(value);
  }
  if (key.contains('date') || key == 'day' || key == 'created_at') {
    return formatDateTime(value);
  }
  if (key == 'movement_type' || key == 'type' || key == 'status') {
    return prettyLabel(value.toString());
  }
  return value.toString();
}

bool _isStockIn(String type) =>
    type == 'purchase' ||
    type == 'production_in' ||
    type == 'return_in' ||
    type == 'transfer_in';
