import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/payment_dialog.dart';

class PayablesScreen extends StatefulWidget {
  const PayablesScreen({super.key});

  @override
  State<PayablesScreen> createState() => _PayablesScreenState();
}

class _PayablesScreenState extends State<PayablesScreen> {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Payables & suppliers',
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Open bills'),
                Tab(text: 'Aging'),
                Tab(text: 'Suppliers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: _payablesSpec,
                    readPermission: 'payables.read',
                    alwaysReadOnly: true,
                    actions: (row) {
                      if (!session.can('payables.write')) return const [];
                      final balance = asNum(row['balance']);
                      if (balance <= 0 || row['status'] == 'void') return const [];
                      return [
                        CrudRowAction(
                          label: 'Pay supplier',
                          icon: Icons.payments_outlined,
                          onPressed: (row) => _payBill(session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: _agingSpec,
                    readPermission: 'payables.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: suppliersSpec,
                    readPermission: 'purchasing.read',
                    writePermission: 'purchasing.write',
                    actions: (row) {
                      if (!session.can('payables.read')) return const [];
                      return [
                        CrudRowAction(
                          label: 'Statement',
                          icon: Icons.receipt_long_outlined,
                          onPressed: (row) => _statement(session, row),
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

  Future<void> _payBill(
    AuthController session,
    Map<String, dynamic> payable,
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
    final payment = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentDialog(
        title: 'Pay ${asText(payable['bill_number'])}',
        accounts: accounts,
        defaultAmount: asNum(payable['balance']),
      ),
    );
    if (payment == null) return;
    try {
      final response = await session.client.rpc('record_supplier_payment', params: {
        'target_bill': payable['bill_id'],
        'target_account': payment['account_id'],
        'payment_amount': payment['amount'],
        'payment_method': payment['method'],
        'payment_reference': payment['reference'],
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Supplier payment recorded',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _statement(
    AuthController session,
    Map<String, dynamic> supplier,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year - 1, now.month, 1),
        end: now,
      ),
    );
    if (range == null) return;
    try {
      final response = await session.client.rpc('supplier_statement', params: {
        'target_branch': branch.branchId,
        'target_supplier': supplier['id'],
        'from_date': dateOnly(range.start),
        'to_date': dateOnly(range.end),
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Supplier statement — ${asText(supplier['name'])}',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _payablesSpec = TableSpec(
  table: 'supplier_payables',
  title: 'Supplier payables',
  singular: 'Payable',
  orderBy: 'due_date',
  ascending: true,
  branchScoped: true,
  searchColumns: ['supplier_name', 'bill_number', 'status', 'aging_bucket'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('supplier_name', 'Supplier', list: true),
    FieldSpec('bill_number', 'Bill', list: true),
    FieldSpec('issue_date', 'Issued', type: FieldType.date, list: true),
    FieldSpec('due_date', 'Due', type: FieldType.date, list: true),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
    FieldSpec('paid_amount', 'Paid', type: FieldType.number, list: true),
    FieldSpec('balance', 'Balance', type: FieldType.number, list: true),
    FieldSpec('days_overdue', 'Days overdue', type: FieldType.number, list: true),
    FieldSpec('aging_bucket', 'Aging', list: true),
    FieldSpec('status', 'Status', list: true),
  ],
);

const _agingSpec = TableSpec(
  table: 'supplier_aging',
  title: 'Supplier aging',
  singular: 'Supplier',
  orderBy: 'total_outstanding',
  ascending: false,
  branchScoped: true,
  searchColumns: ['supplier_name'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('supplier_name', 'Supplier', list: true),
    FieldSpec('open_bills', 'Open bills', type: FieldType.number, list: true),
    FieldSpec('current_amount', 'Current', type: FieldType.number, list: true),
    FieldSpec('days_1_30', '1–30 days', type: FieldType.number, list: true),
    FieldSpec('days_31_60', '31–60 days', type: FieldType.number, list: true),
    FieldSpec('days_61_90', '61–90 days', type: FieldType.number, list: true),
    FieldSpec('days_over_90', '90+ days', type: FieldType.number, list: true),
    FieldSpec('total_outstanding', 'Total', type: FieldType.number, list: true),
  ],
);
