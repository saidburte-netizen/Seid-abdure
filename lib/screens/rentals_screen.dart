import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../data/save_flow.dart';
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
      await SaveFlow.write(
        module: 'Rentals',
        target: 'fn_generate_rent_invoices',
        action: () => session.client.rpc(
          'fn_generate_rent_invoices',
          params: {'p_date': dateOnly(DateTime.now())},
        ),
      );
      if (context.mounted) showSnack(context, 'Rent invoices generated');
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
      Map<String, dynamic>? saved;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RentPaymentDialog(
          invoice: invoice,
          accounts: accounts,
          onSubmit: (result) async {
            saved = Map<String, dynamic>.from(
              await SaveFlow.write(
                module: 'Rentals',
                target: 'rent_payments',
                action: () => session.client
                    .from('rent_payments')
                    .insert({
                      'invoice_id': invoice['id'],
                      'cash_account_id': result['account'],
                      'amount': result['amount'],
                      'payment_date': result['date'],
                      'method': result['method'],
                      if (asText(result['reference']).isNotEmpty)
                        'reference': result['reference'],
                      'received_by': session.userId,
                    })
                    .select()
                    .single(),
              ),
            );
          },
        ),
      );
      if (ok == true && context.mounted) {
        showSnack(context, uiText(context, 'Rent payment recorded.'));
        if (saved != null) {
          final fresh = await session.client
              .from('rent_invoices')
              .select()
              .eq('id', invoice['id'])
              .maybeSingle();
          if (!context.mounted) return;
          await _showReceipt(
            context,
            session,
            fresh == null ? invoice : Map<String, dynamic>.from(fresh),
            saved!,
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  Future<void> _showReceipt(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> invoice,
    Map<String, dynamic> payment,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    String address = '';
    try {
      final row = await session.client
          .from('branches')
          .select('address')
          .eq('id', branch.branchId)
          .maybeSingle();
      address = asText(row?['address']);
    } catch (_) {
      // A missing address must not block the receipt.
    }
    if (!context.mounted) return;
    final bytes = await BrandPdf.document(
      title: uiText(context, 'Rent payment receipt'),
      documentNumber: asText(payment['id']).split('-').first,
      branchName: branch.branchName,
      subtitle: address,
      details: [
        ('Tenant', asText(invoice['tenant_name'])),
        ('Property', asText(invoice['property_name'])),
        (
          'Period',
          '${formatDate(invoice['period_start'])} – ${formatDate(invoice['period_end'])}',
        ),
        ('Amount', formatMoney(payment['amount'])),
        (
          'Balance',
          formatMoney(asNum(invoice['amount']) - asNum(invoice['paid_amount'])),
        ),
        ('Date', formatDate(payment['payment_date'])),
        ('Reference', asText(payment['reference'])),
      ],
      columns: const [
        PdfColumn('Description', 'description'),
        PdfColumn('Amount', 'amount', numeric: true),
      ],
      rows: [
        {
          'description': 'Rent for ${asText(invoice['invoice_no'])}',
          'amount': asNum(payment['amount']),
        },
      ],
      note: 'Thank you for your payment.',
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiText(context, 'Rent payment recorded.')),
        content: Text(
          '${uiText(context, 'Amount')}: ${formatMoney(payment['amount'])}\n'
          '${uiText(context, 'Balance')}: '
          '${formatMoney(asNum(invoice['amount']) - asNum(invoice['paid_amount']))}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiText(context, 'Close')),
          ),
          FilledButton.icon(
            onPressed: () => BrandPdf.share(
              fileName:
                  'rent_payment_${asText(payment['id']).split('-').first}',
              bytes: bytes,
            ),
            icon: const Icon(Icons.share_outlined),
            label: Text(uiText(context, 'Share receipt')),
          ),
        ],
      ),
    );
  }

  Future<void> _newInvoice(BuildContext context, AuthController session) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    try {
      final leases = await repo.list(
        'leases',
        orderBy: 'created_at',
        ascending: false,
      );
      if (leases.isEmpty) {
        if (context.mounted) {
          showSnack(
            context,
            uiText(context, 'Create a lease before adding an invoice.'),
            error: true,
          );
        }
        return;
      }
      if (!context.mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _NewInvoiceDialog(
          session: session,
          leases: leases,
          onCreate: (values) => SaveFlow.write(
            module: 'Rentals',
            target: 'rent_invoices',
            action: () => session.client.from('rent_invoices').insert(values),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _showInvoiceHistory(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> invoice,
  ) async {
    List<Map<String, dynamic>> payments = const [];
    try {
      final rows = await session.client
          .from('rent_payments')
          .select()
          .eq('invoice_id', invoice['id'])
          .order('payment_date', ascending: false);
      payments = [for (final row in rows) Map<String, dynamic>.from(row)];
    } catch (error) {
      if (context.mounted) showFriendlyError(context, error);
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiText(context, 'Payment history')),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${uiText(context, 'Invoice')}: '
                  '${asText(invoice['invoice_no'])}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${uiText(context, 'Balance')}: '
                  '${formatMoney(asNum(invoice['amount']) - asNum(invoice['paid_amount']))}',
                ),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Text(uiText(context, 'No payments yet.'))
                else
                  for (final payment in payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatMoney(payment['amount'])),
                      subtitle: Text(
                        '${formatDate(payment['payment_date'])} · '
                        '${uiText(context, prettyLabel(asText(payment['method'])))}'
                        '${asText(payment['reference']).isEmpty ? '' : '\n${asText(payment['reference'])}'}',
                      ),
                      trailing: IconButton(
                        tooltip: uiText(context, 'Share receipt'),
                        onPressed: () =>
                            _showReceipt(context, session, invoice, payment),
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiText(context, 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _tenantStatement(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> tenant,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    try {
      final invoices = await session.client
          .from('rent_invoices')
          .select()
          .eq('tenant_id', tenant['id'])
          .order('due_date', ascending: true);
      final rows = [for (final row in invoices) Map<String, dynamic>.from(row)];
      final total = rows.fold<num>(
        0,
        (sum, row) => sum + asNum(row['amount']) - asNum(row['paid_amount']),
      );
      final overdue = rows
          .where(
            (row) =>
                asNum(row['amount']) > asNum(row['paid_amount']) &&
                DateTime.tryParse(
                      asText(row['due_date']),
                    )?.isBefore(DateTime.now()) ==
                    true,
          )
          .fold<num>(
            0,
            (sum, row) =>
                sum + asNum(row['amount']) - asNum(row['paid_amount']),
          );
      if (!context.mounted) return;
      final bytes = await BrandPdf.document(
        title: uiText(context, 'Tenant statement'),
        documentNumber: dateOnly(DateTime.now()),
        branchName: branch.branchName,
        subtitle: asText(tenant['full_name']),
        details: [
          ('Total due', formatMoney(total)),
          ('Overdue', formatMoney(overdue)),
        ],
        columns: const [
          PdfColumn('Invoice', 'invoice_no'),
          PdfColumn('Due date', 'due_date'),
          PdfColumn('Amount', 'amount', numeric: true),
          PdfColumn('Balance', 'balance', numeric: true),
        ],
        rows: [
          for (final row in rows)
            {
              'invoice_no': row['invoice_no'],
              'due_date': row['due_date'],
              'amount': row['amount'],
              'balance': asNum(row['amount']) - asNum(row['paid_amount']),
            },
        ],
        note: 'This statement is generated from the rent ledger.',
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(uiText(context, 'Tenant statement')),
          content: Text(
            '${uiText(context, 'Total due')}: ${formatMoney(total)}\n'
            '${uiText(context, 'Overdue')}: ${formatMoney(overdue)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(uiText(context, 'Close')),
            ),
            FilledButton.icon(
              onPressed: () =>
                  BrandPdf.share(fileName: 'tenant_statement', bytes: bytes),
              icon: const Icon(Icons.share_outlined),
              label: Text(uiText(context, 'Share statement')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'Rentals'),
      kpiKinds: const [KpiKind.rentDue, KpiKind.overdueReceivables],
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
            const AppTabBar(
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
                    actions: (row) => [
                      CrudRowAction(
                        label: uiText(context, 'Statement'),
                        icon: Icons.description_outlined,
                        onPressed: (row) =>
                            _tenantStatement(context, session, row),
                      ),
                    ],
                  ),
                  CrudTab(
                    spec: specFor('leases'),
                    readPermission: 'rentals.manage',
                    writePermission: 'rentals.manage',
                  ),
                  _InvoicesTab(
                    session: session,
                    onNewInvoice: () => _newInvoice(context, session),
                    onReceivePayment: (invoice) =>
                        _recordPayment(context, session, invoice),
                    onHistory: (invoice) =>
                        _showInvoiceHistory(context, session, invoice),
                  ),
                  _PaymentsTab(
                    session: session,
                    onReceipt: (invoice, payment) =>
                        _showReceipt(context, session, invoice, payment),
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

class _InvoiceData {
  const _InvoiceData({required this.invoices, required this.tenants});

  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> tenants;
}

class _InvoicesTab extends StatefulWidget {
  const _InvoicesTab({
    required this.session,
    required this.onNewInvoice,
    required this.onReceivePayment,
    required this.onHistory,
  });

  final AuthController session;
  final Future<void> Function() onNewInvoice;
  final void Function(Map<String, dynamic> invoice) onReceivePayment;
  final void Function(Map<String, dynamic> invoice) onHistory;

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  Future<_InvoiceData>? _future;
  String? _status;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    DataRevision.notifier.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DataRevision.notifier.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<_InvoiceData> _load() async {
    final invoices = await widget.session.client
        .from('rent_invoices')
        .select()
        .order('due_date', ascending: false);
    final tenants = await widget.session.client
        .from('tenants')
        .select()
        .order('full_name');
    return _InvoiceData(
      invoices: [for (final row in invoices) Map<String, dynamic>.from(row)],
      tenants: [for (final row in tenants) Map<String, dynamic>.from(row)],
    );
  }

  String _statusOf(Map<String, dynamic> row) {
    final balance = asNum(row['amount']) - asNum(row['paid_amount']);
    if (balance <= 0.001) return 'paid';
    final due = DateTime.tryParse(asText(row['due_date']));
    if (due != null &&
        due.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )) {
      return 'overdue';
    }
    if (asNum(row['paid_amount']) > 0) return 'partial';
    final stored = asText(row['status']).toLowerCase();
    return stored.isEmpty ? 'unpaid' : stored;
  }

  String _tenantName(_InvoiceData data, Object? id) {
    for (final tenant in data.tenants) {
      if (tenant['id'] == id) return asText(tenant['full_name']);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InvoiceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: friendlyMessage(snapshot.error!),
            onRetry: () async => _reload(),
          );
        }
        final data = snapshot.data!;
        final rows = data.invoices.where((invoice) {
          if (_status != null && _statusOf(invoice) != _status) return false;
          if (_tenantId != null &&
              invoice['tenant_id']?.toString() != _tenantId) {
            return false;
          }
          return true;
        }).toList();
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        uiText(context, 'Rent invoices'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onNewInvoice,
                      icon: const Icon(Icons.add),
                      label: Text(uiText(context, 'New invoice')),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final entry in const [
                      (null, 'All'),
                      ('unpaid', 'Unpaid'),
                      ('partial', 'Partial'),
                      ('paid', 'Paid'),
                      ('overdue', 'Overdue'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(uiText(context, entry.$2)),
                          selected: _status == entry.$1,
                          onSelected: (_) => setState(() => _status = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: DropdownButtonFormField<String?>(
                  initialValue: _tenantId,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Tenant'),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(uiText(context, 'All tenants')),
                    ),
                    for (final tenant in data.tenants)
                      DropdownMenuItem<String?>(
                        value: tenant['id']?.toString(),
                        child: Text(asText(tenant['full_name'])),
                      ),
                  ],
                  onChanged: (value) => setState(() => _tenantId = value),
                ),
              ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: EmptyView(
                    message: uiText(
                      context,
                      'No invoices match these filters.',
                    ),
                  ),
                )
              else
                for (final invoice in rows)
                  _InvoiceCard(
                    invoice: invoice,
                    tenant: _tenantName(data, invoice['tenant_id']),
                    status: _statusOf(invoice),
                    onPay: () => widget.onReceivePayment(invoice),
                    onHistory: () => widget.onHistory(invoice),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.tenant,
    required this.status,
    required this.onPay,
    required this.onHistory,
  });

  final Map<String, dynamic> invoice;
  final String tenant;
  final String status;
  final VoidCallback onPay;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final balance = asNum(invoice['amount']) - asNum(invoice['paid_amount']);
    final danger = status == 'overdue';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asText(invoice['invoice_no']),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: danger ? scheme.errorContainer : null,
                  label: Text(
                    uiText(context, prettyLabel(status)),
                    style: danger ? TextStyle(color: scheme.error) : null,
                  ),
                ),
              ],
            ),
            if (tenant.isNotEmpty) Text(tenant),
            Text(
              '${uiText(context, 'Due date')}: ${formatDate(invoice['due_date'])}',
              style: danger ? TextStyle(color: scheme.error) : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${uiText(context, 'Amount')}: ${formatMoney(invoice['amount'])}',
                  ),
                ),
                Text(
                  '${uiText(context, 'Balance')}: ${formatMoney(balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: danger ? scheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (balance > 0.001)
                  FilledButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(uiText(context, 'Receive payment')),
                  ),
                OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                  label: Text(uiText(context, 'Payment history')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({required this.session, required this.onReceipt});

  final AuthController session;
  final void Function(
    Map<String, dynamic> invoice,
    Map<String, dynamic> payment,
  )
  onReceipt;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  Future<List<Map<String, dynamic>>>? _future;
  Map<String, Map<String, dynamic>> _invoices = {};

  @override
  void initState() {
    super.initState();
    DataRevision.notifier.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    DataRevision.notifier.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final invoices = await widget.session.client.from('rent_invoices').select();
    _invoices = {
      for (final row in invoices)
        row['id'].toString(): Map<String, dynamic>.from(row),
    };
    final payments = await widget.session.client
        .from('rent_payments')
        .select()
        .order('payment_date', ascending: false);
    return [for (final row in payments) Map<String, dynamic>.from(row)];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: friendlyMessage(snapshot.error!),
            onRetry: () async => _reload(),
          );
        }
        final payments = snapshot.data ?? const [];
        if (payments.isEmpty) {
          return EmptyView(message: uiText(context, 'No payments yet.'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            for (final payment in payments)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.payments_outlined),
                  ),
                  title: Text(formatMoney(payment['amount'])),
                  subtitle: Text(
                    '${formatDate(payment['payment_date'])} · '
                    '${uiText(context, prettyLabel(asText(payment['method'])))}'
                    '${asText(payment['reference']).isEmpty ? '' : '\n${asText(payment['reference'])}'}',
                  ),
                  trailing: IconButton(
                    tooltip: uiText(context, 'Share receipt'),
                    onPressed: () {
                      final invoice =
                          _invoices[payment['invoice_id']?.toString()];
                      if (invoice != null) {
                        widget.onReceipt(invoice, payment);
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NewInvoiceDialog extends StatefulWidget {
  const _NewInvoiceDialog({
    required this.session,
    required this.leases,
    required this.onCreate,
  });

  final AuthController session;
  final List<Map<String, dynamic>> leases;
  final Future<void> Function(Map<String, dynamic> values) onCreate;

  @override
  State<_NewInvoiceDialog> createState() => _NewInvoiceDialogState();
}

class _NewInvoiceDialogState extends State<_NewInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _leaseId;
  DateTime _dueDate = DateTime.now();
  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now();
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.leases.isNotEmpty) _selectLease(widget.leases.first);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _selectLease(Map<String, dynamic> lease) {
    _leaseId = lease['id']?.toString();
    _amount.text = asNum(lease['rent_amount']).toStringAsFixed(2);
    _periodStart =
        DateTime.tryParse(asText(lease['start_date'])) ?? DateTime.now();
    _periodEnd = DateTime.tryParse(asText(lease['end_date'])) ?? DateTime.now();
    _dueDate = _periodStart;
  }

  Future<void> _pickDate(DateTime current, ValueChanged<DateTime> apply) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => apply(picked));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final lease = widget.leases.firstWhere(
      (row) => row['id']?.toString() == _leaseId,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onCreate({
        'lease_id': lease['id'],
        'tenant_id': lease['tenant_id'],
        'property_id': lease['property_id'],
        'period_start': dateOnly(_periodStart),
        'period_end': dateOnly(_periodEnd),
        'amount': num.tryParse(_amount.text.trim()) ?? 0,
        'paid_amount': 0,
        'due_date': dateOnly(_dueDate),
        'status': 'unpaid',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, 'New invoice')),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _leaseId,
                  decoration: InputDecoration(
                    labelText: '${uiText(context, 'Lease')} *',
                  ),
                  items: [
                    for (final lease in widget.leases)
                      DropdownMenuItem(
                        value: lease['id'].toString(),
                        child: Text(
                          '${asText(lease['lease_no']).isEmpty ? uiText(context, 'Lease') : asText(lease['lease_no'])} · '
                          '${formatMoney(lease['rent_amount'])}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    final lease = widget.leases.firstWhere(
                      (row) => row['id']?.toString() == value,
                    );
                    setState(() => _selectLease(lease));
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${uiText(context, 'Amount')} *',
                  ),
                  validator: (value) {
                    final amount = num.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return uiText(context, 'Enter an amount greater than 0.');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _DateTile(
                  label: uiText(context, 'Period start'),
                  value: _periodStart,
                  onTap: () =>
                      _pickDate(_periodStart, (value) => _periodStart = value),
                ),
                _DateTile(
                  label: uiText(context, 'Period end'),
                  value: _periodEnd,
                  onTap: () =>
                      _pickDate(_periodEnd, (value) => _periodEnd = value),
                ),
                _DateTile(
                  label: uiText(context, 'Due date'),
                  value: _dueDate,
                  onTap: () => _pickDate(_dueDate, (value) => _dueDate = value),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(uiText(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(
            _saving ? uiText(context, 'Saving…') : uiText(context, 'Save'),
          ),
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(formatDate(value)),
      onTap: onTap,
    );
  }
}

class _RentPaymentDialog extends StatefulWidget {
  const _RentPaymentDialog({
    required this.invoice,
    required this.accounts,
    required this.onSubmit,
  });

  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic> payment) onSubmit;

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
  late String _account = _defaultAccount(widget.accounts);
  String _method = 'cash';

  String _defaultAccount(List<Map<String, dynamic>> accounts) {
    for (final account in accounts) {
      if (asText(account['name']).toLowerCase() == 'cash drawer') {
        return account['id'].toString();
      }
    }
    return accounts.first['id'].toString();
  }

  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  num get _balance =>
      asNum(widget.invoice['amount']) - asNum(widget.invoice['paid_amount']);

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _setMethod(String method) {
    setState(() {
      _method = method;
      final needle = switch (method) {
        'bank' => 'bank',
        'telebirr' => 'telebirr',
        'cbe_birr' => 'cbe',
        'mobile_money' => 'mobile',
        _ => 'cash',
      };
      for (final account in widget.accounts) {
        final haystack =
            '${asText(account['name'])} '
                    '${asText(account['account_type'])}'
                .toLowerCase();
        if (haystack.contains(needle)) {
          _account = account['id'].toString();
          break;
        }
      }
    });
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(
        () => _error = uiText(context, 'Enter an amount greater than 0.'),
      );
      return;
    }
    if (amount > _balance + 0.001) {
      setState(
        () => _error =
            '${uiText(context, 'Amount is more than the balance')}: '
            '${formatMoney(_balance)}',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'account': _account,
        'amount': amount,
        'method': _method,
        'reference': _reference.text.trim(),
        'date': dateOnly(_date),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyMessage(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Receive payment')),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${uiText(context, 'Rent for')} ${asText(widget.invoice['invoice_no'])}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${uiText(context, 'Balance')}: ${formatMoney(_balance)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: uiText(context, 'Amount'),
                helperText: uiText(context, 'Default is the full balance'),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(uiText(context, 'Payment date')),
              subtitle: Text(formatDate(_date)),
              onTap: _saving ? null : _pickDate,
            ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(labelText: uiText(context, 'Method')),
              items: [
                DropdownMenuItem(
                  value: 'cash',
                  child: Text(uiText(context, 'Cash')),
                ),
                DropdownMenuItem(
                  value: 'bank',
                  child: Text(uiText(context, 'Bank transfer')),
                ),
                DropdownMenuItem(
                  value: 'telebirr',
                  child: Text(uiText(context, 'Telebirr')),
                ),
                DropdownMenuItem(
                  value: 'cbe_birr',
                  child: Text(uiText(context, 'CBE Birr')),
                ),
              ],
              onChanged: (value) => _setMethod(value ?? 'cash'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _account,
              isExpanded: true,
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
              onChanged: (value) =>
                  setState(() => _account = value ?? _account),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: uiText(context, 'Reference (optional)'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: Text(uiText(context, 'Cancel')),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(
          _saving
              ? uiText(context, 'Saving…')
              : uiText(context, 'Receive payment'),
        ),
      ),
    ],
  );
}
