import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/payment_dialog.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Rentals & property',
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Rent roll'),
                Tab(text: 'Properties'),
                Tab(text: 'Units'),
                Tab(text: 'Leases'),
                Tab(text: 'Invoices'),
                Tab(text: 'Payments'),
                Tab(text: 'Maintenance'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: _rentRollSpec,
                    readPermission: 'rentals.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: propertiesSpec,
                    readPermission: 'rentals.read',
                    writePermission: 'rentals.write',
                  ),
                  CrudTab(
                    spec: unitsSpec,
                    readPermission: 'rentals.read',
                    writePermission: 'rentals.write',
                  ),
                  CrudTab(
                    spec: leasesSpec,
                    readPermission: 'rentals.read',
                    writePermission: 'rentals.write',
                  ),
                  CrudTab(
                    spec: _rentInvoicesSpec,
                    readPermission: 'rentals.read',
                    alwaysReadOnly: true,
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: session.can('rentals.write')
                              ? () => _generateInvoices(session)
                              : null,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Generate rent invoices'),
                        ),
                      ),
                    ),
                    actions: (row) {
                      final remaining = asNum(row['amount']) - asNum(row['paid_amount']);
                      if (remaining <= 0 ||
                          row['status'] == 'paid' ||
                          row['status'] == 'void' ||
                          !session.can('rentals.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Record payment',
                          icon: Icons.payments_outlined,
                          onPressed: (row) => _recordPayment(session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: _rentPaymentsSpec,
                    readPermission: 'rentals.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: maintenanceSpec,
                    readPermission: 'rentals.read',
                    writePermission: 'rentals.write',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvoices(AuthController session) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      ),
    );
    if (range == null) return;
    try {
      final response = await session.client.rpc('generate_rent_invoices', params: {
        'target_branch': branch.branchId,
        'target_period_start': dateOnly(range.start),
        'target_period_end': dateOnly(range.end),
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Rent invoices generated',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _recordPayment(
    AuthController session,
    Map<String, dynamic> invoice,
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
    final remaining = asNum(invoice['amount']) - asNum(invoice['paid_amount']);
    final payment = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PaymentDialog(
        title: 'Rent payment — ${asText(invoice['invoice_number'])}',
        accounts: accounts,
        defaultAmount: remaining,
      ),
    );
    if (payment == null) return;
    try {
      final response = await session.client.rpc('record_rent_payment', params: {
        'target_invoice': invoice['id'],
        'target_account': payment['account_id'],
        'payment_amount': payment['amount'],
        'payment_method': payment['method'],
        'payment_reference': payment['reference'],
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Rent payment recorded',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _rentRollSpec = TableSpec(
  table: 'rent_roll',
  title: 'Rent roll',
  singular: 'Lease',
  orderBy: 'property_name',
  branchScoped: true,
  searchColumns: ['property_name', 'unit_name', 'tenant_name', 'status'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('property_name', 'Property', list: true),
    FieldSpec('unit_name', 'Unit', list: true),
    FieldSpec('tenant_name', 'Tenant', list: true),
    FieldSpec('tenant_phone', 'Phone', list: true),
    FieldSpec('rent_amount', 'Rent', type: FieldType.number, list: true),
    FieldSpec('invoiced_total', 'Invoiced', type: FieldType.number, list: true),
    FieldSpec('collected_total', 'Collected', type: FieldType.number, list: true),
    FieldSpec('outstanding', 'Outstanding', type: FieldType.number, list: true),
    FieldSpec('status', 'Status', list: true),
  ],
);

const _rentInvoicesSpec = TableSpec(
  table: 'rent_invoices',
  title: 'Rent invoices',
  singular: 'Rent invoice',
  orderBy: 'due_date',
  ascending: true,
  searchColumns: ['invoice_number', 'status', 'notes'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('invoice_number', 'Invoice', list: true),
    FieldSpec('lease_id', 'Lease', type: FieldType.lookup, lookupTable: 'leases', lookupLabel: 'tenant_name', list: true),
    FieldSpec('period_start', 'Period start', type: FieldType.date, list: true),
    FieldSpec('period_end', 'Period end', type: FieldType.date, list: true),
    FieldSpec('due_date', 'Due date', type: FieldType.date, list: true),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
    FieldSpec('paid_amount', 'Paid', type: FieldType.number, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, list: true, options: {
      'unpaid': 'Unpaid', 'partial': 'Partial', 'paid': 'Paid', 'void': 'Void',
    }),
  ],
);

const _rentPaymentsSpec = TableSpec(
  table: 'rent_payments',
  title: 'Rent payments',
  singular: 'Rent payment',
  orderBy: 'paid_at',
  ascending: false,
  branchScoped: false,
  searchColumns: ['method', 'reference'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('paid_at', 'Paid at', type: FieldType.date, list: true),
    FieldSpec('rent_invoice_id', 'Invoice', type: FieldType.lookup, lookupTable: 'rent_invoices', lookupLabel: 'invoice_number', list: true),
    FieldSpec('cash_account_id', 'Account', type: FieldType.lookup, lookupTable: 'cash_accounts', list: true),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
    FieldSpec('method', 'Method', list: true),
    FieldSpec('reference', 'Reference', list: true),
  ],
);
