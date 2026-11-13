import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  late final TableSpec _batchSpec = _buildBatchSpec();

  TableSpec _buildBatchSpec() => TableSpec(
        table: 'production_batches',
        title: 'Production batches',
        singular: 'Production batch',
        orderBy: 'scheduled_for',
        ascending: false,
        searchColumns: ['batch_number', 'status', 'notes'],
        defaults: {
          'batch_number':
              'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        },
        fields: const [
          FieldSpec('batch_number', 'Batch number', required: true, list: true),
          FieldSpec('recipe_id', 'Recipe', type: FieldType.lookup, lookupTable: 'recipes', required: true, list: true),
          FieldSpec('planned_quantity', 'Planned quantity', type: FieldType.number, required: true, list: true, min: 0.001),
          FieldSpec('produced_quantity', 'Produced quantity', type: FieldType.number, defaultValue: 0, list: true, min: 0),
          FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'planned', list: true, options: {
            'planned': 'Planned', 'in_progress': 'In progress', 'completed': 'Completed', 'cancelled': 'Cancelled',
          }),
          FieldSpec('scheduled_for', 'Scheduled for', type: FieldType.date, required: true, list: true),
          FieldSpec('notes', 'Notes', type: FieldType.multiline),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Production',
      body: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Batches'),
                Tab(text: 'Recipes'),
                Tab(text: 'Ingredients'),
                Tab(text: 'Products'),
                Tab(text: 'Inventory items'),
                Tab(text: 'Categories'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: _batchSpec,
                    readPermission: 'production.read',
                    writePermission: 'production.write',
                    emptyMessage:
                        'No batches scheduled. Create a batch to plan production.',
                    actions: (row) {
                      final status = row['status']?.toString();
                      if (status == 'completed' || status == 'cancelled') {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Complete batch',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) async {
                            final planned =
                                asNum(row['planned_quantity']).toString();
                            final result = await showInputDialog(
                              context,
                              title: 'Complete production batch',
                              submitLabel: 'Complete',
                              fields: [
                                InputField(
                                  'actual_quantity',
                                  'Produced quantity',
                                  initial: planned,
                                  type: FieldType.number,
                                  required: true,
                                  min: 0.001,
                                ),
                                const InputField(
                                  'consumption_cost',
                                  'Consumption unit cost override (optional)',
                                  type: FieldType.number,
                                  min: 0,
                                ),
                              ],
                            );
                            if (result == null) return;
                            final response = await session.client.rpc(
                              'complete_production_batch',
                              params: {
                                'target_batch': row['id'],
                                'actual_quantity':
                                    result['actual_quantity'],
                                'target_store': null,
                                'consumption_cost':
                                    result['consumption_cost'],
                              },
                            );
                            if (context.mounted) {
                              showSnack(
                                context,
                                'Batch completed. '
                                '${asMap(response)['movements_created'] ?? ''} stock movements recorded.',
                              );
                            }
                          },
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: recipesSpec,
                    readPermission: 'production.read',
                    writePermission: 'production.write',
                    emptyMessage:
                        'No recipes yet. Add a recipe and its ingredients to produce consistently.',
                  ),
                  CrudTab(
                    spec: recipeItemsSpec,
                    readPermission: 'production.read',
                    writePermission: 'production.write',
                    emptyMessage:
                        'No ingredients. Select a recipe and add inventory items.',
                  ),
                  CrudTab(
                    spec: productsSpec,
                    readPermission: 'production.read',
                    writePermission: 'production.write',
                    emptyMessage:
                        'No products. Add finished products for the point of sale.',
                  ),
                  CrudTab(
                    spec: inventoryItemsSpec,
                    readPermission: 'inventory.read',
                    writePermission: 'inventory.write',
                    emptyMessage:
                        'No inventory items. Add raw materials before building recipes.',
                  ),
                  CrudTab(
                    spec: categoriesSpec,
                    readPermission: 'production.read',
                    writePermission: 'production.write',
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
