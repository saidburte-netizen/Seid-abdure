import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import 'pos_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Future<void> _returnSale(
    AuthController session,
    Map<String, dynamic> sale,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReturnDialog(sale: sale, session: session),
    );
    if (result == null || !mounted) return;
    try {
      final branch = session.selectedBranch;
      if (branch == null) return;
      final repo = BranchRepository(session.client, branch.branchId);
      final accounts = await repo.list(
        'cash_accounts',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      if (accounts.isEmpty) {
        throw Exception('Create a cash account before recording a return.');
      }
      String returnNo;
      try {
        returnNo = (await session.client.rpc(
          'next_number',
          params: {'p_prefix': 'RETURN'},
        )).toString();
      } catch (_) {
        returnNo = 'RETURN-${DateTime.now().millisecondsSinceEpoch}';
      }
      final returned = await session.client
          .from('sale_returns')
          .insert({
            'return_no': returnNo,
            'sale_id': sale['id'],
            'return_date': dateOnly(DateTime.now()),
            'reason': result['reason'],
            'refund_amount': result['refund'],
            'cash_account_id': accounts.first['id'],
            'created_by': session.userId,
          })
          .select()
          .single();
      final lines = (result['lines'] as List)
          .map((line) => Map<String, dynamic>.from(line as Map))
          .map(
            (line) => {
              'return_id': returned['id'],
              'sale_item_id': line['sale_item_id'],
              'product_id': line['product_id'],
              'quantity': line['quantity'],
              'amount': line['amount'],
            },
          )
          .toList();
      if (lines.isNotEmpty) {
        await session.client.from('sale_return_items').insert(lines);
      }
      final refund = asNum(result['refund']);
      if (refund > 0) {
        await session.client.from('cash_transactions').insert({
          'branch_id': branch.branchId,
          'cash_account_id': accounts.first['id'],
          'txn_type': 'out',
          'amount': refund,
          'txn_date': dateOnly(DateTime.now()),
          'description': 'Refund for sale return $returnNo',
          'method': 'cash',
          'reference_type': 'sale_return',
          'reference_id': returned['id'],
          'created_by': session.userId,
        });
      }
      if (mounted) {
        showSnack(context, 'Return $returnNo recorded.');
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _receipt(
    AuthController session,
    Map<String, dynamic> sale,
  ) async {
    try {
      final items = await session.client
          .from('sale_items')
          .select()
          .eq('sale_id', sale['id']);
      final branch = session.selectedBranch;
      final bytes = await BrandPdf.document(
        title: 'Sales receipt',
        documentNumber: asText(sale['receipt_no']),
        branchName: branch?.branchName ?? 'Main branch',
        subtitle: formatDate(sale['sale_date']),
        details: [
          ('Total', formatMoney(sale['total_amount'])),
          ('Paid', formatMoney(sale['paid_amount'])),
          ('Status', prettyLabel(asText(sale['payment_status']))),
        ],
        columns: const [
          PdfColumn('Item', 'product_name'),
          PdfColumn('Qty', 'quantity', numeric: true),
          PdfColumn('Unit price', 'unit_price', numeric: true),
          PdfColumn('Total', 'line_total', numeric: true),
        ],
        rows: (items as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
        note: 'Thank you for choosing Brade and Cake House.',
      );
      await BrandPdf.share(
        fileName: 'receipt_${sale['receipt_no']}',
        bytes: bytes,
        subject: 'Brade and Cake House receipt',
      );
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _closeDay(AuthController session) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CloseDayDialog(),
    );
    if (result == null) return;
    try {
      await session.client.rpc(
        'fn_close_day',
        params: {
          'p_branch': branch.branchId,
          'p_date': dateOnly(DateTime.now()),
          'p_counted': asNum(result['counted']),
          'p_notes': result['notes'] ?? '',
        },
      );
      if (mounted) showSnack(context, 'Day closed successfully.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Sales & returns',
      actions: [
        if (session.can('pos.use'))
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PosScreen())),
            icon: const Icon(Icons.point_of_sale),
            label: const Text('New sale'),
          ),
      ],
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Sales'),
                Tab(text: 'Sale items'),
                Tab(text: 'Payments'),
                Tab(text: 'Returns'),
                Tab(text: 'Return items'),
                Tab(text: 'Daily closings'),
                Tab(text: 'Customers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('sales'),
                    readPermission: 'sales.view',
                    alwaysReadOnly: true,
                    actions: (row) => [
                      CrudRowAction(
                        label: 'Print receipt',
                        icon: Icons.print_outlined,
                        onPressed: (row) => _receipt(session, row),
                      ),
                      if (session.can('sales.void') &&
                          row['status'] != 'returned')
                        CrudRowAction(
                          label: 'Record return',
                          icon: Icons.assignment_return_outlined,
                          onPressed: (row) => _returnSale(session, row),
                        ),
                    ],
                  ),
                  CrudTab(
                    spec: specFor('sale_items'),
                    readPermission: 'sales.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('sale_payments'),
                    readPermission: 'sales.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('sale_returns'),
                    readPermission: 'sales.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('sale_return_items'),
                    readPermission: 'sales.view',
                    alwaysReadOnly: true,
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: session.can('cash.manage')
                                ? () => _closeDay(session)
                                : null,
                            icon: const Icon(Icons.lock_clock_outlined),
                            label: const Text('Close today'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CrudTab(
                          spec: specFor('daily_closings'),
                          readPermission: 'cash.view',
                          alwaysReadOnly: true,
                        ),
                      ),
                    ],
                  ),
                  CrudTab(
                    spec: specFor('customers'),
                    readPermission: 'sales.view',
                    writePermission: 'credit.manage',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.sale, required this.session});

  final Map<String, dynamic> sale;
  final AuthController session;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _reason = TextEditingController(text: 'Customer return');
  final _quantities = <String, TextEditingController>{};
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.session.client
          .from('sale_items')
          .select()
          .eq('sale_id', widget.sale['id']);
      if (!mounted) return;
      setState(() {
        _items = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        for (final item in _items) {
          _quantities[item['id'] as String] = TextEditingController(text: '0');
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = readableError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final lines = <Map<String, dynamic>>[];
    var refund = 0.0;
    for (final item in _items) {
      final quantity = asNum(_quantities[item['id']]?.text);
      if (quantity <= 0) continue;
      final unit = asNum(item['line_total']) / asNum(item['quantity']);
      final amount = (unit * quantity * 100).round() / 100;
      refund += amount;
      lines.add({
        'sale_item_id': item['id'],
        'product_id': item['product_id'],
        'quantity': quantity,
        'amount': amount,
      });
    }
    if (lines.isEmpty) return;
    Navigator.of(context).pop({
      'reason': _reason.text.trim(),
      'refund': (refund * 100).round() / 100,
      'lines': lines,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Return ${widget.sale['receipt_no']}'),
    content: SizedBox(
      width: 520,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Text(_error!)
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                  const SizedBox(height: 12),
                  for (final item in _items)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item['product_name']} (${item['quantity']})',
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _quantities[item['id']],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Return qty',
                            ),
                          ),
                        ),
                      ],
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
        onPressed: _loading || _error != null ? null : _submit,
        child: const Text('Record return'),
      ),
    ],
  );
}

class _CloseDayDialog extends StatefulWidget {
  const _CloseDayDialog();

  @override
  State<_CloseDayDialog> createState() => _CloseDayDialogState();
}

class _CloseDayDialogState extends State<_CloseDayDialog> {
  final _counted = TextEditingController(text: '0');
  final _notes = TextEditingController();

  @override
  void dispose() {
    _counted.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Close business day'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _counted,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Counted cash'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).pop({'counted': _counted.text, 'notes': _notes.text.trim()}),
        child: const Text('Close day'),
      ),
    ],
  );
}
