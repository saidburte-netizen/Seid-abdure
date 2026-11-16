import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../brand/brand.dart';
import '../data/formatting.dart';
import '../data/schema.dart';
import '../l10n/app_localizations.dart';
import 'app_scaffold.dart';
import 'app_ui.dart';
import 'common.dart';
import '../l10n/ui_text.dart';

export 'app_ui.dart';

class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.showHome = true,
    this.isRoot = false,
    this.hero,
    this.showHero = false,
    this.heroSubtitle,
    this.heroHeightFactor = 0.0,
    this.kpiKinds = const [],
    this.kpiItems,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// Kept for source compatibility. [isRoot] is the navigation switch.
  final bool showHome;

  /// The home dashboard is the only screen without a back arrow.
  final bool isRoot;

  /// Retained for source compatibility; the compact header replaces the hero.
  final Widget? hero;
  final bool showHero;
  final String? heroSubtitle;
  final double heroHeightFactor;

  /// Summary numbers loaded from [v_dashboard_kpis] and shown in the header.
  final List<KpiKind> kpiKinds;

  /// Static summary cards for screens without a matching database KPI.
  final List<KpiItem>? kpiItems;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final Widget? strip = kpiItems != null
        ? KpiStrip(items: kpiItems!)
        : (kpiKinds.isEmpty ? null : DashboardKpiStrip(kinds: kpiKinds));
    return AppScaffold(
      isRoot: isRoot,
      drawer: _PortalDrawer(session: session),
      title: Text(
        title,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        ...actions,
        const NotificationAction(),
        _AccountMenu(session: session),
        const SizedBox(width: 4),
      ],
      kpiStrip: strip,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _PortalDrawer extends StatelessWidget {
  const _PortalDrawer({required this.session});

  final AuthController session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context);
    final items = <(String, String, IconData, String?)>[
      ('/', 'Dashboard', Icons.dashboard_outlined, null),
      ('/pos', 'New sale', Icons.point_of_sale_outlined, 'pos.use'),
      ('/sales', 'Sales & returns', Icons.receipt_long_outlined, 'sales.view'),
      (
        '/production',
        'Production',
        Icons.bakery_dining_outlined,
        'production.manage',
      ),
      ('/inventory', 'Inventory', Icons.inventory_2_outlined, 'inventory.view'),
      (
        '/cash',
        'Cash & expenses',
        Icons.account_balance_wallet_outlined,
        'cash.view',
      ),
      ('/people', 'People & HR', Icons.groups_outlined, 'hr.view'),
      ('/payroll', 'Payroll', Icons.payments_outlined, 'payroll.manage'),
      ('/rentals', 'Rentals', Icons.apartment_outlined, 'rentals.manage'),
      (
        '/credit',
        'Credit control',
        Icons.account_balance_outlined,
        'credit.manage',
      ),
      (
        '/approvals',
        'Approvals',
        Icons.fact_check_outlined,
        'expenses.approve',
      ),
      ('/reports', 'Reports', Icons.bar_chart_outlined, 'reports.view'),
      ('/notifications', 'Notifications', Icons.notifications_outlined, null),
      ('/settings', 'Settings', Icons.settings_outlined, null),
    ];
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: scheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(Brand.logoAsset, width: 58, height: 58),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Brand.appName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            Brand.slogan,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  session.selectedBranch?.branchName ??
                      strings.noBranchSelected,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onPrimary),
                ),
                if (session.branches.length > 1)
                  _BranchSelector(session: session),
              ],
            ),
          ),
          for (final item in items)
            if (item.$4 == null || session.can(item.$4!))
              ListTile(
                leading: Icon(item.$3),
                title: Text(_portalLabel(strings, item.$1)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(item.$1);
                },
              ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(strings.signOut),
            onTap: () {
              Navigator.of(context).pop();
              session.signOut();
            },
          ),
        ],
      ),
    );
  }
}

