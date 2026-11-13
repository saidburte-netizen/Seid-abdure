import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _reload();
    }
  }

  void _reload() {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    _future = session.client
        .rpc('report_dashboard', params: {'target_branch': branch.branchId})
        .then(asMap);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  static const _modules = [
    ('production', 'Production', Icons.bakery_dining, 'production.read'),
    ('sales', 'Sales & POS', Icons.point_of_sale, 'sales.read'),
    ('inventory', 'Inventory', Icons.inventory_2_outlined, 'inventory.read'),
    ('cash', 'Cash & expenses', Icons.account_balance_wallet_outlined, 'cash.read'),
    ('people', 'People & HR', Icons.groups_outlined, 'people.read'),
    ('payroll', 'Payroll', Icons.receipt_long_outlined, 'payroll.read'),
    ('rentals', 'Rentals', Icons.apartment_outlined, 'rentals.read'),
    ('payables', 'Payables', Icons.request_quote_outlined, 'payables.read'),
    ('reports', 'Reports', Icons.bar_chart, 'reports.read'),
    ('settings', 'Settings', Icons.settings_outlined, 'settings.manage'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) {
      return const ModuleScaffold(
        title: 'Dashboard',
        body: EmptyView(message: 'Select a branch to continue.'),
      );
    }
    return ModuleScaffold(
      title: 'Dashboard',
      showHome: false,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _WelcomeHeader(session: session, branch: branch),
            if (session.can('reports.read'))
              AsyncView<Map<String, dynamic>>(
                future: _future ?? Future.value(const {}),
                onRetry: _refresh,
                builder: (context, data) => _DashboardBody(data: data),
              )
            else
              const SectionCard(
                child: Text(
                  'Your role does not include dashboard reporting. Use the module shortcuts below.',
                ),
              ),
            PageHeader(
              title: 'Workspace',
              subtitle: 'All operational areas available to your role.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns >= 3 ? 1.55 : 1.25,
                    children: [
                      for (final module in _modules)
                        if (session.can(module.$4))
                          _ModuleCard(
                            label: module.$2,
                            icon: module.$3,
                            onTap: () => context.go('/module/${module.$1}'),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.session, required this.branch});

  final AuthController session;
  final BranchAccess branch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome${session.fullName == null ? '' : ', ${session.fullName}'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${branch.branchName} • ${branch.roleSlugs.map(prettyLabel).join(', ')}'
                  ' • ${formatDate(DateTime.now())}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                if (session.can('sales.write'))
                  FilledButton.icon(
                    onPressed: () => context.push('/pos'),
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('New sale'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Alerts'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Today sales', formatMoney(data['today_sales']), Icons.today, null),
      ('This month', formatMoney(data['month_sales']), Icons.calendar_month, null),
      ('Cash balance', formatMoney(data['cash_balance']), Icons.account_balance_wallet_outlined, null),
      ('Receivables', formatMoney(data['receivables']), Icons.person_search_outlined, null),
      ('Payables', formatMoney(data['payables']), Icons.request_quote_outlined, null),
      ('Rent outstanding', formatMoney(data['rent_outstanding']), Icons.apartment_outlined, null),
      ('Low stock', formatQuantity(data['low_stock_items']), Icons.warning_amber_outlined, Theme.of(context).colorScheme.error),
      ('Pending expenses', formatQuantity(data['pending_expenses']), Icons.pending_actions_outlined, null),
      ('Pending leave', formatQuantity(data['pending_leave']), Icons.event_busy_outlined, null),
      ('Batches today', formatQuantity(data['batches_today']), Icons.bakery_dining_outlined, null),
      ('Active employees', formatQuantity(data['active_employees']), Icons.groups_outlined, null),
      ('Revenue this month', formatMoney(data['revenue_this_month']), Icons.trending_up, null),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns >= 3 ? 2.0 : 1.55,
            children: [
              for (final card in cards)
                StatCard(
                  label: card.$1,
                  value: card.$2,
                  icon: card.$3,
                  color: card.$4,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      );
}
