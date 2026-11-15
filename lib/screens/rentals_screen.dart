import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class RentalsScreen extends StatelessWidget {
  const RentalsScreen({super.key});

  Future<void> _generateInvoices(
    BuildContext context,
    AuthController session,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: uiText(context, 'Generate rent invoices?'),
      message: uiText(
        context,
        'The database will create invoices for active leases for today.',
      ),
      confirmLabel: 'Generate',
    );
    if (!confirmed) return;
    try {
      await session.client.rpc(
        'fn_generate_rent_invoices',
        params: {'p_date': dateOnly(DateTime.now())},
      );
      if (context.mounted) showSnack(context, 'Rent invoices generated.');
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  Future<void> _recordPayment(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> invoice,
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
        throw Exception('Create a cash account before recording rent.');
      }
      if (!context.mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            _RentPaymentDialog(invoice: invoice, accounts: accounts),
      );
      if (result == null) return;
      await session.client.from('rent_payments').insert({
        'invoice_id': invoice['id'],
        'cash_account_id': result['account'],
        'amount': result['amount'],
        'payment_date': dateOnly(DateTime.now()),
        'method': result['method'],
        'reference': result['reference'],
        'received_by': session.userId,
      });
      if (context.mounted) showSnack(context, 'Rent payment recorded.');
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
      title: uiText(context, 'Rentals'),
      actions: [
        if (session.can('rentals.manage'))
          IconButton(
            tooltip: AppLocalizations.of(context).generateInvoices,
            onPressed: () => _generateInvoices(context, session),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
      ],
      body: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Properties'),
                Tab(text: 'Tenants'),
                Tab(text: 'Leases'),
                Tab(text: 'Rent invoices'),
                Tab(text: 'Rent payments'),
                Tab(text: 'Maintenance'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('properties'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
                  ),
                  CrudTab(
                    spec: specFor('tenants'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
                  ),
                  CrudTab(
                    spec: specFor('leases'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
                  ),
                  CrudTab(
                    spec: specFor('rent_invoices'),
                    readPermission: 'rentals.manage',
                    alwaysReadOnly: true,
                    actions: (row) {
                      if (!session.can('rentals.manage') ||
                          asNum(row['amount']) <= asNum(row['paid_amount'])) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: uiText(context, 'Record rent'),
                          icon: Icons.payments_outlined,
                          onPressed: (row) =>
                              _recordPayment(context, session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('rent_payments'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
                  ),
                  CrudTab(
                    spec: specFor('maintenance_requests'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
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

class _RentPaymentDialog extends StatefulWidget {
  const _RentPaymentDialog({required this.invoice, required this.accounts});

  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> accounts;

  @override
  State<_RentPaymentDialog> createState() => _RentPaymentDialogState();
}

class _RentPaymentDialogState extends State<_RentPaymentDialog> {
  late final _amount = TextEditingController(
    text:
        (asNum(widget.invoice['amount']) - asNum(widget.invoice['paid_amount']))
            .toStringAsFixed(2),
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
    title: Text('Rent for ${widget.invoice['invoice_no']}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _account,
          decoration: InputDecoration(
            labelText: uiText(context, 'Cash account'),
          ),
          items: [
            for (final account in widget.accounts)
              DropdownMenuItem(
                value: account['id'] as String,
                child: Text(asText(account['name'])),
              ),
          ],
          onChanged: (value) => setState(() => _account = value ?? _account),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: uiText(context, 'Amount')),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(labelText: uiText(context, 'Method')),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
            DropdownMenuItem(value: 'telebirr', child: Text('Telebirr')),
            DropdownMenuItem(value: 'cbe_birr', child: Text('CBE Birr')),
            DropdownMenuItem(
              value: 'mobile_money',
              child: Text('Mobile money'),
            ),
          ],
          onChanged: (value) => setState(() => _method = value ?? 'cash'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reference,
          decoration: InputDecoration(labelText: uiText(context, 'Reference')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const LText('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop({
          'account': _account,
          'amount': asNum(_amount.text),
          'method': _method,
          'reference': _reference.text.trim(),
        }),
        child: const LText('Record rent'),
      ),
    ],
  );
}
