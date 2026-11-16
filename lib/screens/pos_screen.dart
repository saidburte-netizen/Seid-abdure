import '../core/events/data_revision.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../data/sale_math.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _paid = TextEditingController();
  final _notes = TextEditingController();
  final _cart = <String, num>{};
  final _products = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _stores = const [];
  List<Map<String, dynamic>> _accounts = const [];
  String? _customerId;
  String? _storeId;
  String? _accountId;
  String _method = 'cash';
  String _query = '';
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _discount.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    try {
      final products = await repo.list(
        'products',
        equals: {'is_active': true},
        orderBy: 'name',
        branchScoped: false,
      );
      final customers = await repo.list(
        'customers',
        equals: {'is_active': true},
        orderBy: 'full_name',
        branchScoped: false,
      );
      final stores = await repo.list(
        'stores',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      final accounts = await repo.list(
        'cash_accounts',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addEntries(
            products.map((row) => MapEntry(row['id'] as String, row)),
          );
        _customers = customers;
        _stores = stores;
        _accounts = accounts;
        _storeId = stores.isEmpty ? null : stores.first['id'] as String;
        _accountId = accounts.isEmpty ? null : accounts.first['id'] as String;
        _loading = false;
      });
      _setPaidToTotal();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = readableError(context, error);
        });
      }
    }
  }

  SaleTotals get _totals => computeSaleTotals([
        for (final entry in _cart.entries)
          SaleLineInput(
            price: asNum(_products[entry.key]?['price']),
            quantity: entry.value,
            taxRate: asNum(_products[entry.key]?['tax_rate']),
          ),
      ], discount: asNum(_discount.text));

  num get _subtotal => _totals.subtotal;

  num get _discountValue => _totals.discount;

  num get _tax => _totals.tax;

  num get _total => _totals.total;

  void _setPaidToTotal() {
    _paid.text = _subtotal == 0 ? '' : _total.toStringAsFixed(2);
  }

  void _add(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
    _setPaidToTotal();
  }

  void _change(String id, num delta) {
    final next = (_cart[id] ?? 0) + delta;
    setState(() {
      if (next <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = next;
      }
    });
    _setPaidToTotal();
  }

  void _clear() {
    setState(() {
      _cart.clear();
      _discount.text = '0';
      _notes.clear();
      _customerId = null;
      _method = 'cash';
    });
    _setPaidToTotal();
  }

  Future<String> _nextReceipt() async {
    final session = SessionScope.of(context);
    try {
      final value = await session.client.rpc(
        'next_number',
        params: {'p_prefix': 'SALE'},
      );
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) return text;
    } catch (_) {
      // Fall back to a timestamp receipt number if numbering is unavailable.
    }
    return 'SALE-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _complete() async {
    if (_cart.isEmpty) {
      showSnack(context, 'Add at least one product to the sale');
      DataRevision.bump();
      return;
    }
    if (_storeId == null) {
      showSnack(context, 'Create a store before selling');
      DataRevision.bump();
      return;
    }
    if (_method != 'credit' && _accountId == null) {
      showSnack(context, 'Create a cash account before selling');
      DataRevision.bump();
      return;
    }
    if (_method == 'credit' && _customerId == null) {
      showSnack(context, 'Choose a customer for a credit sale.', error: true);
      return;
    }
    final tendered = asNum(_paid.text);
    if (_method != 'credit' && tendered + 0.001 < _total) {
      showSnack(context, 'Payment does not cover the total.', error: true);
      return;
    }
    final paid =
        _method == 'credit' ? 0 : (tendered > _total ? _total : tendered);
    final confirmed = await confirmAction(
      context,
      title: uiText(context, 'Complete sale'),
      message: 'Charge ${formatMoney(_total)} and issue a receipt?',
      confirmLabel: 'Complete',
    );
    if (!confirmed || !mounted) return;

    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    setState(() => _submitting = true);
    try {
      final receiptNo = await _nextReceipt();
      final totals = _totals;
      final subtotal = totals.subtotal;
      final discount = totals.discount;
      final tax = totals.tax;
      final total = totals.total;
      final sale = await session.client
          .from('sales')
          .insert({
            'receipt_no': receiptNo,
            'branch_id': branch.branchId,
            'store_id': _storeId,
            'customer_id': _customerId,
            'cashier_id': session.userId,
            'sale_date': dateOnly(DateTime.now()),
            'subtotal': subtotal,
            'discount_amount': discount,
            'tax_amount': tax,
            'total_amount': total,
            'paid_amount': paid,
            'payment_status': paid >= total
                ? 'paid'
                : paid > 0
                    ? 'partial'
                    : _method == 'credit'
                        ? 'credit'
                        : 'unpaid',
            'status': 'completed',
            'notes': _notes.text.trim(),
          })
          .select()
          .single();
      final saleId = sale['id'] as String;
      final items = <Map<String, dynamic>>[];
      var lineIndex = 0;
      for (final entry in _cart.entries) {
        final product = _products[entry.key]!;
        final line = totals.lines[lineIndex++];
        items.add({
          'sale_id': saleId,
          'product_id': entry.key,
          'product_name': product['name'],
          'quantity': entry.value,
          'unit_price': line.unitPrice,
          'discount_amount': 0,
          'tax_amount': line.taxAmount,
          'line_total': line.lineTotal,
        });
      }
      await session.client.from('sale_items').insert(items);
      if (_method == 'credit') {
        // The database trigger creates the receivable from this payment row.
        await session.client.from('sale_payments').insert({
          'sale_id': saleId,
          'cash_account_id': null,
          'method': 'credit',
          'amount': total,
          'reference': const Uuid().v4().substring(0, 8),
          'paid_at': nowIso(),
          'received_by': session.userId,
        });
      } else if (paid > 0) {
        await session.client.from('sale_payments').insert({
          'sale_id': saleId,
          'cash_account_id': _accountId,
          'method': _method,
          'amount': paid,
          'reference': const Uuid().v4().substring(0, 8),
          'paid_at': nowIso(),
          'received_by': session.userId,
        });
      }
      if (!mounted) return;
      await _showReceipt(
        sale: Map<String, dynamic>.from(sale),
        items: items,
        paid: paid,
      );
      _clear();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showReceipt({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required num paid,
  }) async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    final bytes = await BrandPdf.document(
      title: uiText(context, 'Sales receipt'),
      documentNumber: asText(sale['receipt_no']),
      branchName: branch?.branchName ?? 'Jimma branch',
      subtitle: formatDate(sale['sale_date']),
      details: [
        ('Customer', _customerName()),
        ('Cashier', session.fullName ?? session.userEmail ?? ''),
        (
          uiText(context, 'Payment method'),
          uiText(context, prettyLabel(_method)),
        ),
        ('Paid', formatMoney(paid)),
        ('Balance', formatMoney(asNum(sale['total_amount']) - paid)),
      ],
      columns: const [
        PdfColumn('Item', 'product_name'),
        PdfColumn('Qty', 'quantity', numeric: true),
        PdfColumn('Unit price', 'unit_price', numeric: true),
        PdfColumn('Tax', 'tax_amount', numeric: true),
        PdfColumn('Total', 'line_total', numeric: true),
      ],
      rows: items,
      note: 'Thank you for choosing Brade and Cake House.',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Sale completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Receipt', asText(sale['receipt_no'])),
            _row('Total', formatMoney(sale['total_amount'])),
            _row('Paid', formatMoney(paid)),
            _row('Balance', formatMoney(asNum(sale['total_amount']) - paid)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const LText('Close'),
          ),
          FilledButton.icon(
            onPressed: () => BrandPdf.share(
              fileName: 'receipt_${sale['receipt_no']}',
              bytes: bytes,
              subject: 'Brade and Cake House receipt',
            ),
            icon: const Icon(Icons.print_outlined),
            label: const LText('Receipt PDF'),
          ),
        ],
      ),
    );
  }

  String _customerName() {
    for (final customer in _customers) {
      if (customer['id'] == _customerId) {
        return asText(customer['full_name']);
      }
    }
    return 'Walk-in customer';
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final products = _products.values
        .where(
          (product) =>
              _query.isEmpty ||
              asText(product['name']).toLowerCase().contains(_query) ||
              asText(product['sku']).toLowerCase().contains(_query),
        )
        .toList();
    return ModuleScaffold(
      title: uiText(context, 'Point of sale'),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Clear cart'),
          onPressed: _cart.isEmpty ? null : _clear,
          icon: const Icon(Icons.remove_shopping_cart_outlined),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final catalog = _catalog(products);
                    final cart = _cartPanel(session);
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: catalog),
                              SizedBox(width: 380, child: cart),
                            ],
                          )
                        : DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                const TabBar(
                                  tabs: [
                                    Tab(text: 'Products'),
                                    Tab(text: 'Cart'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(children: [catalog, cart]),
                                ),
                              ],
                            ),
                          );
                  },
                ),
    );
  }

  Widget _catalog(List<Map<String, dynamic>> products) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: uiText(context, 'Search products'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? EmptyView(
                    message: uiText(
                      context,
                      'No active products. Add products in Production.',
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 150,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final qty = _cart[product['id']] ?? 0;
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _add(product),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        asText(product['name']),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    if (qty > 0) Badge(label: Text('$qty')),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  asText(product['sku']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatMoney(product['price']),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );

  Widget _cartPanel(AuthController session) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Current sale', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyView(
                icon: Icons.shopping_basket_outlined,
                message:
                    uiText(context, 'Tap a product to add it to the sale.'),
              ),
            )
          else
            for (final entry in _cart.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(asText(_products[entry.key]?['name'])),
                subtitle: Text(
                  '${formatMoney(_products[entry.key]?['price'])} × ${entry.value}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: uiText(context, 'Decrease quantity'),
                      onPressed: () => _change(entry.key, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${entry.value}'),
                    IconButton(
                      tooltip: uiText(context, 'Increase quantity'),
                      onPressed: () => _change(entry.key, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
          const Divider(),
          DropdownButtonFormField<String?>(
            initialValue: _customerId,
            decoration: InputDecoration(labelText: uiText(context, 'Customer')),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Walk-in')),
              for (final customer in _customers)
                DropdownMenuItem<String?>(
                  value: customer['id'] as String,
                  child: Text(asText(customer['full_name'])),
                ),
            ],
            onChanged: (value) => setState(() => _customerId = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _storeId,
            decoration: InputDecoration(labelText: uiText(context, 'Store')),
            items: [
              for (final store in _stores)
                DropdownMenuItem(
                  value: store['id'] as String,
                  child: Text(asText(store['name'])),
                ),
            ],
            onChanged: (value) => setState(() => _storeId = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(
              labelText: uiText(context, 'Payment method'),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
              DropdownMenuItem(value: 'telebirr', child: Text('Telebirr')),
              DropdownMenuItem(value: 'cbe_birr', child: Text('CBE Birr')),
              DropdownMenuItem(
                  value: 'mobile_money', child: Text('Mobile money')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'credit', child: Text('Credit')),
            ],
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          if (_method != 'credit') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: uiText(context, 'Cash account'),
              ),
              items: [
                for (final account in _accounts)
                  DropdownMenuItem(
                    value: account['id'] as String,
                    child: Text(asText(account['name'])),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _discount,
            decoration: InputDecoration(
              labelText: uiText(context, 'Discount (ETB)'),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(_setPaidToTotal),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _paid,
            decoration:
                InputDecoration(labelText: uiText(context, 'Amount paid')),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: InputDecoration(labelText: uiText(context, 'Notes')),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _totalRow('Subtotal', _subtotal),
          _totalRow('Discount', -_discountValue),
          _totalRow('Tax', _tax),
          const Divider(),
          _totalRow('Total', _total, bold: true),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submitting ? null : _complete,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_submitting ? 'Completing…' : 'Complete sale'),
          ),
        ],
      );

  Widget _totalRow(String label, num value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
              ),
            ),
            Text(
              formatMoney(value),
              style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
          ],
        ),
      );
}
