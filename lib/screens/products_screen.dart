import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../core/errors/friendly_error.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../data/save_flow.dart';
import '../data/upload_validation.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ui_text.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';

class ProductFormException implements Exception {
  const ProductFormException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.openFormOnLoad = false});

  /// Used by the POS empty state via `/products/new` so the user lands
  /// directly in the Add product dialog instead of on the list first.
  final bool openFormOnLoad;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsData {
  const _ProductsData({
    required this.products,
    required this.categories,
    required this.units,
    required this.stock,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final Map<String, Map<String, dynamic>> stock;
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  Future<_ProductsData>? _future;
  bool _started = false;
  String _query = '';
  String? _categoryId;
  bool? _active = true;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    DataRevision.notifier.addListener(_onRevision);
    _listenerAdded = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _reload();
      if (widget.openFormOnLoad) _openFormAfterLoad();
    }
  }

  Future<void> _openFormAfterLoad() async {
    final future = _future;
    if (future == null) return;
    try {
      final data = await future;
      if (mounted) await _openForm(data, null);
    } catch (_) {
      // The list already renders the error; no duplicate dialog needed.
    }
  }

  @override
  void dispose() {
    if (_listenerAdded) DataRevision.notifier.removeListener(_onRevision);
    _search.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<_ProductsData> _load() async {
    final session = SessionScope.of(context);
    final products = await session.client
        .from('products')
        .select()
        .order('name', ascending: true);
    final categories = await session.client
        .from('categories')
        .select()
        .eq('kind', 'product')
        .eq('is_active', true)
        .order('name', ascending: true);
    final units = await session.client
        .from('units')
        .select()
        .order('name', ascending: true);
    Map<String, Map<String, dynamic>> stock = {};
    try {
      final rows = await session.client.from('v_stock_overview').select();
      stock = {
        for (final row in rows)
          if (row['item_id'] != null)
            row['item_id'].toString(): Map<String, dynamic>.from(row),
      };
    } catch (_) {
      // The screen still works without the optional stock summary view.
    }
    return _ProductsData(
      products: [for (final row in products) Map<String, dynamic>.from(row)],
      categories: [
        for (final row in categories) Map<String, dynamic>.from(row),
      ],
      units: [for (final row in units) Map<String, dynamic>.from(row)],
      stock: stock,
    );
  }

  Map<String, dynamic>? _defaultUnit(List<Map<String, dynamic>> units) {
    for (final unit in units) {
      final code = asText(unit['code']).toLowerCase();
      final name = asText(unit['name']).toLowerCase();
      if (code == 'pcs' || name == 'pcs' || name == 'piece') return unit;
    }
    return units.isEmpty ? null : units.first;
  }

  Future<void> _saveDraft(
    _ProductDraft draft,
    Map<String, dynamic>? row,
  ) async {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final branch = session.selectedBranch;
    if (branch == null) throw const ProductFormException('No branch selected.');
    var imageUrl = row?['image_url']?.toString();
    if (draft.photo != null) {
      final picked = draft.photo!;
      final size = await picked.length();
      final problem = validateAvatarUpload(
        fileName: picked.name,
        byteLength: size,
      );
      if (problem != null) {
        throw ProductFormException(
          problem == UploadProblem.tooLarge
              ? strings.errorFileTooLarge
              : strings.errorUnsupportedFile,
        );
      }
      final dot = picked.name.lastIndexOf('.');
      final extension = dot < 0
          ? 'jpg'
          : picked.name.substring(dot + 1).toLowerCase();
      final bytes = await picked.readAsBytes();
      final path =
          'products/${branch.branchId}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await session.client.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: avatarContentType(extension),
              upsert: true,
            ),
          );
      imageUrl = session.client.storage
          .from('product-images')
          .getPublicUrl(path);
    }

    final unitId =
        draft.unitId ??
        _defaultUnit(
          (await session.client.from('units').select().order('name'))
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
        )?['id']?.toString();
    if (draft.trackStock && unitId == null) {
      throw const ProductFormException(
        'Create a unit first, then save the product.',
      );
    }

    String? storeId;
    if (draft.trackStock && draft.openingStock > 0) {
      final stores = await session.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      final rows = [for (final row in stores) Map<String, dynamic>.from(row)];
      Map<String, dynamic>? store;
      for (final item in rows) {
        if (asText(item['name']).toLowerCase() == 'shop') store = item;
      }
      store ??= rows.cast<Map<String, dynamic>?>().firstWhere(
        (item) => asText(item?['name']).toLowerCase() == 'main store',
        orElse: () => rows.isEmpty ? null : rows.first,
      );
      storeId = store?['id']?.toString();
      if (storeId == null) {
        throw const ProductFormException(
          'Create the Shop store before adding opening stock.',
        );
      }
    }

    await SaveFlow.write(
      module: 'Products',
      target: 'products',
      action: () async {
        final payload = <String, dynamic>{
          'name': draft.name.trim(),
          'price': draft.price,
          'cost': draft.cost,
          'tax_rate': draft.taxRate,
          'is_active': draft.isActive,
          if (draft.nameAm.trim().isNotEmpty) 'name_am': draft.nameAm.trim(),
          if (draft.nameOm.trim().isNotEmpty) 'name_om': draft.nameOm.trim(),
          if (draft.description.trim().isNotEmpty)
            'description': draft.description.trim(),
          if (draft.categoryId != null) 'category_id': draft.categoryId,
          if (unitId != null) 'unit_id': unitId,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        };
        Map<String, dynamic> product;
        if (row == null) {
          product = Map<String, dynamic>.from(
            await session.client
                .from('products')
                .insert(payload)
                .select()
                .single(),
          );
        } else {
          product = Map<String, dynamic>.from(
            await session.client
                .from('products')
                .update(payload)
                .eq('id', row['id'])
                .select()
                .single(),
          );
        }

        try {
          if (!draft.trackStock) {
            if (product['item_id'] != null) {
              await session.client
                  .from('products')
                  .update({'item_id': null})
                  .eq('id', product['id']);
            }
            return;
          }

          var itemId = product['item_id']?.toString();
          if (itemId == null) {
            final item = Map<String, dynamic>.from(
              await session.client
                  .from('items')
                  .insert({
                    'name': draft.name.trim(),
                    'item_type': 'finished_good',
                    'unit_id': unitId,
                    'cost_price': draft.cost,
                    'min_stock': 0,
                    'is_active': draft.isActive,
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      'image_url': imageUrl,
                  })
                  .select()
                  .single(),
            );
            itemId = item['id'].toString();
            await session.client
                .from('products')
                .update({'item_id': itemId})
                .eq('id', product['id']);
          } else {
            await session.client
                .from('items')
                .update({
                  'name': draft.name.trim(),
                  'unit_id': unitId,
                  'cost_price': draft.cost,
                  'is_active': draft.isActive,
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    'image_url': imageUrl,
                })
                .eq('id', itemId);
          }

          if (row == null && draft.openingStock > 0 && storeId != null) {
            await session.client.from('stock_movements').insert({
              'store_id': storeId,
              'item_id': itemId,
              'movement_type': 'adjustment',
              'quantity': draft.openingStock,
              'unit_cost': draft.cost,
              'notes': 'Opening stock',
              'created_by': session.userId,
            });
          }
        } catch (error) {
          // Clean up a half-created product when the linked item fails. This
          // is a best-effort compensation because the database has no
          // product+item transaction in the applied schema.
          if (row == null) {
            try {
              await session.client
                  .from('products')
                  .delete()
                  .eq('id', product['id']);
            } catch (_) {
              // Leave the original error visible.
            }
          }
          rethrow;
        }
      },
    );
  }

  Future<void> _openForm(_ProductsData data, Map<String, dynamic>? row) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductFormDialog(
        row: row,
        categories: data.categories,
        units: data.units,
        defaultUnit: _defaultUnit(data.units),
        onSubmit: (draft) => _saveDraft(draft, row),
      ),
    );
    if (saved == true && mounted) {
      showSnack(context, uiText(context, 'Product saved.'));
      _reload();
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row) async {
    try {
      await SaveFlow.write(
        module: 'Products',
        target: 'products',
        action: () => SessionScope.of(context).client
            .from('products')
            .update({'is_active': !(row['is_active'] == true)})
            .eq('id', row['id']),
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _duplicate(Map<String, dynamic> row) async {
    final confirmed = await confirmAction(
      context,
      title: uiText(context, 'Duplicate product?'),
      message: uiText(
        context,
        'A copy will be created with stock tracking turned off.',
      ),
      confirmLabel: uiText(context, 'Duplicate'),
    );
    if (!confirmed || !mounted) return;
    try {
      await SaveFlow.write(
        module: 'Products',
        target: 'products',
        action: () => SessionScope.of(context).client.from('products').insert({
          'name': '${asText(row['name'])} (copy)',
          'name_am': row['name_am'],
          'name_om': row['name_om'],
          'category_id': row['category_id'],
          'unit_id': row['unit_id'],
          'price': asNum(row['price']),
          'cost': asNum(row['cost']),
          'tax_rate': asNum(row['tax_rate']),
          'description': row['description'],
          'image_url': row['image_url'],
          'is_active': true,
        }),
      );
      if (mounted) {
        showSnack(context, uiText(context, 'Product duplicated.'));
        _reload();
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _startTracking(Map<String, dynamic> row) async {
    final session = SessionScope.of(context);
    try {
      String? unitId = row['unit_id']?.toString();
      if (unitId == null) {
        final units = [
          for (final unit
              in await session.client.from('units').select().order('name'))
            Map<String, dynamic>.from(unit),
        ];
        unitId = _defaultUnit(units)?['id']?.toString();
      }
      if (unitId == null) {
        throw const ProductFormException(
          'Create a unit first, then start tracking stock.',
        );
      }
      await SaveFlow.write(
        module: 'Products',
        target: 'items',
        action: () async {
          final item = Map<String, dynamic>.from(
            await session.client
                .from('items')
                .insert({
                  'name': asText(row['name']),
                  'item_type': 'finished_good',
                  'unit_id': unitId,
                  'cost_price': asNum(row['cost']),
                  'min_stock': 0,
                  'is_active': row['is_active'] != false,
                  if (asText(row['image_url']).isNotEmpty)
                    'image_url': row['image_url'],
                })
                .select()
                .single(),
          );
          await session.client
              .from('products')
              .update({'item_id': item['id']})
              .eq('id', row['id']);
        },
      );
      if (mounted) {
        showSnack(context, uiText(context, 'Stock tracking started.'));
        _reload();
      }
    } catch (error) {
      if (mounted) {
        showSnack(
          context,
          error is ProductFormException
              ? error.message
              : friendlyMessage(error),
          error: true,
        );
      }
    }
  }

  Future<void> _showDetail(
    Map<String, dynamic> row,
    Map<String, dynamic>? stock,
  ) async {
    final session = SessionScope.of(context);
    List<Map<String, dynamic>> sales = const [];
    try {
      final rows = await session.client
          .from('v_product_sales')
          .select()
          .eq('product_id', row['id'])
          .order('sale_day', ascending: false)
          .limit(8);
      sales = [for (final item in rows) Map<String, dynamic>.from(item)];
    } catch (_) {
      // Detail is still useful without the sales summary view.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asText(row['name'])),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (asText(row['image_url']).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      asText(row['image_url']),
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${uiText(context, 'Price')}: ${formatMoney(row['price'])}',
                ),
                Text('${uiText(context, 'Cost')}: ${formatMoney(row['cost'])}'),
                if (row['item_id'] == null)
                  Text(
                    uiText(context, 'Stock is not tracked for this product'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else if (stock != null)
                  Text(
                    '${uiText(context, 'Stock on hand')}: '
                    '${asNum(stock['quantity']).toStringAsFixed(2)} '
                    '${asText(stock['unit_code'])}',
                  ),
                const SizedBox(height: 12),
                Text(
                  uiText(context, 'Recent sales'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (sales.isEmpty)
                  Text(uiText(context, 'No sales yet.'))
                else
                  for (final sale in sales)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(asText(sale['sale_day'])),
                      subtitle: Text(
                        '${uiText(context, 'Quantity')}: '
                        '${asNum(sale['quantity_sold']).toStringAsFixed(2)}',
                      ),
                      trailing: Text(formatMoney(sale['revenue'])),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          if (row['item_id'] == null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _startTracking(row);
              },
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(uiText(context, 'Start tracking stock')),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiText(context, 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    Future<void> add() async {
      final data = await _future;
      if (data != null) await _openForm(data, null);
    }

    return ModuleScaffold(
      title: uiText(context, 'Products'),
      actions: [
        if (!compact)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC8A24A),
                    foregroundColor: const Color(0xFF231A05),
                  ),
                  onPressed: _future == null ? null : add,
                  icon: const Icon(Icons.add),
                  label: Text(uiText(context, 'Add product')),
                ),
              ),
            ),
          ),
      ],
      floatingActionButton: compact
          ? FloatingActionButton(
              tooltip: uiText(context, 'Add product'),
              onPressed: _future == null ? null : add,
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<_ProductsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyMessage(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          final products = data.products.where((product) {
            if (_active != null && (product['is_active'] == true) != _active) {
              return false;
            }
            if (_categoryId != null &&
                product['category_id']?.toString() != _categoryId) {
              return false;
            }
            if (_query.isEmpty) return true;
            final haystack = [
              asText(product['name']),
              asText(product['name_am']),
              asText(product['name_om']),
              asText(product['sku']),
            ].join(' ').toLowerCase();
            return haystack.contains(_query);
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(uiText(context, 'All')),
                        selected: _active == null,
                        onSelected: (_) => setState(() => _active = null),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(uiText(context, 'Active')),
                        selected: _active == true,
                        onSelected: (_) => setState(() => _active = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(uiText(context, 'Inactive')),
                        selected: _active == false,
                        onSelected: (_) => setState(() => _active = false),
                      ),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: Text(uiText(context, 'All categories')),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                      for (final category in data.categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(asText(category['name'])),
                          selected: _categoryId == category['id']?.toString(),
                          onSelected: (_) => setState(
                            () => _categoryId = category['id']?.toString(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyView(
                      message: uiText(
                        context,
                        'No products match these filters.',
                      ),
                      action: FilledButton.icon(
                        onPressed: add,
                        icon: const Icon(Icons.add),
                        label: Text(uiText(context, 'Add product')),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 650
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 230,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final stock = data.stock[product['item_id']];
                          return _ProductCard(
                            product: product,
                            stock: stock,
                            onTap: () => _showDetail(product, stock),
                            onEdit: () => _openForm(data, product),
                            onToggle: () => _toggleActive(product),
                            onDuplicate: () => _duplicate(product),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.stock,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDuplicate,
  });

  final Map<String, dynamic> product;
  final Map<String, dynamic>? stock;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final image = asText(product['image_url']);
    final low = stock?['is_low'] == true;
    final untracked = product['item_id'] == null;
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: image.isEmpty
                  ? Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Center(
                        child: Icon(
                          Icons.bakery_dining,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      asText(product['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Edit'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    visualDensity: VisualDensity.compact,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'toggle') onToggle();
                      if (value == 'duplicate') onDuplicate();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text(uiText(context, 'Duplicate')),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          product['is_active'] == true
                              ? uiText(context, 'Deactivate')
                              : uiText(context, 'Reactivate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                formatMoney(product['price']),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  if (untracked)
                    Expanded(
                      child: Text(
                        uiText(
                          context,
                          'Stock is not tracked for this product',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else if (stock != null)
                    Expanded(
                      child: Text(
                        '${asNum(stock!['quantity']).toStringAsFixed(2)} '
                        '${asText(stock!['unit_code'])}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: low
                              ? Theme.of(context).colorScheme.error
                              : null,
                          fontWeight: low ? FontWeight.w700 : null,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (low)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(uiText(context, 'Low')),
                        ),
                      ),
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

class _ProductDraft {
  _ProductDraft({
    required this.name,
    required this.nameAm,
    required this.nameOm,
    required this.price,
    required this.cost,
    required this.taxRate,
    required this.description,
    required this.categoryId,
    required this.unitId,
    required this.isActive,
    required this.trackStock,
    required this.openingStock,
    required this.photo,
  });

  final String name;
  final String nameAm;
  final String nameOm;
  final num price;
  final num cost;
  final num taxRate;
  final String description;
  final String? categoryId;
  final String? unitId;
  final bool isActive;
  final bool trackStock;
  final num openingStock;
  final XFile? photo;
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.row,
    required this.categories,
    required this.units,
    required this.defaultUnit,
    required this.onSubmit,
  });

  final Map<String, dynamic>? row;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final Map<String, dynamic>? defaultUnit;
  final Future<void> Function(_ProductDraft draft) onSubmit;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nameAm;
  late final TextEditingController _nameOm;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _tax;
  late final TextEditingController _description;
  late final TextEditingController _opening;
  String? _categoryId;
  String? _unitId;
  bool _isActive = true;
  bool _trackStock = true;
  bool _saving = false;
  Object? _error;
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _name = TextEditingController(text: asText(row?['name']));
    _nameAm = TextEditingController(text: asText(row?['name_am']));
    _nameOm = TextEditingController(text: asText(row?['name_om']));
    _price = TextEditingController(
      text: row == null ? '0' : asNum(row['price']).toString(),
    );
    _cost = TextEditingController(
      text: row == null ? '0' : asNum(row['cost']).toString(),
    );
    _tax = TextEditingController(
      text: row == null ? '0' : asNum(row['tax_rate']).toString(),
    );
    _description = TextEditingController(text: asText(row?['description']));
    _opening = TextEditingController(text: '0');
    _categoryId = row?['category_id']?.toString();
    _unitId =
        row?['unit_id']?.toString() ?? widget.defaultUnit?['id']?.toString();
    _isActive = row?['is_active'] != false;
    _trackStock = row == null || row['item_id'] != null;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _nameAm,
      _nameOm,
      _price,
      _cost,
      _tax,
      _description,
      _opening,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 88,
    );
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = num.tryParse(_price.text.trim()) ?? 0;
    if (price <= 0) {
      final confirmed = await confirmAction(
        context,
        title: uiText(context, 'Price is 0'),
        message: uiText(
          context,
          'This product will be saved with a price of 0. You can edit it later.',
        ),
        confirmLabel: uiText(context, 'Save with 0'),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _ProductDraft(
          name: _name.text.trim(),
          nameAm: _nameAm.text.trim(),
          nameOm: _nameOm.text.trim(),
          price: price,
          cost: num.tryParse(_cost.text.trim()) ?? 0,
          taxRate: num.tryParse(_tax.text.trim()) ?? 0,
          description: _description.text.trim(),
          categoryId: _categoryId,
          unitId: _unitId,
          isActive: _isActive,
          trackStock: _trackStock,
          openingStock: num.tryParse(_opening.text.trim()) ?? 0,
          photo: _photo,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.row != null;
    return AlertDialog(
      title: Text(uiText(context, editing ? 'Edit product' : 'Add product')),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '${uiText(context, 'Name')} *',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? uiText(context, 'Name is required')
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameAm,
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Name in Amharic'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _nameOm,
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Name in Oromo'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Price'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Cost'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _tax,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: uiText(context, 'Tax rate'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Category'),
                  ),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(
                        value: category['id'].toString(),
                        child: Text(asText(category['name'])),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _unitId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Unit'),
                  ),
                  items: [
                    for (final unit in widget.units)
                      DropdownMenuItem(
                        value: unit['id'].toString(),
                        child: Text(
                          '${asText(unit['name'])} (${asText(unit['code'])})',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _unitId = value),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(uiText(context, 'Add item to inventory')),
                  subtitle: Text(
                    uiText(
                      context,
                      'Creates a linked inventory item and enables stock tracking.',
                    ),
                  ),
                  value: _trackStock,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _trackStock = value),
                ),
                if (_trackStock && !editing) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _opening,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Opening stock (optional)'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Description'),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _photo == null
                      ? const Icon(Icons.image_outlined)
                      : const Icon(Icons.check_circle_outline),
                  title: Text(
                    _photo == null
                        ? uiText(context, 'Add photo (optional)')
                        : _photo!.name,
                  ),
                  trailing: TextButton(
                    onPressed: _saving ? null : _pickPhoto,
                    child: Text(uiText(context, 'Choose')),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(uiText(context, 'Active')),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error is ProductFormException
                          ? (_error as ProductFormException).message
                          : friendlyMessage(_error!),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
