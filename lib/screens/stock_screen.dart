import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/errors/friendly_error.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../data/save_flow.dart';
import '../l10n/ui_text.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';

class _StockData {
  const _StockData({
    required this.items,
    required this.stores,
    required this.units,
    required this.levels,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> levels;
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _search = TextEditingController();
  Future<_StockData>? _future;
  bool _started = false;
  String _query = '';
  String _filter = 'all';
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
    if (_started) return;
    _started = true;
    // The first load must not call setState while the element is still being
    // mounted. Later refreshes use _reload.
    _future = _load();
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

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<_StockData> _load() async {
    final session = SessionScope.of(context);
    final items = await session.client
        .from('v_stock_overview')
        .select()
        .order('name', ascending: true);
    final stores = await session.client
        .from('stores')
        .select()
        .eq('is_active', true)
        .order('name');
    final units = await session.client.from('units').select().order('name');
    final levels = await session.client.from('stock_levels').select();
    return _StockData(
      items: [for (final row in items) Map<String, dynamic>.from(row)],
      stores: [for (final row in stores) Map<String, dynamic>.from(row)],
      units: [for (final row in units) Map<String, dynamic>.from(row)],
      levels: [for (final row in levels) Map<String, dynamic>.from(row)],
    );
  }

  String? _defaultStoreId(_StockData data) {
    for (final store in data.stores) {
      if (asText(store['name']).toLowerCase() == 'shop') {
        return store['id']?.toString();
      }
    }
    for (final store in data.stores) {
      if (asText(store['name']).toLowerCase() == 'main store') {
        return store['id']?.toString();
      }
    }
    return data.stores.isEmpty ? null : data.stores.first['id']?.toString();
  }

  Future<void> _runAction(
    _StockData data,
    Map<String, dynamic> item,
    String action,
  ) async {
    final result = await showDialog<_StockAction>(
      context: context,
      builder: (context) => _StockActionDialog(
        action: action,
        item: item,
        stores: data.stores,
        defaultStoreId: _defaultStoreId(data),
        currentQuantity: asNum(item['quantity']),
      ),
    );
    if (result == null || !mounted) return;
    final session = SessionScope.of(context);
    try {
      await SaveFlow.write(
        module: 'Stock',
        target: result.action == 'transfer'
            ? 'stock_transfers'
            : 'stock_movements',
        action: () async {
          if (result.action == 'transfer') {
            await session.client.from('stock_transfers').insert({
              'from_store_id': result.storeId,
              'to_store_id': result.toStoreId,
              'item_id': item['item_id'],
              'quantity': result.quantity,
              'notes': result.note.isEmpty ? null : result.note,
              'created_by': session.userId,
            });
            return;
          }
          await session.client.from('stock_movements').insert({
            'store_id': result.storeId,
            'item_id': item['item_id'],
            'movement_type': result.movementType,
            'quantity': result.quantity,
            'unit_cost': asNum(item['cost_price']),
            if (result.note.isNotEmpty) 'notes': result.note,
            'created_by': session.userId,
          });
        },
      );
      if (mounted) {
        showSnack(context, uiText(context, 'Stock updated.'));
        _reload();
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _addItem(_StockData data) async {
    final draft = await showDialog<_ItemDraft>(
      context: context,
      builder: (context) => _AddItemDialog(units: data.units),
    );
    if (draft == null || !mounted) return;
    try {
      await SaveFlow.write(
        module: 'Stock',
        target: 'items',
        action: () => SessionScope.of(context).client.from('items').insert({
          'name': draft.name,
          'item_type': draft.type,
          'unit_id': draft.unitId,
          'min_stock': draft.minStock,
          'is_active': true,
        }),
      );
      if (mounted) {
        showSnack(context, uiText(context, 'Item saved.'));
        _reload();
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _showHistory(_StockData data, Map<String, dynamic> item) async {
    final session = SessionScope.of(context);
    List<Map<String, dynamic>> movements = const [];
    try {
      final rows = await session.client
          .from('stock_movements')
          .select()
          .eq('item_id', item['item_id'])
          .order('created_at', ascending: false)
          .limit(20);
      movements = [for (final row in rows) Map<String, dynamic>.from(row)];
    } catch (_) {
      // The detail still shows per-store levels.
    }
    final levels = data.levels
        .where((level) => level['item_id'] == item['item_id'])
        .toList();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asText(item['name'])),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${uiText(context, 'Stock on hand')}: '
                  '${asNum(item['quantity']).toStringAsFixed(2)} '
                  '${uiText(context, asText(item['unit_name']).isEmpty ? asText(item['unit_code']) : asText(item['unit_name']))}',
                ),
                const SizedBox(height: 12),
                Text(
                  uiText(context, 'Per store'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final level in levels)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      asText(
                        data.stores
                                .where(
                                  (store) => store['id'] == level['store_id'],
                                )
                                .map((store) => store['name'])
                                .isEmpty
                            ? ''
                            : data.stores
                                  .where(
                                    (store) => store['id'] == level['store_id'],
                                  )
                                  .map((store) => store['name'])
                                  .first,
                      ),
                    ),
                    trailing: Text(asNum(level['quantity']).toStringAsFixed(2)),
                  ),
                const SizedBox(height: 12),
                Text(
                  uiText(context, 'Movement history'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (movements.isEmpty)
                  Text(uiText(context, 'No stock movements yet.'))
                else
                  for (final movement in movements)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${asText(movement['movement_type'])} · '
                        '${asNum(movement['quantity']).toStringAsFixed(2)}',
                      ),
                      subtitle: Text(
                        '${asText(movement['created_at'])}'
                        '${asText(movement['notes']).isEmpty ? '' : '\n${asText(movement['notes'])}'}',
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

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: uiText(context, 'Stock'),
      actions: [
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
                onPressed: _future == null
                    ? null
                    : () async {
                        final data = await _future;
                        if (data != null) await _addItem(data);
                      },
                icon: const Icon(Icons.add),
                label: Text(uiText(context, 'Add item')),
              ),
            ),
          ),
        ),
      ],
      body: FutureBuilder<_StockData>(
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
          final items = data.items.where((item) {
            if (_filter == 'raw' && item['item_type'] != 'raw_material') {
              return false;
            }
            if (_filter == 'finished' && item['item_type'] != 'finished_good') {
              return false;
            }
            if (_filter == 'low' && item['is_low'] != true) return false;
            if (_query.isEmpty) return true;
            return '${asText(item['name'])} ${asText(item['sku'])}'
                .toLowerCase()
                .contains(_query);
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
                      labelText: uiText(context, 'Search stock'),
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
                      for (final entry in const [
                        ('all', 'All'),
                        ('raw', 'Raw materials'),
                        ('finished', 'Finished goods'),
                        ('low', 'Low stock'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(uiText(context, entry.$2)),
                            selected: _filter == entry.$1,
                            onSelected: (_) =>
                                setState(() => _filter = entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyView(
                      message: uiText(
                        context,
                        'No stock items match these filters.',
                      ),
                    ),
                  )
                else
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item['is_low'] == true
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            item['item_type'] == 'finished_good'
                                ? Icons.bakery_dining
                                : Icons.grain,
                          ),
                        ),
                        title: Text(asText(item['name'])),
                        subtitle: Text(
                          '${asNum(item['quantity']).toStringAsFixed(2)} '
                          '${uiText(context, asText(item['unit_name']).isEmpty ? asText(item['unit_code']) : asText(item['unit_name']))} · '
                          '${uiText(context, prettyLabel(asText(item['item_type'])))}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item['is_low'] == true)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                label: Text(
                                  uiText(context, 'Low'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'history') {
                                  _showHistory(data, item);
                                } else {
                                  _runAction(data, item, value);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'receive',
                                  child: Text(uiText(context, 'Receive stock')),
                                ),
                                PopupMenuItem(
                                  value: 'use',
                                  child: Text(
                                    uiText(context, 'Use or adjust stock'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'count',
                                  child: Text(uiText(context, 'Count')),
                                ),
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Text(uiText(context, 'Transfer')),
                                ),
                                PopupMenuItem(
                                  value: 'history',
                                  child: Text(
                                    uiText(context, 'Movement history'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showHistory(data, item),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StockAction {
  const _StockAction({
    required this.action,
    required this.storeId,
    required this.toStoreId,
    required this.quantity,
    required this.movementType,
    required this.note,
  });

  final String action;
  final String storeId;
  final String toStoreId;
  final num quantity;
  final String movementType;
  final String note;
}

class _StockActionDialog extends StatefulWidget {
  const _StockActionDialog({
    required this.action,
    required this.item,
    required this.stores,
    required this.defaultStoreId,
    required this.currentQuantity,
  });

  final String action;
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> stores;
  final String? defaultStoreId;
  final num currentQuantity;

  @override
  State<_StockActionDialog> createState() => _StockActionDialogState();
}

class _StockActionDialogState extends State<_StockActionDialog> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  String? _storeId;
  String? _toStoreId;
  String _movementType = 'adjustment';
  String? _error;

  @override
  void initState() {
    super.initState();
    _storeId = widget.defaultStoreId;
    if (widget.action == 'count') {
      _quantity.text = widget.currentQuantity.toStringAsFixed(2);
    }
    if (widget.action == 'use') _movementType = 'damage';
    _toStoreId = widget.stores.length > 1
        ? widget.stores
              .firstWhere(
                (store) => store['id'] != widget.defaultStoreId,
                orElse: () => widget.stores.first,
              )['id']
              ?.toString()
        : null;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final entered = num.tryParse(_quantity.text.trim());
    if (entered == null || entered == 0) {
      setState(() => _error = uiText(context, 'Enter a quantity.'));
      return;
    }
    if (widget.action == 'count') {
      final delta = entered - widget.currentQuantity;
      if (delta == 0) {
        setState(() => _error = uiText(context, 'The count has not changed.'));
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _StockAction(
          action: widget.action,
          storeId: _storeId!,
          toStoreId: '',
          quantity: delta,
          movementType: 'count',
          note: _note.text.trim(),
        ),
      );
      return;
    }
    if (_storeId == null) {
      setState(() => _error = uiText(context, 'Choose a store.'));
      return;
    }
    if (widget.action == 'transfer' && _toStoreId == null) {
      setState(() => _error = uiText(context, 'Choose the destination store.'));
      return;
    }
    final quantity = switch (widget.action) {
      'receive' => entered,
      'use' => -entered.abs(),
      'adjustment' => entered,
      _ => entered,
    };
    Navigator.of(context).pop(
      _StockAction(
        action: widget.action,
        storeId: _storeId!,
        toStoreId: _toStoreId ?? '',
        quantity: quantity,
        movementType: switch (widget.action) {
          'receive' => 'purchase',
          'use' => _movementType,
          'transfer' => 'transfer_out',
          _ => _movementType,
        },
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.action) {
      'receive' => 'Receive stock',
      'use' => 'Use or adjust stock',
      'count' => 'Count stock',
      'transfer' => 'Transfer stock',
      _ => 'Stock action',
    };
    return AlertDialog(
      title: Text(uiText(context, title)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(asText(widget.item['name'])),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _storeId,
              decoration: InputDecoration(labelText: uiText(context, 'Store')),
              items: [
                for (final store in widget.stores)
                  DropdownMenuItem(
                    value: store['id'].toString(),
                    child: Text(asText(store['name'])),
                  ),
              ],
              onChanged: (value) => setState(() => _storeId = value),
            ),
            if (widget.action == 'transfer') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _toStoreId,
                decoration: InputDecoration(
                  labelText: uiText(context, 'Destination store'),
                ),
                items: [
                  for (final store in widget.stores)
                    DropdownMenuItem(
                      value: store['id'].toString(),
                      child: Text(asText(store['name'])),
                    ),
                ],
                onChanged: (value) => setState(() => _toStoreId = value),
              ),
            ],
            if (widget.action == 'use') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _movementType,
                decoration: InputDecoration(
                  labelText: uiText(context, 'Reason'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'damage',
                    child: Text(uiText(context, 'Damage')),
                  ),
                  DropdownMenuItem(
                    value: 'adjustment',
                    child: Text(uiText(context, 'Adjustment')),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _movementType = value ?? 'damage'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.action == 'count'
                    ? uiText(context, 'Counted quantity')
                    : uiText(context, 'Quantity'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: uiText(context, 'Note (optional)'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, 'Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(uiText(context, 'Save'))),
      ],
    );
  }
}

class _ItemDraft {
  const _ItemDraft({
    required this.name,
    required this.type,
    required this.unitId,
    required this.minStock,
  });

  final String name;
  final String type;
  final String unitId;
  final num minStock;
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.units});

  final List<Map<String, dynamic>> units;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _name = TextEditingController();
  final _min = TextEditingController(text: '0');
  String _type = 'raw_material';
  String? _unitId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unitId = _defaultUnit();
  }

  String? _defaultUnit() {
    for (final unit in widget.units) {
      if (asText(unit['code']).toLowerCase() == 'pcs') {
        return unit['id']?.toString();
      }
    }
    return widget.units.isEmpty ? null : widget.units.first['id']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, 'Add item')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '${uiText(context, 'Name')} *',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: uiText(context, 'Item type'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'raw_material',
                  child: Text(uiText(context, 'Raw material')),
                ),
                DropdownMenuItem(
                  value: 'finished_good',
                  child: Text(uiText(context, 'Finished good')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _type = value ?? 'raw_material'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _unitId,
              decoration: InputDecoration(labelText: uiText(context, 'Unit')),
              items: [
                for (final unit in widget.units)
                  DropdownMenuItem(
                    value: unit['id'].toString(),
                    child: Text(asText(unit['name'])),
                  ),
              ],
              onChanged: (value) => setState(() => _unitId = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: uiText(context, 'Minimum stock'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = uiText(context, 'Name is required'));
              return;
            }
            if (_unitId == null) {
              setState(() => _error = uiText(context, 'Choose a unit.'));
              return;
            }
            Navigator.of(context).pop(
              _ItemDraft(
                name: _name.text.trim(),
                type: _type,
                unitId: _unitId!,
                minStock: num.tryParse(_min.text.trim()) ?? 0,
              ),
            );
          },
          child: Text(uiText(context, 'Save')),
        ),
      ],
    );
  }
}
