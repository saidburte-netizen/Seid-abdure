import 'package:flutter/material.dart';

import '../data/schema.dart';
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

  String _selected = 'v_dashboard_kpis';
  int _refreshSeed = 0;

  @override
  Widget build(BuildContext context) => ModuleScaffold(
    title: uiText(context, 'Reports & analytics'),
    kpiKinds: const [KpiKind.cashBalance, KpiKind.todaySales, KpiKind.lowStock],
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Report view'),
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
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _refreshSeed++),
                icon: const Icon(Icons.refresh),
                label: const LText('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: CrudTab(
            key: ValueKey('$_selected-$_refreshSeed'),
            spec: specFor(_selected),
            readPermission: 'reports.view',
            alwaysReadOnly: true,
          ),
        ),
      ],
    ),
  );
}
