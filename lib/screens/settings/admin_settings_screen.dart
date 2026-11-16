import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../data/export.dart';
import '../../data/formatting.dart';
import '../../data/pdf_export.dart';
import '../../data/repository.dart';
import '../../data/schema.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/common.dart';
import '../../widgets/crud_tab.dart';
import '../../l10n/ui_text.dart';

/// A single permission-aware master-data screen used by Settings.
class SettingsTableScreen extends StatelessWidget {
  const SettingsTableScreen({
    required this.title,
    required this.table,
    required this.readPermission,
    required this.writePermission,
    this.adminOnly = false,
    super.key,
  });

  final String title;
  final String table;
  final String readPermission;
  final String writePermission;
  final bool adminOnly;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final isAdmin = session.selectedBranch?.isAdmin ?? false;
    return AppScaffold(
      title: Text(title),
      body: (!adminOnly || isAdmin) && session.can(readPermission)
          ? CrudTab(
              spec: specFor(table),
              readPermission: readPermission,
              writePermission: writePermission,
            )
          : EmptyView(message: strings.noPermissionForArea),
    );
  }
}

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final tabs = <(String, String, String)>[
      ('Units', 'units', 'units.manage'),
      ('Categories', 'categories', 'categories.manage'),
      ('Expense categories', 'expense_categories', 'expenses.manage'),
      ('Departments', 'departments', 'hr.manage'),
      ('Shifts', 'shifts', 'hr.manage'),
      ('Leave types', 'leave_types', 'hr.manage'),
      ('Tax brackets', 'tax_brackets', 'payroll.manage'),
    ].where((tab) => session.can(tab.$3)).toList();
    if (tabs.isEmpty) {
      return AppScaffold(
        title: Text(strings.masterData),
        body: EmptyView(message: strings.noPermissionForArea),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: AppScaffold(
        title: Text(strings.masterData),
        bottomNavigationBar: TabBar(
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab.$1)],
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              CrudTab(
                spec: specFor(tab.$2),
                readPermission: tab.$3,
                writePermission: tab.$3,
              ),
          ],
        ),
      ),
    );
  }
}

