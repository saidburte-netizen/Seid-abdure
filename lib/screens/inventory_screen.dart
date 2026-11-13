import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/export.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final TableSpec _poSpec = TableSpec(
    table: 'purchase_orders',
    title: 'Purchase orders',
    singular: 'Purchase order',
    orderBy: 'created_at',
    ascending: false,
    searchColumns: const ['po_number', 'status', 'notes'],
    defaults: {
      'po_number':
          'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    },
    fields: purchaseOrdersSpec.fields,
  );

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Inventory',
      body: DefaultTabController(
        length: 12,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Stock'),
                Tab(text: 'Items'),
                Tab(text: 'Stores'),
                Tab(text: 'Suppliers'),
                Tab(text: 'Purchase orders'),
                Tab(text: 'PO lines'),
                Tab(text: 'Adjustments'),
                Tab(text: 'Adjustment lines'),
                Tab(text: 'Transfers'),
                Tab(text: 'Transfer lines'),
                Tab(text: 'Counts'),
                Tab(text: 'Count lines'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const _StockView(),
                  const CrudTab(
                    spec: inventoryItemsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                  ),
                  const CrudTab(
                    spec: storesSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                  ),
                  const CrudTab(
                    spec: suppliersSpec,
                    readPermission: 'purchasing.read',
                    writePermission: 'purchasing.write',
                  ),
                  CrudTab(
                    spec: _poSpec,
                    readPermission: 'purchasing.read',
                    writePermission: 'purchasing.write',
                    actions: (row) {
                      final status = row['status']?.toString();
                      if (status == 'received' ||
                          status == 'cancelled' ||
                          !session.can('purchasing.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Receive goods',
                          icon: Icons.local_shipping_outlined,
                          onPressed: (row) =>
                              _receivePurchaseOrder(session, row),
                        ),
                      ];
                    },
                  ),
                  const CrudTab(
                    spec: purchaseOrderItemsSpec,
                    readPermission: 'purchasing.read',
                    writePermission: 'purchasing.write',
                  ),
                  CrudTab(
                    spec: stockAdjustmentsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                    actions: (row) {
                      if (row['status'] != 'pending' ||
                          !session.can('inventory.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve adjustment',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) async {
                            final confirmed = await confirmAction(
                              context,
                              title: 'Approve adjustment?',
                              message:
                                  'This posts the adjustment to the stock ledger.',
                              confirmLabel: 'Approve',
                            );
                            if (!confirmed) return;
                            await session.client.rpc(
                              'approve_stock_adjustment',
                              params: {'target_adjustment': row['id']},
                            );
                            if (context.mounted) {
                              showSnack(context, 'Adjustment approved.');
                            }
                          },
                        ),
                      ];
                    },
                  ),
                  const CrudTab(
                    spec: stockAdjustmentItemsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                  ),
                  CrudTab(
                    spec: stockTransfersSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                    actions: (row) {
                      if (row['status'] != 'pending' ||
                          !session.can('inventory.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Complete transfer',
                          icon: Icons.swap_horiz,
                          onPressed: (row) async {
                            final confirmed = await confirmAction(
                              context,
                              title: 'Complete transfer?',
                              message:
                                  'Stock will move from the source store to the destination store.',
                              confirmLabel: 'Complete',
                            );
                            if (!confirmed) return;
                            await session.client.rpc(
                              'complete_stock_transfer',
                              params: {'target_transfer': row['id']},
                            );
                            if (context.mounted) {
                              showSnack(context, 'Transfer completed.');
                            }
                          },
                        ),
                      ];
                    },
                  ),
                  const CrudTab(
                    spec: stockTransferItemsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                  ),
                  CrudTab(
                    spec: stockCountsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                    actions: (row) {
                      if (row['status'] == 'approved' ||
                          row['status'] == 'cancelled' ||
                          !session.can('inventory.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve count',
                          icon: Icons.fact_check_outlined,
                          onPressed: (row) async {
                            final confirmed = await confirmAction(
                              context,
                              title: 'Approve stock count?',
                              message:
                                  'Variance between the live stock ledger and counted quantities will be posted.',
                              confirmLabel: 'Approve',
                            );
                            if (!confirmed) return;
                            await session.client.rpc(
                              'approve_stock_count',
                              params: {'target_count': row['id']},
                            );
                            if (context.mounted) {
                              showSnack(context, 'Stock count approved.');
                            }
                          },
                        ),
                      ];
                    },
                  ),
                  const CrudTab(
                    spec: stockCountItemsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receivePurchaseOrder(
    AuthController session,
    Map<String, dynamic> order,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    final stores = await repo.list('stores', orderBy: 'name');
    final lines = await session.client
        .from('purchase_order_items')
        .select(
          'id, inventory_item_id, quantity, received_quantity, unit_cost, inventory_items(name, unit)',
        )
        .eq('purchase_order_id', order['id']);
    if (!mounted) return;
    if (stores.isEmpty) {
      showSnack(context, 'Create a store before receiving goods.', error: true);
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReceiveDialog(
        order: order,
        stores: stores,
        lines: (lines as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
      ),
    );
    if (result == null) return;
    try {
      final response = await session.client.rpc(
        'receive_purchase_order',
        params: {
          'target_order': order['id'],
          'target_store': result['store_id'],
          'receipt_lines': {'items': result['items'], 'notes': result['notes']},
        },
      );
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Goods received',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

class _StockView extends StatefulWidget {
  const _StockView();

  @override
  State<_StockView> createState() => _StockViewState();
}

class _StockViewState extends State<_StockView> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return Future.value(<String, dynamic>{});
    return session.client
        .rpc('report_inventory', params: {'target_branch': branch.branchId})
        .then(asMap);
  }

  @override
  Widget build(BuildContext context) => AsyncView<Map<String, dynamic>>(
    future: _future ?? Future.value(<String, dynamic>{}),
    onRetry: () async => setState(() => _future = _load()),
    builder: (context, data) {
      final items = asMapList(data['items']);
      final lowStock = asMapList(data['low_stock']);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 240,
                child: StatCard(
                  label: 'Stock value',
                  value: formatMoney(data['total_value']),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              SizedBox(
                width: 240,
                child: StatCard(
                  label: 'Items below minimum',
                  value: formatQuantity(lowStock.length),
                  icon: Icons.warning_amber_outlined,
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'Stock on hand',
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Export CSV',
                  onPressed: () async {
                    final csv = rowsToCsv(items);
                    final path = await saveCsvFile('stock_on_hand', csv);
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Stock exported'),
                        content: SelectableText(path ?? csv),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_outlined),
                ),
              ],
            ),
            child: ReportTable(rows: items),
          ),
          if (lowStock.isNotEmpty)
            SectionCard(
              title: 'Low stock alerts',
              child: ReportTable(rows: lowStock),
            ),
        ],
      );
    },
  );
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({
    required this.order,
    required this.stores,
    required this.lines,
  });

  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> lines;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  String? _storeId;
  final _quantities = <String, TextEditingController>{};
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storeId = widget.stores.first['id'] as String?;
    for (final line in widget.lines) {
      final remaining =
          asNum(line['quantity']) - asNum(line['received_quantity']);
      _quantities[line['id'] as String] = TextEditingController(
        text: remaining > 0 ? remaining.toString() : '0',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Receive ${asText(widget.order['po_number'])}'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _storeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Receive into store',
              ),
              items: [
                for (final store in widget.stores)
                  DropdownMenuItem(
                    value: store['id'] as String,
                    child: Text(asText(store['name'])),
                  ),
              ],
              onChanged: (value) => setState(() => _storeId = value),
            ),
            const SizedBox(height: 14),
            for (final line in widget.lines) _lineRow(line),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Receipt notes'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Receive goods')),
    ],
  );

  Widget _lineRow(Map<String, dynamic> line) {
    final item = asMap(line['inventory_items']);
    final remaining =
        asNum(line['quantity']) - asNum(line['received_quantity']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${asText(item['name'], fallback: 'Item')} • '
              'remaining ${formatQuantity(remaining)} ${asText(item['unit'])}',
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _quantities[line['id'] as String],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Quantity',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_storeId == null) {
      showSnack(context, 'Choose a store.', error: true);
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final line in widget.lines) {
      final quantity = asNum(_quantities[line['id'] as String]?.text);
      if (quantity <= 0) continue;
      final remaining =
          asNum(line['quantity']) - asNum(line['received_quantity']);
      if (quantity > remaining + 0.001) {
        showSnack(
          context,
          'Received quantity exceeds the remaining order.',
          error: true,
        );
        return;
      }
      items.add({
        'inventory_item_id': line['inventory_item_id'],
        'quantity': quantity,
        'unit_cost': line['unit_cost'],
      });
    }
    if (items.isEmpty) {
      showSnack(context, 'Enter a quantity to receive.', error: true);
      return;
    }
    Navigator.of(
      context,
    ).pop({'store_id': _storeId, 'items': items, 'notes': _notes.text.trim()});
  }
}
