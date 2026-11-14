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
  Future<Map<String, dynamic>>? _kpis;
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
    if (session.isCustomer) return;
    _kpis = session.client
        .from('v_dashboard_kpis')
        .select()
        .maybeSingle()
        .then(
          (row) => row == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(row),
        );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _kpis;
  }

  Future<void> _alerts() async {
    final session = SessionScope.of(context);
    try {
      await session.client.rpc('fn_generate_alerts');
      if (mounted) showSnack(context, 'Alerts generated.');
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  static const _modules = [
    ('pos', 'Point of sale', Icons.point_of_sale, 'pos.use'),
    ('sales', 'Sales & returns', Icons.receipt_long_outlined, 'sales.view'),
    ('production', 'Production', Icons.bakery_dining, 'production.manage'),
    ('inventory', 'Inventory', Icons.inventory_2_outlined, 'inventory.view'),
    (
      'cash',
      'Cash & expenses',
      Icons.account_balance_wallet_outlined,
      'cash.view',
    ),
    ('people', 'People & HR', Icons.groups_outlined, 'hr.view'),
    ('payroll', 'Payroll', Icons.receipt_long_outlined, 'payroll.manage'),
    ('rentals', 'Rentals', Icons.apartment_outlined, 'rentals.manage'),
    (
      'credit',
      'Credit control',
      Icons.account_balance_outlined,
      'credit.manage',
    ),
    ('approvals', 'Approvals', Icons.fact_check_outlined, 'expenses.approve'),
    ('reports', 'Reports', Icons.bar_chart, 'reports.view'),
    ('settings', 'Settings', Icons.settings_outlined, 'settings.manage'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.isCustomer) return const _CustomerDashboard();
    final branch = session.selectedBranch;
    if (branch == null) {
      return const ModuleScaffold(
        title: 'Dashboard',
        body: EmptyView(message: 'No branch is available.'),
      );
    }
    return ModuleScaffold(
      title: 'Dashboard',
      showHome: false,
      actions: [
        IconButton(
          tooltip: 'Generate alerts',
          onPressed: _alerts,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _WelcomeHeader(session: session, branch: branch),
            AsyncView<Map<String, dynamic>>(
              future: _kpis ?? Future.value(const {}),
              onRetry: _refresh,
              builder: (context, data) => _KpiGrid(data: data),
            ),
            const PageHeader(
              title: 'Workspace',
              subtitle: 'Open a module to manage the business.',
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
                            onTap: () => context.go(
                              module.$1 == 'pos'
                                  ? '/pos'
                                  : '/module/${module.$1}',
                            ),
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
  Widget build(BuildContext context) {
    final portal = branch.isAdmin
        ? 'Admin portal'
        : branch.isManager
        ? 'Manager portal'
        : 'Staff portal';
    return Padding(
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
                portal,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome${session.fullName == null ? '' : ', ${session.fullName}'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${branch.branchName} • ${branch.roleLabel} • ${formatDate(DateTime.now())}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (session.can('pos.use'))
                FilledButton.icon(
                  onPressed: () => context.push('/pos'),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('New sale'),
                ),
              OutlinedButton.icon(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Alerts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Today sales', formatMoney(data['today_sales']), Icons.today),
      (
        'Cash balance',
        formatMoney(data['cash_balance']),
        Icons.account_balance_wallet_outlined,
      ),
      (
        'Low stock',
        formatQuantity(data['low_stock_items']),
        Icons.warning_amber_outlined,
      ),
      (
        'Overdue credit',
        formatMoney(data['overdue_receivables']),
        Icons.person_search_outlined,
      ),
      ('Rent due', formatMoney(data['rent_due']), Icons.apartment_outlined),
      (
        'Staff present',
        formatQuantity(data['staff_present_today']),
        Icons.groups_outlined,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 620
              ? 2
              : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.2 : 2.4,
            children: [
              for (final card in cards)
                StatCard(label: card.$1, value: card.$2, icon: card.$3),
            ],
          );
        },
      ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CustomerDashboard extends StatefulWidget {
  const _CustomerDashboard();

  @override
  State<_CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<_CustomerDashboard> {
  bool _started = false;
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _receivables = const [];
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    try {
      final customer = await session.client
          .from('customers')
          .select()
          .eq('user_id', session.userId ?? '')
          .maybeSingle();
      if (customer == null) {
        setState(() => _error = 'No customer record is linked to this login.');
        return;
      }
      final orders = await session.client
          .from('cake_orders')
          .select()
          .eq('customer_id', customer['id'])
          .order('created_at', ascending: false);
      final receivables = await session.client
          .from('receivables')
          .select()
          .eq('customer_id', customer['id'])
          .order('due_date', ascending: false);
      if (!mounted) return;
      setState(() {
        _customer = Map<String, dynamic>.from(customer);
        _orders = (orders as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _receivables = (receivables as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'My account',
      showHome: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Customer profile',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asText(
                    _customer?['full_name'],
                    fallback: session.fullName ?? '',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(asText(_customer?['phone'])),
                Text(asText(_customer?['email'])),
              ],
            ),
          ),
          if (_error != null)
            SectionCard(child: Text(_error!))
          else ...[
            SectionCard(
              title: 'Cake orders',
              child: _orders.isEmpty
                  ? const EmptyView(message: 'No cake orders yet.')
                  : Column(
                      children: [
                        for (final order in _orders)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(asText(order['order_no'])),
                            subtitle: Text(
                              '${formatDate(order['due_at'])} • ${prettyLabel(asText(order['status']))}',
                            ),
                            trailing: Text(formatMoney(order['total_amount'])),
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Credit balance',
              child: _receivables.isEmpty
                  ? const EmptyView(message: 'No outstanding credit.')
                  : Column(
                      children: [
                        for (final row in _receivables)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              asText(
                                row['description'],
                                fallback: 'Receivable',
                              ),
                            ),
                            subtitle: Text(
                              'Due ${formatDate(row['due_date'])}',
                            ),
                            trailing: Text(formatMoney(row['balance'])),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
