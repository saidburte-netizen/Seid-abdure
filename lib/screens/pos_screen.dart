import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/offline_queue.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../widgets/common.dart';

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
  final _customers = <Map<String, dynamic>>[];
  late BranchRepository _repo;
  Map<String, dynamic> _settings = const {};
  bool _started = false;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _customerId;
  String _method = 'cash';
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
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
    _repo = BranchRepository(session.client, branch.branchId);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _repo.list(
        'products',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      final customers = await _repo.list(
        'customers',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      final settings = await _repo.settings();
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addEntries(
            products.map((row) => MapEntry(row['id'] as String, row)),
          );
        _customers
          ..clear()
          ..addAll(customers);
        _settings = settings;
        _loading = false;
      });
      _setPaidToTotal();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = readableError(error);
        });
      }
    }
  }

  num get _subtotal {
    var total = 0.0;
    for (final entry in _cart.entries) {
      final product = _products[entry.key];
      if (product == null) continue;
      total +=
          ((asNum(product['selling_price']) * entry.value) * 100).round() / 100;
    }
    return total;
  }

  num get _discountValue {
    final value = asNum(_discount.text);
    return value < 0 ? 0 : (value > _subtotal ? _subtotal : value);
  }

  num get _serviceCharge {
    final rate = asNum(_settings['service_charge_rate']);
    return ((_subtotal - _discountValue) * rate * 100).round() / 100;
  }

  num get _tax {
    final rate = asNum(_settings['tax_rate']);
    final inclusive = asBool(_settings['tax_inclusive']);
    final base = _subtotal - _discountValue + _serviceCharge;
    if (inclusive) {
      return ((base - base / (1 + rate)) * 100).round() / 100;
    }
    return (base * rate * 100).round() / 100;
  }

  num get _total {
    if (asBool(_settings['tax_inclusive'])) {
      return _subtotal - _discountValue + _serviceCharge;
    }
    return _subtotal - _discountValue + _serviceCharge + _tax;
  }

  void _setPaidToTotal() {
    if (_subtotal == 0) {
      _paid.text = '';
    } else {
      _paid.text = _total.toStringAsFixed(2);
    }
  }

  void _add(Map<String, dynamic> product) {
    final id = product['id'] as String;
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
    _setPaidToTotal();
  }

  void _changeQuantity(String id, num delta) {
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

  List<Map<String, dynamic>> get _paymentRows => [
    {
      'method': _method,
      'amount': asNum(_paid.text) <= 0 ? _total : asNum(_paid.text),
      'reference': '',
    },
  ];

  Future<void> _complete() async {
    if (_cart.isEmpty) {
      showSnack(context, 'Add at least one product to the sale.');
      return;
    }
    if (_method == 'credit' && _customerId == null) {
      showSnack(context, 'Choose a customer for a credit sale.', error: true);
      return;
    }
    final paidAmount = asNum(_paid.text);
    if (paidAmount + 0.001 < _total) {
      showSnack(context, 'Payment does not cover the total.', error: true);
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Complete sale',
      message: 'Charge ${formatMoney(_total)} and issue a receipt?',
      confirmLabel: 'Complete',
    );
    if (!confirmed || !mounted) return;

    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    final items = [
      for (final entry in _cart.entries)
        {'product_id': entry.key, 'quantity': entry.value},
    ];
    final payments = _paymentRows;
    final discount = _discountValue;
    final notes = _notes.text.trim();
    setState(() => _submitting = true);
    try {
      final result = await session.client.rpc(
        'complete_sale',
        params: {
          'target_branch': branch.branchId,
          'sale_items': items,
          'sale_payments': payments,
          'target_customer': _customerId,
          'sale_discount': discount,
          'sale_notes': notes,
          'p_client_id': const Uuid().v4(),
        },
      );
      if (!mounted) return;
      await _showReceipt(asMap(result));
      _clear();
    } catch (error) {
      final message = readableError(error);
      final offlinePossible =
          _method != 'credit' &&
          (message.contains('Network') ||
              message.contains('Socket') ||
              message.contains('Failed host lookup') ||
              message.contains('Connection'));
      if (offlinePossible && mounted) {
        final saveOffline = await confirmAction(
          context,
          title: 'Connection unavailable',
          message:
              'Save this sale in the offline queue and sync it when the connection returns?',
          confirmLabel: 'Save offline',
        );
        if (saveOffline) {
          final queue = await OfflineQueue.create();
          await queue.enqueue(
            branchId: branch.branchId,
            items: items,
            payments: payments,
            customerId: _customerId,
            discount: discount,
            notes: notes,
          );
          if (mounted) {
            showSnack(context, 'Sale saved offline. It will sync later.');
            _clear();
          }
        }
      } else if (mounted) {
        showSnack(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showReceipt(Map<String, dynamic> result) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sale completed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _receiptRow('Sale number', asText(result['sale_number'])),
          _receiptRow('Receipt number', asText(result['receipt_number'])),
          _receiptRow('Subtotal', formatMoney(result['subtotal'])),
          _receiptRow('Discount', formatMoney(result['discount'])),
          _receiptRow('Service charge', formatMoney(result['service_charge'])),
          _receiptRow('Tax', formatMoney(result['tax_total'])),
          const Divider(),
          _receiptRow('Total', formatMoney(result['grand_total'])),
          _receiptRow('Paid', formatMoney(result['paid_total'])),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () => _shareReceipt(dialogContext, result),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF receipt'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _clear();
          },
          child: const Text('Next sale'),
        ),
      ],
    ),
  );

  Future<void> _shareReceipt(
    BuildContext dialogContext,
    Map<String, dynamic> result,
  ) async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    try {
      final bytes = await BrandPdf.document(
        title: 'Sales receipt',
        documentNumber: asText(result['receipt_number']),
        branchName: branch?.branchName ?? 'Main branch',
        subtitle: 'Payment confirmation',
        details: [
          ('Sale', asText(result['sale_number'])),
          ('Payment', _method.replaceAll('_', ' ').toUpperCase()),
          ('Cashier', session.fullName ?? session.userEmail ?? ''),
        ],
        columns: const [
          PdfColumn('Item', 'item'),
          PdfColumn('Qty', 'quantity', numeric: true),
          PdfColumn('Unit price', 'unit_price', numeric: true),
          PdfColumn('Line total', 'line_total', numeric: true),
        ],
        rows: [
          for (final entry in _cart.entries)
            if (_products[entry.key] != null)
              {
                'item': asText(_products[entry.key]!['name']),
                'quantity': entry.value,
                'unit_price': asNum(_products[entry.key]!['selling_price']),
                'line_total':
                    asNum(_products[entry.key]!['selling_price']) * entry.value,
              },
        ],
        totals: [
          ('Subtotal', formatMoney(result['subtotal'])),
          ('Discount', formatMoney(result['discount'])),
          ('Service charge', formatMoney(result['service_charge'])),
          ('Tax', formatMoney(result['tax_total'])),
          ('Total', formatMoney(result['grand_total'])),
          ('Paid', formatMoney(result['paid_total'])),
        ],
        note: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      await BrandPdf.share(
        fileName: 'receipt_${asText(result['receipt_number'])}',
        bytes: bytes,
        subject: 'Receipt ${asText(result['receipt_number'])}',
      );
      if (dialogContext.mounted) {
        showSnack(dialogContext, 'Receipt PDF ready to share.');
      }
    } catch (error) {
      if (dialogContext.mounted) {
        showSnack(dialogContext, readableError(error), error: true);
      }
    }
  }

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  List<Map<String, dynamic>> get _filteredProducts {
    final needle = _query.trim().toLowerCase();
    final rows = _products.values.toList()
      ..sort((a, b) => asText(a['name']).compareTo(asText(b['name'])));
    if (needle.isEmpty) return rows;
    return rows
        .where(
          (product) =>
              asText(product['name']).toLowerCase().contains(needle) ||
              asText(product['sku']).toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.can('sales.write')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Point of sale')),
        body: const EmptyView(
          icon: Icons.lock_outline,
          message: 'You do not have permission to take sales.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Point of sale'),
        actions: [
          IconButton(
            tooltip: 'Refresh catalogue',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _productsPane()),
                      SizedBox(width: 390, child: _cartPane(compact: false)),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(child: _productsPane()),
                    _mobileCartBar(),
                  ],
                );
              },
            ),
    );
  }

  Widget _productsPane() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Search products',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      Expanded(
        child: _filteredProducts.isEmpty
            ? const EmptyView(
                icon: Icons.bakery_dining_outlined,
                message: 'No active products found.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 700
                      ? 3
                      : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final id = product['id'] as String;
                      final inCart = _cart[id] ?? 0;
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
                                    if (inCart > 0)
                                      CircleAvatar(
                                        radius: 13,
                                        child: Text(
                                          formatQuantity(inCart),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  formatMoney(product['selling_price']),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                Text(
                                  asText(product['unit'], fallback: 'piece'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    ],
  );

  Widget _mobileCartBar() {
    final itemCount = _cart.values.fold<num>(0, (sum, value) => sum + value);
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$itemCount item(s) • ${formatMoney(_total)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Tax ${formatMoney(_tax)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _cart.isEmpty
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.85,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) => _cartPane(
                            compact: true,
                            scrollController: scrollController,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('Cart (${_cart.length})'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartPane({
    required bool compact,
    ScrollController? scrollController,
  }) {
    final content = ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Current sale',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: _cart.isEmpty ? null : _clear,
              child: const Text('Clear'),
            ),
          ],
        ),
        if (_cart.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyView(
              icon: Icons.shopping_basket_outlined,
              message: 'Tap a product to add it to the sale.',
            ),
          )
        else
          for (final entry in _cart.entries.toList())
            _CartLine(
              product: _products[entry.key]!,
              quantity: entry.value,
              onAdd: () => _add(_products[entry.key]!),
              onRemove: () => _changeQuantity(entry.key, -1),
              onDelete: () => setState(() => _cart.remove(entry.key)),
            ),
        const Divider(height: 28),
        DropdownButtonFormField<String>(
          initialValue: _customerId ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Customer (optional)'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Walk-in customer')),
            for (final customer in _customers)
              DropdownMenuItem(
                value: customer['id'] as String,
                child: Text(
                  '${asText(customer['name'])}'
                  '${asText(customer['phone']).isEmpty ? '' : ' • ${customer['phone']}'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(
            () => _customerId = (value == null || value.isEmpty) ? null : value,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _discount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Discount (ETB)'),
          onChanged: (_) {
            setState(() {});
            _setPaidToTotal();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'telebirr', child: Text('TeleBirr')),
            DropdownMenuItem(value: 'cbe_birr', child: Text('CBE Birr')),
            DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
            DropdownMenuItem(value: 'credit', child: Text('Customer credit')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _method = value);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _paid,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount paid (ETB)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Sale notes'),
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _totalRow('Subtotal', _subtotal),
        _totalRow('Discount', -_discountValue),
        _totalRow('Service charge', _serviceCharge),
        _totalRow('Tax', _tax),
        const Divider(),
        _totalRow('Total', _total, strong: true),
        if (asNum(_paid.text) > _total)
          _totalRow('Change', asNum(_paid.text) - _total),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _submitting || _cart.isEmpty ? null : _complete,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_submitting ? 'Completing…' : 'Complete sale'),
        ),
        if (compact) const SizedBox(height: 24),
      ],
    );
    return compact
        ? content
        : Card(
            margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: content,
          );
  }

  Widget _totalRow(String label, num value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
        ),
        Text(
          formatMoney(value),
          style: strong
              ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
              : null,
        ),
      ],
    ),
  );
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
  });

  final Map<String, dynamic> product;
  final num quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(asText(product['name'])),
    subtitle: Text(formatMoney(product['selling_price'])),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(formatQuantity(quantity)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );
}
