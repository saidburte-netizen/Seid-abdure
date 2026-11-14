import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
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
  Future<void> _receivePurchaseOrder(
    AuthController session,
    Map<String, dynamic> order,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    try {
      final stores = await repo.list(
        'stores',
        equals: {'is_active': true},
        orderBy: 'name',
      );
      if (stores.isEmpty) {
        throw Exception('Create a store before receiving goods.');
      }
      final lines = await session.client
          .from('purchase_order_items')
          .select()
          .eq('po_id', order['id']);
      if (!mounted) return;
      final storeId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Receive ${order['po_number']}'),
          content: DropdownButtonFormField<String>(
            initialValue: stores.first['id'] as String,
            decoration: const InputDecoration(labelText: 'Receiving store'),
            items: [
              for (final store in stores)
                DropdownMenuItem(
                  value: store['id'] as String,
                  child: Text(asText(store['name'])),
                ),
            ],
            onChanged: (_) {},
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(stores.first['id'] as String),
              child: const Text('Receive all'),
            ),
          ],
        ),
      );
      if (storeId == null) return;
      String receiptNo;
      try {
        receiptNo = (await session.client.rpc(
          'next_number',
          params: {'p_prefix': 'GRN'},
        ))
            .toString();
      } catch (_) {
        receiptNo = 'GRN-${DateTime.now().millisecondsSinceEpoch}';
      }
      final receipt = await session.client
          .from('goods_receipts')
          .insert({
            'receipt_no': receiptNo,
            'po_id': order['id'],
            'store_id': storeId,
            'received_date': dateOnly(DateTime.now()),
            'received_by': session.userId,
            'notes': 'Received from purchase order ${order['po_number']}',
          })
          .select()
          .single();
      final items = <Map<String, dynamic>>[];
      for (final raw in (lines as List)) {
        final line = Map<String, dynamic>.from(raw as Map);
        final remaining =
            asNum(line['quantity_ordered']) - asNum(line['quantity_received']);
        if (remaining <= 0) continue;
        items.add({
          'receipt_id': receipt['id'],
          'item_id': line['item_id'],
          'quantity': remaining,
          'unit_cost': line['unit_cost'],
          'batch_no': '',
          'expiry_date': null,
        });
      }
      if (items.isNotEmpty) {
        await session.client.from('goods_receipt_items').insert(items);
      }
      await session.client
          .from('purchase_orders')
          .update({'status': 'received'}).eq('id', order['id']);
      if (mounted) showSnack(context, 'Goods received as $receiptNo.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _approveCount(
    AuthController session,
    Map<String, dynamic> count,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Approve stock count?',
      message: 'The database trigger will post counted variances to stock.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    try {
      await session.client
          .from('stock_counts')
          .update({'status': 'approved'}).eq('id', count['id']);
      if (mounted) showSnack(context, 'Stock count approved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Inventory & purchasing',
      body: DefaultTabController(
        length: 14,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Stock levels'),
                Tab(text: 'Movements'),
                Tab(text: 'Items'),
                Tab(text: 'Categories'),
                Tab(text: 'Units'),
                Tab(text: 'Stores'),
                Tab(text: 'Suppliers'),
                Tab(text: 'Purchase orders'),
                Tab(text: 'PO lines'),
                Tab(text: 'Goods receipts'),
                Tab(text: 'Receipt lines'),
                Tab(text: 'Stock counts'),
                Tab(text: 'Count lines'),
                Tab(text: 'Transfers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('stock_levels'),
                    readPermission: 'inventory.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('stock_movements'),
                    readPermission: 'inventory.view',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: specFor('items'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('categories'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('units'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('stores'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('suppliers'),
                    readPermission: 'inventory.view',
                    writePermission: 'purchasing.manage',
                  ),
                  CrudTab(
                    spec: specFor('purchase_orders'),
                    readPermission: 'inventory.view',
                    writePermission: 'purchasing.manage',
                    actions: (row) {
                      if (!session.can('purchasing.manage') ||
                          row['status'] == 'received' ||
                          row['status'] == 'cancelled') {
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
                  CrudTab(
                    spec: specFor('purchase_order_items'),
                    readPermission: 'inventory.view',
                    writePermission: 'purchasing.manage',
                  ),
                  CrudTab(
                    spec: specFor('goods_receipts'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('goods_receipt_items'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('stock_counts'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                    actions: (row) {
                      if (!session.can('inventory.manage') ||
                          row['status'] == 'approved') {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve count',
                          icon: Icons.fact_check_outlined,
                          onPressed: (row) => _approveCount(session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('stock_count_items'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('stock_transfers'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
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
