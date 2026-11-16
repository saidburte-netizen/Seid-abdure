import '../core/events/data_revision.dart';
import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/void_sale_access.dart';
import '../data/formatting.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import 'pos_screen.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ui_text.dart';

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
      // The database owns the refund cash row (trg_returns_cash) and the
      // restored stock rows (trg_return_items_stock). Inserting them here
      // would double the refund and the stock movement.
      await session.client
          .from('sales')
          .update({'status': 'returned'})
          .eq('id', sale['id']);
      if (mounted) {
        showSnack(context, 'Return $returnNo recorded.');
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _voidSale(
    AuthController session,
    Map<String, dynamic> sale,
  ) async {
    final input = await showInputDialog(
      context,
      title: 'Void ${asText(sale['receipt_no'])}',
      fields: const [
        InputField(
          'reason',
          'Void reason',
          type: FieldType.multiline,
          required: true,
          hint: 'Explain why this completed sale is being voided',
        ),
      ],
      submitLabel: 'Void sale',
    );
    if (input == null || !mounted) return;
    final confirmed = await confirmAction(
      context,
      title: uiText(context, 'Void this sale?'),
      message: uiText(
        context,
        'The database restores stock, cash and credit for this sale. This cannot be undone.',
      ),
      confirmLabel: uiText(context, 'Void sale'),
    );
    if (!confirmed || !mounted) return;
    try {
      await session.client.rpc(
        'void_sale',
        params: {
          'target_sale': sale['id'],
          'reason': (input['reason'] ?? '').toString().trim(),
        },
      );
      if (mounted) {
        showSnack(context, AppLocalizations.of(context).voidSaleSuccess);
        DataRevision.bump();
      }
    } catch (error) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context);
      final failure = classifyVoidSaleFailure(error);
      final message = switch (failure) {
        VoidSaleFailure.notFound => strings.voidSaleNotFound,
        VoidSaleFailure.alreadyVoided => strings.voidSaleAlreadyVoided,
        VoidSaleFailure.onlyCompleted => strings.voidSaleOnlyCompleted,
        VoidSaleFailure.hasReturns => strings.voidSaleHasReturns,
        VoidSaleFailure.permissionDenied => strings.errorPermissionDenied,
        VoidSaleFailure.unknown => strings.voidSaleFailed,
      };
      showSnack(context, message);
    }
  }

  Future<void> _receipt(
    AuthController session,
    Map<String, dynamic> sale,
  ) async {
    final title = uiText(context, 'Sales receipt');
    final statusLabel = uiText(context, 'Status');
    final statusValue = uiText(
      context,
      prettyLabel(asText(sale['payment_status'])),
    );
    try {
      final items = await session.client
          .from('sale_items')
          .select()
          .eq('sale_id', sale['id']);
      final branch = session.selectedBranch;
      final bytes = await BrandPdf.document(
        title: title,
        documentNumber: asText(sale['receipt_no']),
        branchName: branch?.branchName ?? 'Jimma branch',
        subtitle: formatDate(sale['sale_date']),
        details: [
          ('Total', formatMoney(sale['total_amount'])),
          ('Paid', formatMoney(sale['paid_amount'])),
          (statusLabel, statusValue),
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
      if (mounted) showFriendlyError(context, error);
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
      if (mounted) showSnack(context, 'Day closed successfully');
      DataRevision.bump();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'Sales & returns'),
      kpiKinds: const [KpiKind.todaySales, KpiKind.lowStock],
      actions: [
        if (session.can('pos.use'))
          IconButton(
            tooltip: uiText(context, 'New sale'),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PosScreen())),
            icon: const Icon(Icons.point_of_sale),
          ),
      ],
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            const AppTabBar(
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
                        label: uiText(context, 'Print receipt'),
                        icon: Icons.print_outlined,
                        onPressed: (row) => _receipt(session, row),
                      ),
                      if (session.can('sales.void') &&
                          row['status'] != 'returned')
                        CrudRowAction(
                          label: uiText(context, 'Record return'),
                          icon: Icons.assignment_return_outlined,
                          onPressed: (row) => _returnSale(session, row),
                        ),
                      if (canVoidSale(session.roleCode) &&
                          row['status'] == 'completed')
                        CrudRowAction(
                          label: uiText(context, 'Void sale'),
                          icon: Icons.block_outlined,
                          onPressed: (row) => _voidSale(session, row),
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
                            label: const LText('Close today'),
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
          _error = readableError(context, error);
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
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Reason'),
                    ),
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
                            decoration: InputDecoration(
                              labelText: uiText(context, 'Return qty'),
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
        child: const LText('Cancel'),
      ),
      FilledButton(
        onPressed: _loading || _error != null ? null : _submit,
        child: const LText('Record return'),
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
    title: const LText('Close business day'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _counted,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: uiText(context, 'Counted cash'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: InputDecoration(labelText: uiText(context, 'Notes')),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const LText('Cancel'),
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