String _portalLabel(AppLocalizations strings, String route) => switch (route) {
  '/' => strings.dashboard,
  '/pos' => strings.newSale,
  '/sales' => strings.salesModule,
  '/production' => strings.productionModule,
  '/inventory' => strings.inventoryModule,
  '/cash' => strings.cashModule,
  '/people' => strings.peopleModule,
  '/payroll' => strings.payrollModule,
  '/rentals' => strings.rentalsModule,
  '/credit' => strings.payablesModule,
  '/approvals' => 'Approvals',
  '/reports' => strings.reportsModule,
  '/notifications' => strings.notificationsModule,
  '/settings' => strings.settingsModule,
  _ => route,
};

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.session});

  final AuthController session;

  @override
  Widget build(BuildContext context) {
    if (session.branches.length <= 1) {
      return Text(
        session.selectedBranch?.branchCode ?? '',
        style: Theme.of(context).textTheme.labelLarge,
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: session.selectedBranchId,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        dropdownColor: Theme.of(context).colorScheme.primary,
        items: [
          for (final branch in session.branches)
            DropdownMenuItem(
              value: branch.branchId,
              child: Text(
                branch.branchCode.isEmpty
                    ? branch.branchName
                    : '${branch.branchName} (${branch.branchCode})',
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) session.selectBranch(value);
        },
      ),
    );
  }
}

class NotificationAction extends StatefulWidget {
  const NotificationAction({super.key});

  @override
  State<NotificationAction> createState() => _NotificationActionState();
}

