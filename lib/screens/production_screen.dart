import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  Future<void> _completeBatch(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> batch,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: uiText(context, 'Complete production batch?'),
      message: uiText(
        context,
        'The database trigger will consume ingredients and add finished stock.',
      ),
      confirmLabel: 'Complete',
    );
    if (!confirmed) return;
    try {
      await session.client
          .from('production_batches')
          .update({'status': 'completed', 'completed_at': nowIso()})
          .eq('id', batch['id']);
      if (context.mounted) showSnack(context, 'Production batch completed.');
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  Future<void> _advanceCakeOrder(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> order,
  ) async {
    final current = asText(order['status']);
    final next = switch (current) {
      'pending' => 'confirmed',
      'confirmed' => 'in_production',
      'in_production' => 'ready',
      'ready' => 'delivered',
      _ => null,
    };
    if (next == null) return;
    try {
      await session.client
          .from('cake_orders')
          .update({'status': next})
          .eq('id', order['id']);
      if (context.mounted) {
        showSnack(
          context,
          uiTextFormat(context, 'cakeOrderMarked', {
            'status': uiText(context, prettyLabel(next)),
          }),
        );
      }
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
      title: uiText(context, 'Production & catalog'),
      body: DefaultTabController(
        length: 8,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Products'),
                Tab(text: 'Categories'),
                Tab(text: 'Units'),
                Tab(text: 'Items'),
                Tab(text: 'Recipes'),
                Tab(text: 'Recipe items'),
                Tab(text: 'Batches'),
                Tab(text: 'Cake orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('products'),
                    readPermission: 'products.view',
                    writePermission: 'products.manage',
                  ),
                  CrudTab(
                    spec: specFor('categories'),
                    readPermission: 'products.view',
                    writePermission: 'products.manage',
                  ),
                  CrudTab(
                    spec: specFor('units'),
                    readPermission: 'products.view',
                    writePermission: 'products.manage',
                  ),
                  CrudTab(
                    spec: specFor('items'),
                    readPermission: 'inventory.view',
                    writePermission: 'inventory.manage',
                  ),
                  CrudTab(
                    spec: specFor('recipes'),
                    readPermission: 'production.manage',
                    writePermission: 'production.manage',
                  ),
                  CrudTab(
                    spec: specFor('recipe_items'),
                    readPermission: 'production.manage',
                    writePermission: 'production.manage',
                  ),
                  CrudTab(
                    spec: specFor('production_batches'),
                    readPermission: 'production.manage',
                    writePermission: 'production.manage',
                    actions: (row) => row['status'] == 'completed'
                        ? const []
                        : [
                            CrudRowAction(
                              label: uiText(context, 'Complete batch'),
                              icon: Icons.check_circle_outline,
                              onPressed: (row) =>
                                  _completeBatch(context, session, row),
                            ),
                          ],
                  ),
                  CrudTab(
                    spec: specFor('cake_orders'),
                    readPermission: 'production.manage',
                    writePermission: 'production.manage',
                    actions: (row) {
                      if (row['status'] == 'delivered' ||
                          row['status'] == 'cancelled') {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: uiText(context, 'Advance status'),
                          icon: Icons.arrow_forward,
                          onPressed: (row) =>
                              _advanceCakeOrder(context, session, row),
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
}
