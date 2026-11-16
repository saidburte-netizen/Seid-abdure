import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/save_flow.dart';
import '../l10n/app_localizations.dart';
import '../widgets/brand_ui.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>>? _kpis;
  bool _started = false;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _addListener();
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _addListener() {
    if (_listenerAdded) return;
    DataRevision.notifier.addListener(_reload);
    _listenerAdded = true;
  }

  void _removeListener() {
    DataRevision.notifier.removeListener(_reload);
    _listenerAdded = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _kpis = _loadKpis();
    }
  }

  Future<Map<String, dynamic>> _loadKpis() {
    final session = SessionScope.of(context);
    if (session.isCustomer) return Future.value(const {});
    return session.client
        .from('v_dashboard_kpis')
        .select()
        .maybeSingle()
        .then(
          (row) => row == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(row),
        );
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _kpis = _loadKpis());
  }

  Future<void> _refresh() async {
    final future = _loadKpis();
    setState(() => _kpis = future);
    await future;
  }

  Future<void> _alerts() async {
    final session = SessionScope.of(context);
    try {
      await SaveFlow.write(
        module: 'Dashboard',
        target: 'fn_generate_alerts',
        action: () => session.client.rpc('fn_generate_alerts'),
      );
      if (mounted) {
        showSnack(context, AppLocalizations.of(context).alertsGenerated);
      }
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  static const List<(String, IconData, String?)> _modules = [
    ('pos', Icons.point_of_sale, 'pos.use'),
    ('cash', Icons.account_balance_wallet_outlined, 'cash.view'),
    ('sales', Icons.receipt_long_outlined, 'sales.view'),
    ('inventory', Icons.inventory_2_outlined, 'inventory.view'),
    ('production', Icons.bakery_dining, 'production.manage'),
    ('people', Icons.groups_outlined, 'hr.view'),
    ('payroll', Icons.receipt_long_outlined, 'payroll.manage'),
    ('rentals', Icons.apartment_outlined, 'rentals.manage'),
    ('credit', Icons.account_balance_outlined, 'credit.manage'),
    ('approvals', Icons.fact_check_outlined, 'expenses.approve'),
    ('reports', Icons.bar_chart, 'reports.view'),
    ('settings', Icons.settings_outlined, null),
  ];

  String _moduleLabel(AppLocalizations strings, String name) => switch (name) {
    'pos' => strings.newSale,
    'sales' => strings.salesModule,
    'production' => strings.productionModule,
    'inventory' => strings.inventoryModule,
    'cash' => strings.cashModule,
    'people' => strings.peopleModule,
    'payroll' => strings.payrollModule,
    'rentals' => strings.rentalsModule,
    'credit' => strings.payablesModule,
    'approvals' => strings.approvals,
    'reports' => strings.reportsModule,
    _ => strings.settingsModule,
  };

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    if (session.isCustomer) return const _CustomerDashboard();
    final branch = session.selectedBranch;
    if (branch == null) {
      return ModuleScaffold(
        title: strings.dashboard,
        isRoot: true,
        showHero: false,
        body: EmptyView(message: strings.noBranchSelected),
      );
    }
    return ModuleScaffold(
      title: strings.dashboard,
      isRoot: true,
      actions: [
        IconButton(
          tooltip: strings.runAlerts,
          onPressed: _alerts,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _WelcomeLine(session: session, branch: branch),
            AsyncView<Map<String, dynamic>>(
              future: _kpis ?? Future.value(const {}),
              onRetry: _refresh,
              builder: (context, data) => _KpiGrid(data: data),
            ),
            SectionBar(
              title: strings.workspace,
              subtitle: strings.workspaceSubtitle,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        if (module.$3 == null || session.can(module.$3!))
                          _ModuleCard(
                            label: _moduleLabel(strings, module.$1),
                            icon: module.$2,
                            onTap: () => context.push(
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

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cards = [
      (
        strings.todaySales,
        formatMoney(data['today_sales']),
        Icons.today,
      ),
      (
        strings.cashBalance,
        formatMoney(data['cash_balance']),
        Icons.account_balance_wallet_outlined,
      ),
      (
        strings.lowStock,
        formatQuantity(data['low_stock_items']),
        Icons.warning_amber_outlined,
      ),
      (
        uiText(context, 'Overdue'),
        formatMoney(data['overdue_receivables']),
        Icons.person_search_outlined,
      ),
      (
        uiText(context, 'Rent due'),
        formatMoney(data['rent_due']),
        Icons.apartment_outlined,
      ),
      (
        uiText(context, 'Staff present'),
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

class _WelcomeLine extends StatelessWidget {
  const _WelcomeLine({required this.session, required this.branch});

  final AuthController session;
  final BranchAccess branch;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final portal = branch.isAdmin
        ? strings.adminPortal
        : branch.isManager
        ? strings.managerPortal
        : strings.teamPortal;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.fullName == null
                      ? strings.welcome
                      : '${strings.welcome}, ${session.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${branch.branchName} • $portal • ${formatDate(DateTime.now())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
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
  bool _loading = true;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customer = await session.client
          .from('customers')
          .select()
          .eq('user_id', session.userId ?? '')
          .maybeSingle();
      if (customer == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No customer record is linked to this login.';
          });
        }
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
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = readableError(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'My account'),
      isRoot: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: uiText(context, 'Customer profile'),
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
                    ErrorView(message: _error!, onRetry: _load)
                  else ...[
                    SectionCard(
                      title: uiText(context, 'Cake orders'),
                      child: _orders.isEmpty
                          ? EmptyView(
                              message: uiText(context, 'No cake orders yet.'),
                            )
                          : Column(
                              children: [
                                for (final order in _orders)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(asText(order['order_no'])),
                                    subtitle: Text(
                                      '${formatDate(order['due_at'])} • ${prettyLabel(asText(order['status']))}',
                                    ),
                                    trailing: Text(
                                      formatMoney(order['total_amount']),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    SectionCard(
                      title: uiText(context, 'Credit balance'),
                      child: _receivables.isEmpty
                          ? EmptyView(
                              message: uiText(
                                context,
                                'No outstanding credit.',
                              ),
                            )
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
            ),
    );
  }
}