class _NotificationActionState extends State<NotificationAction> {
  int _unread = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadUnread();
    }
  }

  Future<void> _loadUnread() async {
    final session = SessionScope.of(context);
    try {
      final uid = session.userId;
      if (uid == null) return;
      var query = session.client
          .from('notifications')
          .select('id,is_read')
          .eq('is_read', false);
      final role = session.roleCode;
      if (role != null) {
        query = query.or('user_id.eq.$uid,role_code.eq.$role');
      } else {
        query = query.eq('user_id', uid);
      }
      final notifications = await query
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() => _unread = (notifications as List).length);
    } catch (_) {
      // Notifications are non-critical; a failed badge must not break the app.
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: uiText(context, 'Notifications'),
    onPressed: () async {
      await context.push('/notifications');
      await _loadUnread();
    },
    icon: _unread > 0
        ? Badge(
            label: Text(_unread > 99 ? '99+' : '$_unread'),
            child: const Icon(Icons.notifications_outlined),
          )
        : const Icon(Icons.notifications_outlined),
  );
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.session});

  final AuthController session;

  @override
  Widget build(BuildContext context) {
    final name = session.fullName?.trim();
    final strings = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: strings.accountPreferences,
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            await _editProfile(context);
          case 'settings':
            await context.push('/settings');
          case 'light':
            await session.setThemeMode(ThemeMode.light);
          case 'dark':
            await session.setThemeMode(ThemeMode.dark);
          case 'system':
            await session.setThemeMode(ThemeMode.system);
          case 'en':
            await session.setLocale('en');
          case 'am':
            await session.setLocale('am');
          case 'om':
            await session.setLocale('om');
          case 'signOut':
            await session.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                (name == null || name.isEmpty)
                    ? '?'
                    : name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
            title: Text(
              name == null || name.isEmpty ? strings.myAccount : name,
            ),
            subtitle: Text(session.userEmail ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(strings.editDisplayName),
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(strings.settingsModule),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'light',
          child: ListTile(
            leading: Icon(
              session.themeMode == ThemeMode.light
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(strings.lightTheme),
          ),
        ),
        PopupMenuItem(
          value: 'dark',
          child: ListTile(
            leading: Icon(
              session.themeMode == ThemeMode.dark
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(strings.darkTheme),
          ),
        ),
        PopupMenuItem(
          value: 'system',
          child: ListTile(
            leading: Icon(
              session.themeMode == ThemeMode.system
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(strings.systemTheme),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'en',
          child: ListTile(
            leading: Icon(
              session.locale?.languageCode == 'en'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(strings.english),
          ),
        ),
        PopupMenuItem(
          value: 'am',
          child: ListTile(
            leading: Icon(
              session.locale?.languageCode == 'am'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const Text('አማርኛ'),
          ),
        ),
        PopupMenuItem(
          value: 'om',
          child: ListTile(
            leading: Icon(
              session.locale?.languageCode == 'om'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: const LText('Afaan Oromoo'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'signOut',
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(strings.signOut),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final controller = TextEditingController(text: session.fullName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).displayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).fullName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await session.updateProfileName(result);
    }
    controller.dispose();
  }
}

/// A form dialog for values that are not simple table rows, such as RPC
/// payloads. It returns the entered map or null when cancelled.
Future<Map<String, dynamic>?> showInputDialog(
  BuildContext context, {
  required String title,
  required List<InputField> fields,
  String submitLabel = 'Submit',
}) => showDialog<Map<String, dynamic>>(
  context: context,
  barrierDismissible: false,
  builder: (context) =>
      _InputDialog(title: title, fields: fields, submitLabel: submitLabel),
);

class InputField {
  const InputField(
    this.key,
    this.label, {
    this.initial,
    this.type = FieldType.text,
    this.required = false,
    this.options = const {},
    this.hint,
    this.min,
    this.max,
  });

  final String key;
  final String label;
  final String? initial;
  final FieldType type;
  final bool required;
  final Map<String, String> options;
  final String? hint;
  final num? min;
  final num? max;
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.fields,
    required this.submitLabel,
  });

  final String title;
  final List<InputField> fields;
  final String submitLabel;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _booleans = <String, bool>{};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.key] = TextEditingController(
        text: field.initial ?? '',
      );
      if (field.type == FieldType.boolean) {
        _booleans[field.key] = field.initial == 'true';
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_dirty && !await confirmDiscardChanges(context)) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      if (!await confirmDiscardChanges(context)) return;
      _dirty = false;
      if (context.mounted) Navigator.of(context).pop();
    },
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildField(field),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const LText('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    ),
  );

  Widget _buildField(InputField field) {
    if (field.type == FieldType.boolean) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: LText(field.label),
        value: _booleans[field.key] ?? false,
        onChanged: (value) => setState(() {
          _dirty = true;
          _booleans[field.key] = value;
        }),
      );
    }
    if (field.type == FieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: _controllers[field.key]!.text.isEmpty
            ? null
            : _controllers[field.key]!.text,
        decoration: InputDecoration(labelText: uiText(context, field.label)),
        items: [
          for (final option in field.options.entries)
            DropdownMenuItem(value: option.key, child: Text(option.value)),
        ],
        validator: (value) =>
            field.required && value == null ? 'Required' : null,
        onChanged: (value) {
          _dirty = true;
          _controllers[field.key]!.text = value ?? '';
        },
      );
    }
    return TextFormField(
      controller: _controllers[field.key],
      keyboardType:
          field.type == FieldType.number || field.type == FieldType.integer
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      minLines: field.type == FieldType.multiline ? 2 : 1,
      maxLines: field.type == FieldType.multiline ? 4 : 1,
      decoration: InputDecoration(
        labelText: uiText(context, field.label),
        hintText: field.hint == null ? null : uiText(context, field.hint!),
      ),
      onChanged: (_) => _dirty = true,
      validator: (value) {
        if (field.required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (field.type == FieldType.number || field.type == FieldType.integer) {
          if (value != null && value.trim().isNotEmpty) {
            final number = num.tryParse(value.trim());
            if (number == null) return 'Enter a number';
            if (field.min != null && number < field.min!) {
              return 'Must be at least ${field.min}';
            }
            if (field.max != null && number > field.max!) {
              return 'Must be at most ${field.max}';
            }
          }
        }
        if (field.type == FieldType.date && value != null && value.isNotEmpty) {
          if (DateTime.tryParse(value) == null) return 'Use YYYY-MM-DD';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field.type == FieldType.boolean) {
        result[field.key] = _booleans[field.key] == true;
        continue;
      }
      final text = _controllers[field.key]!.text.trim();
      if (field.type == FieldType.number) {
        result[field.key] = text.isEmpty ? null : num.tryParse(text);
      } else if (field.type == FieldType.integer) {
        result[field.key] = text.isEmpty ? null : int.tryParse(text);
      } else {
        result[field.key] = text.isEmpty ? null : text;
      }
    }
    Navigator.of(context).pop(result);
  }
}

/// A small date-range control used by reports.
class DateRangePicker extends StatelessWidget {
  const DateRangePicker({
    required this.range,
    required this.onChanged,
    super.key,
  });

  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(DateTime.now().year - 5),
        lastDate: DateTime(DateTime.now().year + 2),
        initialDateRange: range,
      );
      if (selected != null) onChanged(selected);
    },
    icon: const Icon(Icons.date_range_outlined),
    label: Text('${formatDate(range.start)} – ${formatDate(range.end)}'),
  );
}
