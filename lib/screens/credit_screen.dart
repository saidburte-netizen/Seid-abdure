import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class CreditScreen extends StatelessWidget {
  const CreditScreen({super.key});

  Future<void> _payment(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> row,
    String type,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    try {
      final accounts = await repo.list(
        'cash_accounts',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      if (accounts.isEmpty) {
        throw Exception('Create a cash account before recording a payment.');
      }
      if (!context.mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _CreditPaymentDialog(
          title: type == 'receivable'
              ? 'Receive customer payment'
              : 'Pay supplier',
          accounts: accounts,
          suggested: type == 'receivable'
              ? asNum(row['balance'])
              : asNum(row['balance']),
        ),
      );
      if (result == null) return;
      if (type == 'receivable') {
        await session.client.from('receivable_payments').insert({
          'receivable_id': row['id'],
          'cash_account_id': result['account'],
          'amount': result['amount'],
          'payment_date': dateOnly(DateTime.now()),
          'method': result['method'],
          'reference': result['reference'],
          'received_by': session.userId,
        });
      } else {
        await session.client.from('payable_payments').insert({
          'payable_id': row['id'],
          'cash_account_id': result['account'],
          'amount': result['amount'],
          'payment_date': dateOnly(DateTime.now()),
          'method': result['method'],
          'reference': result['reference'],
          'paid_by': session.userId,
        });
      }
      if (context.mounted) showSnack(context, 'Payment recorded.');
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _approveWriteOff(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> row,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Approve write-off?',
      message: 'The database trigger will reduce the receivable balance.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    try {
      await session.client.from('write_offs').update({
        'status': 'approved',
        'approved_by': session.userId,
        'decided_at': nowIso(),
      }).eq('id', row['id']);
      if (context.mounted) showSnack(context, 'Write-off approved.');
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Credit & debit control',
      body: DefaultTabController(
        length: 10,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Receivables'),
                Tab(text: 'Receipts'),
                Tab(text: 'Payables'),
                Tab(text: 'Payments'),
                Tab(text: 'Write-offs'),
                Tab(text: 'Ledger'),
                Tab(text: 'Customer aging'),
                Tab(text: 'Supplier aging'),
                Tab(text: 'Customer balances'),
                Tab(text: 'Supplier balances'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('receivables'),
                    readPermission: 'credit.manage',
                    writePermission: 'credit.manage',
                    actions: (row) {
                      if (!session.can('credit.manage') ||
                          asNum(row['balance']) <= 0) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Receive payment',
                          icon: Icons.payments_outlined,
                          onPressed: (row) =>
                              _payment(context, session, row, 'receivable'),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('receivable_payments'),
                    readPermission: 'credit.manage',
                    writePermission: 'credit.manage',
                  ),
                  CrudTab(
                    spec: specFor('payables'),
                    readPermission: 'credit.manage',
                    writePermission: 'credit.manage',
                    actions: (row) {
                      if (!session.can('credit.manage') ||
                          asNum(row['balance']) <= 0) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Pay supplier',
                          icon: Icons.payments_outlined,
                          onPressed: (row) =>
                              _payment(context, session, row, 'payable'),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('payable_payments'),
                    readPermission: 'credit.manage',
                    writePermission: 'credit.manage',
                  ),
                  CrudTab(
                    spec: specFor('write_offs'),
                    readPermission: 'credit.manage',
                    writePermission: 'credit.manage',
                    actions: (row) {
                      if (!session.can('credit.manage') ||
                          row['status'] == 'approved') {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve write-off',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) =>
                              _approveWriteOff(context, session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('ledger_entries'),
                    readPermission: 'credit.manage',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('v_receivable_aging'),
                    readPermission: 'credit.manage',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('v_payable_aging'),
                    readPermission: 'credit.manage',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('v_customer_balances'),
                    readPermission: 'credit.manage',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('v_supplier_balances'),
                    readPermission: 'credit.manage',
                    alwaysReadOnly: true,
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

class _CreditPaymentDialog extends StatefulWidget {
  const _CreditPaymentDialog({
    required this.title,
    required this.accounts,
    required this.suggested,
  });

  final String title;
  final List<Map<String, dynamic>> accounts;
  final num suggested;

  @override
  State<_CreditPaymentDialog> createState() => _CreditPaymentDialogState();
}

class _CreditPaymentDialogState extends State<_CreditPaymentDialog> {
  late final _amount = TextEditingController(
    text: widget.suggested.toStringAsFixed(2),
  );
  final _reference = TextEditingController();
  late String _account = widget.accounts.first['id'] as String;
  String _method = 'cash';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _account,
              decoration: const InputDecoration(labelText: 'Cash account'),
              items: [
                for (final account in widget.accounts)
                  DropdownMenuItem(
                    value: account['id'] as String,
                    child: Text(asText(account['name'])),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _account = value ?? _account),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'telebirr', child: Text('Telebirr')),
                DropdownMenuItem(value: 'cbe_birr', child: Text('CBE Birr')),
                DropdownMenuItem(
                    value: 'mobile_money', child: Text('Mobile money')),
              ],
              onChanged: (value) => setState(() => _method = value ?? 'cash'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(labelText: 'Reference'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'account': _account,
              'amount': asNum(_amount.text),
              'method': _method,
              'reference': _reference.text.trim(),
            }),
            child: const Text('Record payment'),
          ),
        ],
      );
}