class RolePermissionsScreen extends StatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  State<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _permissions = const [];
  Set<String> _granted = {};
  bool _loading = true;
  String? _error;
  String? _savingKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _roles.isEmpty) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        session.client.from('roles').select('code,name').order('name'),
        session.client
            .from('permissions')
            .select('code,module,description')
            .order('module')
            .order('code'),
        session.client
            .from('role_permissions')
            .select('role_code,permission_code'),
      ]);
      if (!mounted) return;
      setState(() {
        _roles = List<Map<String, dynamic>>.from(results[0] as List);
        _permissions = List<Map<String, dynamic>>.from(results[1] as List);
        _granted = {
          for (final row in results[2] as List)
            '${row['role_code']}|${row['permission_code']}',
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyMessage(error);
      });
    }
  }

  Future<void> _toggle(String role, String permission, bool enabled) async {
    final session = SessionScope.of(context);
    final key = '$role|$permission';
    setState(() => _savingKey = key);
    try {
      if (enabled) {
        await session.client.from('role_permissions').insert({
          'role_code': role,
          'permission_code': permission,
        });
      } else {
        await session.client
            .from('role_permissions')
            .delete()
            .eq('role_code', role)
            .eq('permission_code', permission);
      }
      if (!mounted) return;
      setState(() {
        if (enabled) {
          _granted.add(key);
        } else {
          _granted.remove(key);
        }
      });
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final isAdmin = session.selectedBranch?.isAdmin ?? false;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final permission in _permissions) {
      final module = permission['module'] as String? ?? 'other';
      grouped.putIfAbsent(module, () => []).add(permission);
    }
    return AppScaffold(
      title: Text(strings.rolePermissions),
      actions: [
        IconButton(
          tooltip: strings.refresh,
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: !isAdmin
          ? EmptyView(message: strings.noPermissionForArea)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final role in _roles)
                    SectionCard(
                      title: role['name'] as String? ?? role['code'] as String?,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 4,
                              ),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final permission in entry.value)
                                  _permissionChip(
                                    role['code'] as String,
                                    permission,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _permissionChip(String role, Map<String, dynamic> permission) {
    final code = permission['code'] as String? ?? '';
    final key = '$role|$code';
    final selected = _granted.contains(key);
    final saving = _savingKey == key;
    return FilterChip(
      label: Text(code),
      tooltip: permission['description'] as String? ?? code,
      selected: selected,
      onSelected: saving ? null : (value) => _toggle(role, code, value),
      avatar: saving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _table = TextEditingController();
  final _user = TextEditingController();
  final _action = ValueNotifier<String?>(null);
  DateTime? _from;
  DateTime? _to;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _rows.isEmpty) _load();
  }

  @override
  void dispose() {
    _table.dispose();
    _user.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = session.client.from('audit_logs').select();
      if (_table.text.trim().isNotEmpty) {
        query = query.ilike('table_name', '%${_table.text.trim()}%');
      }
      if (_user.text.trim().isNotEmpty) {
        query = query.eq('user_id', _user.text.trim());
      }
      if (_action.value != null) query = query.eq('action', _action.value!);
      if (_from != null) {
        query = query.gte(
          'created_at',
          DateTime(_from!.year, _from!.month, _from!.day).toIso8601String(),
        );
      }
      if (_to != null) {
        query = query.lt(
          'created_at',
          DateTime(
            _to!.year,
            _to!.month,
            _to!.day,
          ).add(const Duration(days: 1)).toIso8601String(),
        );
      }
      final rows = await query.order('created_at', ascending: false).limit(300);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyMessage(error);
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: (from ? _from : _to) ?? now,
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.auditLog),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _table,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'Table'),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _user,
                    decoration: InputDecoration(
                      labelText: uiText(context, 'User ID'),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _action,
                    builder: (context, value, _) =>
                        DropdownButtonFormField<String?>(
                          initialValue: value,
                          decoration: InputDecoration(
                            labelText: uiText(context, 'Action'),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(
                              value: 'INSERT',
                              child: Text('Insert'),
                            ),
                            DropdownMenuItem(
                              value: 'UPDATE',
                              child: Text('Update'),
                            ),
                            DropdownMenuItem(
                              value: 'DELETE',
                              child: LText('Delete'),
                            ),
                          ],
                          onChanged: (value) {
                            _action.value = value;
                            _load();
                          },
                        ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(from: true),
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_from == null ? 'From date' : dateOnly(_from!)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(from: false),
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_to == null ? 'To date' : dateOnly(_to!)),
                ),
                IconButton.filledTonal(
                  tooltip: strings.search,
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                ),
                if (_from != null || _to != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _from = null;
                        _to = null;
                      });
                      _load();
                    },
                    child: const Text('Clear dates'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _rows.isEmpty
                ? EmptyView(
                    message: uiText(
                      context,
                      'No audit entries match these filters.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        return ListTile(
                          leading: Icon(_actionIcon(row['action'] as String?)),
                          title: Text(
                            '${row['action'] ?? ''} • ${row['table_name'] ?? ''}',
                          ),
                          subtitle: Text(
                            [
                              if (row['record_id'] != null)
                                'Record ${row['record_id']}',
                              if (row['created_at'] != null)
                                formatDateTime(row['created_at']),
                              if (row['user_id'] != null)
                                'User ${row['user_id']}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          onTap: () => _showDetails(row),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(String? action) => switch (action) {
    'INSERT' => Icons.add_circle_outline,
    'UPDATE' => Icons.edit_outlined,
    'DELETE' => Icons.delete_outline,
    _ => Icons.history,
  };

  Future<void> _showDetails(Map<String, dynamic> row) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${row['action'] ?? ''} ${row['table_name'] ?? ''}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(row),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const LText('Close'),
        ),
      ],
    ),
  );
}

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  static const _reports = {
    'v_daily_sales': 'Daily sales',
    'v_product_sales': 'Product sales',
    'v_expense_summary': 'Expense summary',
    'v_cash_account_balances': 'Cash account balances',
    'v_low_stock': 'Low stock',
    'v_stock_valuation': 'Stock valuation',
    'v_customer_balances': 'Customer balances',
    'v_supplier_balances': 'Supplier balances',
    'v_receivable_aging': 'Receivable aging',
    'v_payable_aging': 'Payable aging',
    'v_rent_status': 'Rent status',
    'v_payroll_summary': 'Payroll summary',
  };

  String _selected = _reports.keys.first;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _rows.isEmpty) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await session.client.from(_selected).select().limit(5000);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyMessage(error);
      });
    }
  }

  Future<void> _exportCsv() async {
    final csv = rowsToCsv(_rows);
    final path = await saveCsvFile(_selected, csv);
    if (!mounted) return;
    if (path == null) {
      await copyText(context, csv, 'CSV');
      return;
    }
    showSnack(context, AppLocalizations.of(context).exportSaved);
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) return;
    try {
      final keys = _rows.first.keys.take(8).toList();
      final session = SessionScope.of(context);
      final bytes = await BrandPdf.document(
        title: _reports[_selected] ?? _selected,
        documentNumber: dateOnly(DateTime.now()),
        branchName: session.selectedBranch?.branchName ?? '',
        subtitle: '${_rows.length} rows exported from Brade and Cake House',
        columns: [
          for (final key in keys)
            PdfColumn(
              key.replaceAll('_', ' ').toUpperCase(),
              key,
              numeric: _rows.first[key] is num,
            ),
        ],
        rows: _rows,
        footer: 'Brade and Cake House • hani brade and cake',
      );
      await BrandPdf.share(fileName: _selected, bytes: bytes);
      if (mounted) showSnack(context, AppLocalizations.of(context).exportSaved);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.dataExport),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selected,
            isExpanded: true,
            decoration: InputDecoration(labelText: uiText(context, 'Report')),
            items: [
              for (final entry in _reports.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selected = value);
              _load();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loading || _rows.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.table_view_outlined),
                label: Text(strings.csvExport),
              ),
              OutlinedButton.icon(
                onPressed: _loading || _rows.isEmpty ? null : _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(strings.pdfExport),
              ),
              IconButton.filledTonal(
                tooltip: strings.refresh,
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            EmptyView(message: uiText(context, 'This report returned no rows.'))
          else
            SectionCard(
              title: '${_rows.length} rows',
              child: Text(
                _rows.first.keys.take(8).join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class AccountsSettingsScreen extends StatelessWidget {
  const AccountsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final tabs = <(String, String, String, String)>[
      ('Stores', 'stores', 'inventory.view', 'inventory.manage'),
      ('Cash accounts', 'cash_accounts', 'cash.view', 'cash.manage'),
    ].where((tab) => session.can(tab.$3)).toList();
    if (tabs.isEmpty) {
      return AppScaffold(
        title: const LText('Stores & cash accounts'),
        body: EmptyView(message: strings.noPermissionForArea),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: AppScaffold(
        title: const LText('Stores & cash accounts'),
        bottomNavigationBar: TabBar(
          tabs: [for (final tab in tabs) Tab(text: tab.$1)],
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              CrudTab(
                spec: specFor(tab.$2),
                readPermission: tab.$3,
                writePermission: tab.$4,
              ),
          ],
        ),
      ),
    );
  }
}
