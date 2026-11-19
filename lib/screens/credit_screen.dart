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
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PaymentDialog(
          title: type == 'receivable'
              ? 'Receive customer payment'
              : 'Pay supplier',
          accounts: accounts,
          maximum: asNum(row['balance']),
          methods: const [
            'cash',
            'bank',
            'telebirr',
            'cbe_birr',
            'mobile_money',
          ],
          onSave: (result) async {
            if (type == 'receivable') {
              await SaveFlow.write(
                module: 'Credit & debit control',
                target: 'receivable_payments',
                action: () =>
                    session.client.from('receivable_payments').insert({
                      'receivable_id': row['id'],
                      'cash_account_id': result['account'],
                      'amount': result['amount'],
                      'payment_date': dateOnly(DateTime.now()),
                      'method': result['method'],
                      'reference': result['reference'],
                      'received_by': session.userId,
                    }),
              );
            } else {
              await SaveFlow.write(
                module: 'Credit & debit control',
                target: 'payable_payments',
                action: () => session.client.from('payable_payments').insert({
                  'payable_id': row['id'],
                  'cash_account_id': result['account'],
                  'amount': result['amount'],
                  'payment_date': dateOnly(DateTime.now()),
                  'method': result['method'],
                  'reference': result['reference'],
                  'paid_by': session.userId,
                }),
              );
            }
          },
        ),
      );
      if (saved == true && context.mounted) {
        showSnack(context, 'Payment recorded');
      }
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
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
      title: uiText(context, 'Approve write-off?'),
      message: uiText(
        context,
        'The database trigger will reduce the receivable balance.',
      ),
      confirmLabel: uiText(context, 'Approve'),
    );
    if (!confirmed) return;
    try {
      await SaveFlow.write(
        module: 'Credit & debit control',
        target: 'write_offs',
        action: () => session.client
            .from('write_offs')
            .update({
              'status': 'approved',
              'approved_by': session.userId,
              'decided_at': nowIso(),
            })
            .eq('id', row['id']),
      );
      if (context.mounted) showSnack(context, 'Write-off approved.');
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
      title: uiText(context, 'Credit & debit control'),
      kpiKinds: const [KpiKind.overdueReceivables, KpiKind.cashBalance],
      body: DefaultTabController(
        length: 10,
        child: Column(
          children: [
            const AppTabBar(
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
                          label: uiText(context, 'Receive payment'),
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
                          label: uiText(context, 'Pay supplier'),
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
                          label: uiText(context, 'Approve write-off'),
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
