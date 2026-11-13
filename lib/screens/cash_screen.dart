import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/payment_dialog.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Cash & expenses',
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Balances'),
                Tab(text: 'Accounts'),
                Tab(text: 'Transactions'),
                Tab(text: 'Expenses'),
                Tab(text: 'Bills'),
                Tab(text: 'Bill payments'),
                Tab(text: 'Transfers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const CrudTab(
                    spec: _balancesSpec,
                    readPermission: 'cash.read',
                    alwaysReadOnly: true,
                  ),
                  const CrudTab(
                    spec: cashAccountsSpec,
                    readPermission: 'cash.read',
                    writePermission: 'cash.write',
                  ),
                  const CrudTab(
                    spec: _transactionsSpec,
                    readPermission: 'cash.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: expensesSpec,
                    readPermission: 'cash.read',
                    writePermission: 'cash.write',
                    actions: (row) {
                      if (row['status'] != 'pending' ||
                          !session.can('cash.approve')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) =>
                              _reviewExpense(session, row, true),
                        ),
                        CrudRowAction(
                          label: 'Reject',
                          icon: Icons.cancel_outlined,
                          danger: true,
                          onPressed: (row) =>
                              _reviewExpense(session, row, false),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: billsSpec,
                    readPermission: 'cash.read',
                    writePermission: 'cash.write',
                    actions: (row) {
                      final actions = <CrudRowAction>[];
                      final remaining =
                          asNum(row['amount']) - asNum(row['paid_amount']);
                      if (remaining > 0 && row['status'] != 'void') {
                        actions.add(
                          CrudRowAction(
                            label: 'Pay bill',
                            icon: Icons.payments_outlined,
                            onPressed: (row) => _payBill(session, row),
                          ),
                        );
                      }
                      if (row['status'] != 'void' &&
                          session.can('cash.approve')) {
                        actions.add(
                          CrudRowAction(
                            label: 'Void bill',
                            icon: Icons.cancel_outlined,
                            danger: true,
                            onPressed: (row) async {
                              final reason = await showInputDialog(
                                context,
                                title:
                                    'Void bill ${asText(row['bill_number'])}',
                                submitLabel: 'Void',
                                fields: const [
                                  InputField(
                                    'reason',
                                    'Reason',
                                    required: true,
                                    type: FieldType.multiline,
                                  ),
                                ],
                              );
                              if (reason == null) return;
                              await session.client.rpc(
                                'void_bill',
                                params: {
                                  'target_bill': row['id'],
                                  'reason': reason['reason'],
                                },
                              );
                              if (context.mounted) {
                                showSnack(context, 'Bill voided.');
                              }
                            },
                          ),
                        );
                      }
                      return actions;
                    },
                  ),
                  const CrudTab(
                    spec: _billPaymentsSpec,
                    readPermission: 'cash.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: cashTransfersSpec,
                    readPermission: 'cash.read',
                    writePermission: 'cash.write',
                    actions: (row) {
                      if (row['status'] != 'pending' ||
                          !session.can('cash.approve')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) =>
                              _reviewTransfer(session, row, true),
                        ),
                        CrudRowAction(
                          label: 'Reject',
                          icon: Icons.cancel_outlined,
                          danger: true,
                          onPressed: (row) =>
                              _reviewTransfer(session, row, false),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewExpense(
    AuthController session,
    Map<String, dynamic> expense,
    bool approve,
  ) async {
    final reason = await showInputDialog(
      context,
      title: approve ? 'Approve expense' : 'Reject expense',
      submitLabel: approve ? 'Approve' : 'Reject',
      fields: [
        InputField(
          'reason',
          approve ? 'Note (optional)' : 'Rejection reason',
          required: !approve,
          type: FieldType.multiline,
        ),
      ],
    );
    if (reason == null) return;
    try {
      final response = await session.client.rpc(
        'approve_expense',
        params: {
          'target_expense': expense['id'],
          'approve': approve,
          'review_reason': reason['reason'] ?? '',
        },
      );
      if (mounted) {
        await showInfoDialog(
          context,
          title: approve ? 'Expense approved' : 'Expense rejected',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _reviewTransfer(
    AuthController session,
    Map<String, dynamic> transfer,
    bool approve,
  ) async {
    try {
      final response = await session.client.rpc(
        'approve_cash_transfer',
        params: {
          'target_transfer': transfer['id'],
          'approve': approve,
          'review_reason': '',
        },
      );
      if (mounted) {
        await showInfoDialog(
          context,
          title: approve ? 'Transfer approved' : 'Transfer rejected',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _payBill(
    AuthController session,
    Map<String, dynamic> bill,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    final accounts = await repo.list('cash_accounts', orderBy: 'name');
    if (!mounted) return;
    if (accounts.isEmpty) {
      showSnack(context, 'Create a cash account first.', error: true);
      return;
    }
    final remaining = asNum(bill['amount']) - asNum(bill['paid_amount']);
    final payment = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentDialog(
        title: 'Pay ${asText(bill['bill_number'])}',
        accounts: accounts,
        defaultAmount: remaining,
      ),
    );
    if (payment == null) return;
    try {
      final response = await session.client.rpc(
        'pay_bill',
        params: {
          'target_bill': bill['id'],
          'target_account': payment['account_id'],
          'payment_amount': payment['amount'],
          'payment_method': payment['method'],
          'payment_reference': payment['reference'],
        },
      );
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Bill payment recorded',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _balancesSpec = TableSpec(
  table: 'cash_account_balances',
  title: 'Account balances',
  singular: 'Balance',
  orderBy: 'name',
  branchScoped: true,
  searchColumns: ['name', 'account_type'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('name', 'Account', list: true),
    FieldSpec(
      'account_type',
      'Type',
      type: FieldType.select,
      list: true,
      options: {'cash': 'Cash', 'bank': 'Bank', 'mobile_money': 'Mobile money'},
    ),
    FieldSpec('balance', 'Balance', type: FieldType.number, list: true),
  ],
);

const _transactionsSpec = TableSpec(
  table: 'cash_transactions',
  title: 'Cash transactions',
  singular: 'Cash transaction',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['category', 'method', 'notes'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('created_at', 'Date', type: FieldType.date, list: true),
    FieldSpec(
      'cash_account_id',
      'Account',
      type: FieldType.lookup,
      lookupTable: 'cash_accounts',
      list: true,
    ),
    FieldSpec(
      'direction',
      'Direction',
      type: FieldType.select,
      list: true,
      options: {'in': 'In', 'out': 'Out'},
    ),
    FieldSpec('category', 'Category', list: true),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
    FieldSpec('method', 'Method', list: true),
    FieldSpec('notes', 'Notes', list: true),
  ],
);

const _billPaymentsSpec = TableSpec(
  table: 'bill_payments',
  title: 'Bill payments',
  singular: 'Bill payment',
  orderBy: 'paid_at',
  ascending: false,
  branchScoped: false,
  searchColumns: ['reference'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('paid_at', 'Paid at', type: FieldType.date, list: true),
    FieldSpec('bill_id', 'Bill', list: true),
    FieldSpec(
      'cash_account_id',
      'Account',
      type: FieldType.lookup,
      lookupTable: 'cash_accounts',
      list: true,
    ),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
    FieldSpec('method', 'Method', list: true),
    FieldSpec('reference', 'Reference', list: true),
  ],
);
