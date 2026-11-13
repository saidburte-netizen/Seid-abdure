import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Sales',
      body: DefaultTabController(
        length: 5,
        initialIndex: _tab,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (value) => _tab = value,
              tabs: const [
                Tab(text: 'Sales'),
                Tab(text: 'Returns'),
                Tab(text: 'Customers'),
                Tab(text: 'Receivables'),
                Tab(text: 'Daily closes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _salesTab(session),
                  _returnsTab(),
                  _customersTab(session),
                  const _ReceivablesView(),
                  _dailyClosesTab(session),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: session.can('sales.write')
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/pos'),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('New sale'),
            )
          : null,
    );
  }

  Widget _salesTab(AuthController session) => CrudTab(
        spec: _salesSpec,
        readPermission: 'sales.read',
        alwaysReadOnly: true,
        emptyMessage: 'No sales recorded yet.',
        actions: (row) {
          final status = row['status']?.toString();
          final actions = <CrudRowAction>[
            CrudRowAction(
              label: 'View receipt',
              icon: Icons.receipt_long_outlined,
              onPressed: (row) async {
                final receipt = await session.client
                    .from('receipts')
                    .select()
                    .eq('sale_id', row['id'])
                    .maybeSingle();
                if (context.mounted) {
                  await showInfoDialog(
                    context,
                    title: 'Receipt ${asText(receipt?['receipt_number'])}',
                    content: receipt?['payload'] ?? receipt ?? 'No receipt found.',
                  );
                }
              },
            ),
          ];
          if (status == 'completed' && session.can('sales.void')) {
            actions.add(CrudRowAction(
              label: 'Return items',
              icon: Icons.assignment_return_outlined,
              onPressed: (row) => _processReturn(session, row),
            ));
            actions.add(CrudRowAction(
              label: 'Void sale',
              icon: Icons.cancel_outlined,
              danger: true,
              onPressed: (row) async {
                final reason = await showInputDialog(
                  context,
                  title: 'Void sale ${asText(row['sale_number'])}',
                  submitLabel: 'Void sale',
                  fields: const [
                    InputField('reason', 'Reason', required: true, type: FieldType.multiline),
                  ],
                );
                if (reason == null) return;
                await session.client.rpc('void_sale', params: {
                  'target_sale': row['id'],
                  'reason': reason['reason'],
                });
                if (context.mounted) {
                  showSnack(context, 'Sale voided and stock restored.');
                }
              },
            ));
          }
          return actions;
        },
      );

  Widget _returnsTab() => CrudTab(
        spec: _returnsSpec,
        readPermission: 'sales.read',
        alwaysReadOnly: true,
        emptyMessage: 'No returns recorded.',
      );

  Widget _customersTab(AuthController session) => CrudTab(
        spec: customersSpec,
        readPermission: 'customers.read',
        writePermission: 'customers.write',
        emptyMessage: 'No customers yet.',
        actions: (row) {
          if (!session.can('customers.write')) return const [];
          return [
            CrudRowAction(
              label: 'Receive payment',
              icon: Icons.payments_outlined,
              onPressed: (row) => _receiveCustomerPayment(session, row),
            ),
            CrudRowAction(
              label: 'Account statement',
              icon: Icons.receipt_long_outlined,
              onPressed: (row) async {
                final ledger = await session.client
                    .from('customer_ledger')
                    .select()
                    .eq('customer_id', row['id'])
                    .order('created_at', ascending: false)
                    .limit(200);
                if (context.mounted) {
                  await showInfoDialog(
                    context,
                    title: 'Statement — ${asText(row['name'])}',
                    content: ledger,
                  );
                }
              },
            ),
          ];
        },
      );

  Widget _dailyClosesTab(AuthController session) => CrudTab(
        spec: _dailyClosesSpec,
        readPermission: 'sales.read',
        alwaysReadOnly: true,
        emptyMessage: 'No business day has been closed yet.',
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: session.can('sales.write')
                  ? () => _closeDay(session)
                  : null,
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Close business day'),
            ),
          ),
        ),
      );

  Future<void> _processReturn(
    AuthController session,
    Map<String, dynamic> sale,
  ) async {
    final items = await session.client
        .from('sale_items')
        .select('id, product_id, quantity, unit_price, products(name)')
        .eq('sale_id', sale['id']);
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReturnDialog(
        sale: sale,
        items: (items as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
      ),
    );
    if (result == null) return;
    try {
      final response = await session.client.rpc('process_sale_return', params: {
        'target_sale': sale['id'],
        'return_lines': result['lines'],
        'refund_method': result['refund_method'],
        'return_reason': result['reason'],
      });
      if (mounted) {
        showSnack(
          context,
          'Return ${asText(asMap(response)['return_number'])} completed: '
          '${formatMoney(asMap(response)['total'])}.',
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _receiveCustomerPayment(
    AuthController session,
    Map<String, dynamic> customer,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    final accounts = await repo.list(
      'cash_accounts',
      equals: {'is_active': true},
      orderBy: 'name',
    );
    final balanceRows = await repo.list(
      'customer_balances',
      equals: {'customer_id': customer['id']},
      limit: 1,
    );
    if (!mounted) return;
    if (accounts.isEmpty) {
      showSnack(context, 'Create a cash account first.', error: true);
      return;
    }
    final outstanding = balanceRows.isEmpty ? 0 : asNum(balanceRows.first['balance']);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CustomerPaymentDialog(
        customerName: asText(customer['name']),
        outstanding: outstanding,
        accounts: accounts,
      ),
    );
    if (result == null) return;
    try {
      await session.client.rpc('record_customer_payment', params: {
        'target_customer': customer['id'],
        'target_account': result['account_id'],
        'payment_amount': result['amount'],
        'payment_method': result['method'],
        'payment_reference': result['reference'],
      });
      if (mounted) showSnack(context, 'Customer payment recorded.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _closeDay(AuthController session) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final result = await showInputDialog(
      context,
      title: 'Close ${formatDate(DateTime.now())}',
      submitLabel: 'Close day',
      fields: const [
        InputField('counted_cash', 'Counted cash (ETB)', type: FieldType.number, required: true, min: 0),
        InputField('notes', 'Notes', type: FieldType.multiline),
      ],
    );
    if (result == null) return;
    try {
      final response = await session.client.rpc('close_business_day', params: {
        'target_branch': branch.branchId,
        'business_date': dateOnly(DateTime.now()),
        'counted_cash': result['counted_cash'],
        'close_notes': result['notes'] ?? '',
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Business day closed',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _salesSpec = TableSpec(
  table: 'sales',
  title: 'Sales',
  singular: 'Sale',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['sale_number', 'status', 'notes'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('sale_number', 'Sale number', list: true),
    FieldSpec('created_at', 'Date', type: FieldType.date, list: true),
    FieldSpec('customer_id', 'Customer', type: FieldType.lookup, lookupTable: 'customers', list: true),
    FieldSpec('status', 'Status', type: FieldType.select, list: true, options: {
      'draft': 'Draft', 'completed': 'Completed', 'voided': 'Voided', 'refunded': 'Refunded',
    }),
    FieldSpec('subtotal', 'Subtotal', type: FieldType.number, list: true),
    FieldSpec('discount', 'Discount', type: FieldType.number),
    FieldSpec('tax_total', 'Tax', type: FieldType.number),
    FieldSpec('grand_total', 'Total', type: FieldType.number, list: true),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const _returnsSpec = TableSpec(
  table: 'sale_returns',
  title: 'Returns',
  singular: 'Return',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['return_number', 'status', 'reason'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('return_number', 'Return number', list: true),
    FieldSpec('created_at', 'Date', type: FieldType.date, list: true),
    FieldSpec('refund_method', 'Refund method', type: FieldType.select, list: true, options: {
      'cash': 'Cash', 'customer_credit': 'Customer credit', 'original': 'Original method',
    }),
    FieldSpec('total', 'Total', type: FieldType.number, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, list: true, options: {
      'completed': 'Completed', 'voided': 'Voided',
    }),
    FieldSpec('reason', 'Reason', list: true),
  ],
);

const _dailyClosesSpec = TableSpec(
  table: 'daily_closes',
  title: 'Daily closes',
  singular: 'Business day',
  orderBy: 'business_date',
  ascending: false,
  searchColumns: ['business_date', 'status', 'notes'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('business_date', 'Date', type: FieldType.date, list: true),
    FieldSpec('sales_total', 'Sales', type: FieldType.number, list: true),
    FieldSpec('expected_cash', 'Expected cash', type: FieldType.number, list: true),
    FieldSpec('counted_cash', 'Counted cash', type: FieldType.number, list: true),
    FieldSpec('variance', 'Variance', type: FieldType.number, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, list: true, options: {
      'closed': 'Closed', 'reopened': 'Reopened',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.sale, required this.items});

  final Map<String, dynamic> sale;
  final List<Map<String, dynamic>> items;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _selected = <String, bool>{};
  final _quantities = <String, TextEditingController>{};
  String _refundMethod = 'cash';
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final id = item['id'] as String;
      _selected[id] = false;
      _quantities[id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Return — ${asText(widget.sale['sale_number'])}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.items)
                  _itemRow(item),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _refundMethod,
                  decoration: const InputDecoration(labelText: 'Refund method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'customer_credit', child: Text('Customer credit')),
                    DropdownMenuItem(value: 'original', child: Text('Original payment method')),
                  ],
                  onChanged: (value) =>
                      setState(() => _refundMethod = value ?? 'cash'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Process return'),
          ),
        ],
      );

  Widget _itemRow(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final quantity = asNum(item['quantity']);
    final product = asMap(item['products']);
    return Row(
      children: [
        Checkbox(
          value: _selected[id] ?? false,
          onChanged: (value) => setState(() => _selected[id] = value == true),
        ),
        Expanded(
          child: Text(
            '${asText(product['name'], fallback: 'Product')} • '
            '${formatMoney(item['unit_price'])} x ${formatQuantity(quantity)}',
          ),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _quantities[id],
            enabled: _selected[id] == true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Qty',
              helperText: 'Max ${formatQuantity(quantity)}',
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final lines = <Map<String, dynamic>>[];
    for (final item in widget.items) {
      final id = item['id'] as String;
      if (_selected[id] != true) continue;
      final quantity = asNum(_quantities[id]?.text);
      if (quantity <= 0 || quantity > asNum(item['quantity'])) continue;
      lines.add({'sale_item_id': id, 'quantity': quantity});
    }
    if (lines.isEmpty) {
      showSnack(context, 'Select at least one item and quantity.', error: true);
      return;
    }
    Navigator.of(context).pop({
      'lines': lines,
      'refund_method': _refundMethod,
      'reason': _reason.text.trim(),
    });
  }
}

class _CustomerPaymentDialog extends StatefulWidget {
  const _CustomerPaymentDialog({
    required this.customerName,
    required this.outstanding,
    required this.accounts,
  });

  final String customerName;
  final num outstanding;
  final List<Map<String, dynamic>> accounts;

  @override
  State<_CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<_CustomerPaymentDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String? _accountId;
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    _amount.text = widget.outstanding > 0 ? widget.outstanding.toStringAsFixed(2) : '';
    _accountId = widget.accounts.isEmpty
        ? null
        : widget.accounts.first['id'] as String?;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Payment from ${widget.customerName}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding: ${formatMoney(widget.outstanding)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Deposit to account'),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account['id'] as String,
                      child: Text(asText(account['name'])),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'telebirr', child: Text('TeleBirr')),
                  DropdownMenuItem(value: 'cbe_birr', child: Text('CBE Birr')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _method = value ?? 'cash'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (ETB)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Reference (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = asNum(_amount.text);
              if (_accountId == null) {
                showSnack(context, 'Choose an account.', error: true);
                return;
              }
              if (amount <= 0) {
                showSnack(context, 'Enter a payment amount.', error: true);
                return;
              }
              Navigator.of(context).pop({
                'account_id': _accountId,
                'amount': amount,
                'method': _method,
                'reference': _reference.text.trim(),
              });
            },
            child: const Text('Record payment'),
          ),
        ],
      );
}

class _ReceivablesView extends StatefulWidget {
  const _ReceivablesView();

  @override
  State<_ReceivablesView> createState() => _ReceivablesViewState();
}

class _ReceivablesViewState extends State<_ReceivablesView> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return Future.value(const {});
    return session.client
        .rpc('report_receivables', params: {'target_branch': branch.branchId})
        .then(asMap);
  }

  @override
  Widget build(BuildContext context) => AsyncView<Map<String, dynamic>>(
        future: _future ?? Future.value(const {}),
        onRetry: () async => setState(() => _future = _load()),
        builder: (context, data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Receivables',
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: () => setState(() => _future = _load()),
                icon: const Icon(Icons.refresh),
              ),
              child: JsonView(value: data),
            ),
          ],
        ),
      );
}
