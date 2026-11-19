import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/save_flow.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/payment_dialog.dart';
import '../l10n/ui_text.dart';

class CashScreen extends StatelessWidget {
  const CashScreen({
    this.initialTabIndex = 0,
    this.recoveryNotice,
    this.onRecoveryDismiss,
    super.key,
  });

  final int initialTabIndex;
  final String? recoveryNotice;
  final VoidCallback? onRecoveryDismiss;

  Future<void> _createPayable(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> bill,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePayableDialog(
        bill: bill,
        onSave: () => SaveFlow.write(
          module: 'Cash & expenses',
          target: 'payables',
          action: () => session.client.from('payables').insert({
            'supplier_id': bill['supplier_id'],
            'bill_id': bill['id'],
            'description': bill['description'] ?? 'Bill ${bill['bill_no']}',
            'amount': bill['amount'],
            'paid_amount': bill['paid_amount'] ?? 0,
            'balance': asNum(bill['amount']) - asNum(bill['paid_amount']),
            'due_date': bill['due_date'],
            'status': 'open',
            'created_by': session.userId,
          }),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      showSnack(context, uiText(context, 'Payable created from bill.'));
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
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PaymentDialog(
          title: uiText(context, 'Pay payable'),
          accounts: accounts,
          maximum: asNum(payable['balance']),
          onSave: (result) => SaveFlow.write(
            module: 'Cash & expenses',
            target: 'payable_payments',
            action: () => session.client.from('payable_payments').insert({
              'payable_id': payable['id'],
              'cash_account_id': result['account'],
              'amount': result['amount'],
              'payment_date': dateOnly(DateTime.now()),
              'method': result['method'],
              'reference': result['reference'],
              'paid_by': session.userId,
            }),
          ),
        ),
      );
      if (saved == true && context.mounted) {
        showSnack(context, uiText(context, 'Payable payment recorded.'));
      }
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'Cash & expenses'),
      kpiKinds: const [
        KpiKind.cashBalance,
        KpiKind.todaySales,
        KpiKind.overdueReceivables,
      ],
      body: DefaultTabController(
        initialIndex: initialTabIndex,
        length: 8,
        child: Column(
          children: [
            if (recoveryNotice != null)
              MaterialBanner(
                content: Text(recoveryNotice!),
                actions: [
                  TextButton(
                    onPressed: onRecoveryDismiss,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            const _PendingCashNote(),
            const AppTabBar(
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
                          label: uiText(context, 'Create payable'),
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
                          label: uiText(context, 'Pay payable'),
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

class _PendingCashNote extends StatelessWidget {
  const _PendingCashNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              uiText(
                context,
                'Cash balance includes approved entries. Pending entries wait for approval.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePayableDialog extends StatefulWidget {
  const _CreatePayableDialog({required this.bill, required this.onSave});

  final Map<String, dynamic> bill;
  final Future<void> Function() onSave;

  @override
  State<_CreatePayableDialog> createState() => _CreatePayableDialogState();
}

class _CreatePayableDialogState extends State<_CreatePayableDialog> {
  bool _saving = false;
  Object? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Create payable')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          FriendlyErrorBox(error: _error!),
          const SizedBox(height: 12),
        ],
        Text(asText(widget.bill['description'], fallback: 'Bill')),
        const SizedBox(height: 8),
        Text(
          '${uiText(context, 'Amount')}: '
          '${formatMoney(widget.bill['amount'])}',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const LText('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(uiText(context, _saving ? 'Saving…' : 'Create payable')),
      ),
    ],
  );
}
