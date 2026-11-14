import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  Future<void> _createPayable(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> bill,
  ) async {
    try {
      await session.client.from('payables').insert({
        'supplier_id': bill['supplier_id'],
        'bill_id': bill['id'],
        'description': bill['description'] ?? 'Bill ${bill['bill_no']}',
        'amount': bill['amount'],
        'paid_amount': bill['paid_amount'] ?? 0,
        'balance': asNum(bill['amount']) - asNum(bill['paid_amount']),
        'due_date': bill['due_date'],
        'status': 'open',
        'created_by': session.userId,
      });
      if (context.mounted) showSnack(context, 'Payable created from bill.');
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _payPayable(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> payable,
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
        throw Exception('Create a cash account before paying a payable.');
      }
      if (!context.mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _PaymentDialog(
          title: 'Pay payable',
          accounts: accounts,
          suggested: asNum(payable['balance']),
        ),
      );
      if (result == null) return;
      await session.client.from('payable_payments').insert({
        'payable_id': payable['id'],
        'cash_account_id': result['account'],
        'amount': result['amount'],
        'payment_date': dateOnly(DateTime.now()),
        'method': result['method'],
        'reference': result['reference'],
        'paid_by': session.userId,
      });
      if (context.mounted) showSnack(context, 'Payable payment recorded.');
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
      title: 'Cash & expenses',
      body: DefaultTabController(
        length: 8,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Balances'),
                Tab(text: 'Accounts'),
                Tab(text: 'Transactions'),
                Tab(text: 'Transfers'),
                Tab(text: 'Expense categories'),
                Tab(text: 'Bills'),
                Tab(text: 'Payables'),
                Tab(text: 'Payable payments'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('v_cash_account_balances'),
                    readPermission: 'cash.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('cash_accounts'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                  ),
                  CrudTab(
                    spec: specFor('cash_transactions'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                  ),
                  CrudTab(
                    spec: specFor('cash_transfers'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                  ),
                  CrudTab(
                    spec: specFor('expense_categories'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                  ),
                  CrudTab(
                    spec: specFor('bills'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                    actions: (row) {
                      if (!session.can('cash.manage')) return const [];
                      return [
                        CrudRowAction(
                          label: 'Create payable',
                          icon: Icons.request_quote_outlined,
                          onPressed: (row) =>
                              _createPayable(context, session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('payables'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
                    actions: (row) {
                      if (!session.can('cash.manage') ||
                          asNum(row['balance']) <= 0) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Pay payable',
                          icon: Icons.payments_outlined,
                          onPressed: (row) =>
                              _payPayable(context, session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('payable_payments'),
                    readPermission: 'cash.view',
                    writePermission: 'cash.manage',
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

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.title,
    required this.accounts,
    required this.suggested,
  });

  final String title;
  final List<Map<String, dynamic>> accounts;
  final num suggested;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
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
                DropdownMenuItem(value: 'card', child: Text('Card')),
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
