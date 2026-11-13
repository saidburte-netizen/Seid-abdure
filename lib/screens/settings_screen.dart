import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../brand/brand.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModuleScaffold(
    title: 'Settings & administration',
    body: DefaultTabController(
      length: 6,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Organization'),
              Tab(text: 'Branch'),
              Tab(text: 'Branches'),
              Tab(text: 'Members'),
              Tab(text: 'Roles'),
              Tab(text: 'Numbering'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OrganizationSettings(),
                _BranchSettings(),
                CrudTab(
                  spec: _branchesSpec,
                  readPermission: 'settings.manage',
                  writePermission: 'settings.manage',
                ),
                _MembersView(),
                _RolesView(),
                CrudTab(
                  spec: _numberingSpec,
                  readPermission: 'settings.manage',
                  writePermission: 'settings.manage',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrganizationSettings extends StatefulWidget {
  const _OrganizationSettings();

  @override
  State<_OrganizationSettings> createState() => _OrganizationSettingsState();
}

class _OrganizationSettingsState extends State<_OrganizationSettings> {
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();
  final _tin = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _taxRate = TextEditingController();
  final _fiscalMonth = TextEditingController();
  final _footer = TextEditingController();
  String _locale = 'en';
  bool _lowStockAlerts = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _row;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _row == null) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    try {
      final row = await session.client
          .from('organization_settings')
          .select()
          .eq('id', true)
          .maybeSingle();
      if (!mounted) return;
      _row = row == null ? null : Map<String, dynamic>.from(row);
      final data = _row ?? {};
      _legalName.text = asText(data['legal_name'], fallback: Brand.appName);
      _tradeName.text = asText(data['trade_name'], fallback: Brand.appName);
      _tin.text = asText(data['tin']);
      _phone.text = asText(data['phone']);
      _email.text = asText(data['email']);
      _address.text = asText(data['address']);
      _taxRate.text = (asNum(data['default_tax_rate'] ?? 0.15) * 100)
          .toString();
      _fiscalMonth.text = asText(
        data['fiscal_year_start_month'],
        fallback: '7',
      );
      _footer.text = asText(data['receipt_footer']);
      _locale = asText(data['default_locale'], fallback: 'en');
      _lowStockAlerts = asBool(data['low_stock_alerts'], fallback: true);
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _legalName,
      _tradeName,
      _tin,
      _phone,
      _email,
      _address,
      _taxRate,
      _fiscalMonth,
      _footer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final session = SessionScope.of(context);
    setState(() => _saving = true);
    try {
      await session.client.from('organization_settings').upsert({
        'id': true,
        'legal_name': _legalName.text.trim(),
        'trade_name': _tradeName.text.trim(),
        'tin': _tin.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'default_tax_rate': asNum(_taxRate.text) / 100,
        'fiscal_year_start_month': int.tryParse(_fiscalMonth.text.trim()) ?? 7,
        'receipt_footer': _footer.text.trim(),
        'default_locale': _locale,
        'low_stock_alerts': _lowStockAlerts,
        'updated_by': session.userId,
      });
      if (mounted) showSnack(context, 'Organization settings saved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Legal organization',
          trailing: Image.asset(Brand.logoAsset, width: 54, height: 54),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _text('Legal name', _legalName),
                  _text('Trade name', _tradeName),
                  _text('TIN', _tin),
                  _text('Phone', _phone),
                  _text('Email', _email),
                  _text('Address', _address),
                  _text('Default tax rate (%)', _taxRate, number: true),
                  _text(
                    'Fiscal year start month',
                    _fiscalMonth,
                    number: true,
                    integer: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _locale,
                      decoration: const InputDecoration(
                        labelText: 'Default locale',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                        DropdownMenuItem(
                          value: 'om',
                          child: Text('Afaan Oromoo'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _locale = value ?? 'en'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Low stock alerts'),
                      value: _lowStockAlerts,
                      onChanged: (value) =>
                          setState(() => _lowStockAlerts = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _footer,
                decoration: const InputDecoration(labelText: 'Receipt footer'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save organization'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    bool number = false,
    bool integer = false,
  }) => SizedBox(
    width: 300,
    child: TextField(
      controller: controller,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: !integer)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _BranchSettings extends StatefulWidget {
  const _BranchSettings();

  @override
  State<_BranchSettings> createState() => _BranchSettingsState();
}

class _BranchSettingsState extends State<_BranchSettings> {
  final _receiptPrefix = TextEditingController();
  final _salePrefix = TextEditingController();
  final _taxRate = TextEditingController();
  final _serviceRate = TextEditingController();
  bool _taxInclusive = false;
  bool _dailyClose = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  BranchRepository? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch != null) {
      _repo = BranchRepository(session.client, branch.branchId);
      if (_loading) _load();
    }
  }

  Future<void> _load() async {
    try {
      final row = await _repo!.settings();
      if (!mounted) return;
      _receiptPrefix.text = asText(row['receipt_prefix'], fallback: 'RCPT');
      _salePrefix.text = asText(row['sale_prefix'], fallback: 'SALE');
      _taxRate.text = (asNum(row['tax_rate'] ?? 0.15) * 100).toString();
      _serviceRate.text = (asNum(row['service_charge_rate']) * 100).toString();
      _taxInclusive = asBool(row['tax_inclusive']);
      _dailyClose = asBool(row['daily_close_required'], fallback: true);
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _receiptPrefix.dispose();
    _salePrefix.dispose();
    _taxRate.dispose();
    _serviceRate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final existing = await _repo!.first('branch_settings');
      final values = {
        'receipt_prefix': _receiptPrefix.text.trim(),
        'sale_prefix': _salePrefix.text.trim(),
        'tax_rate': asNum(_taxRate.text) / 100,
        'service_charge_rate': asNum(_serviceRate.text) / 100,
        'tax_inclusive': _taxInclusive,
        'daily_close_required': _dailyClose,
      };
      if (existing == null) {
        await _repo!.insert('branch_settings', values);
      } else {
        await _repo!.update(
          'branch_settings',
          _repo!.branchId,
          values,
          primaryKey: 'branch_id',
        );
      }
      if (mounted) showSnack(context, 'Branch settings saved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Current branch configuration',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _text('Receipt prefix', _receiptPrefix),
                  _text('Sale prefix', _salePrefix),
                  _text('Tax rate (%)', _taxRate, number: true),
                  _text('Service charge (%)', _serviceRate, number: true),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prices include tax'),
                value: _taxInclusive,
                onChanged: (value) => setState(() => _taxInclusive = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require daily business close'),
                value: _dailyClose,
                onChanged: (value) => setState(() => _dailyClose = value),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save branch settings'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) => SizedBox(
    width: 240,
    child: TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _MembersView extends StatefulWidget {
  const _MembersView();

  @override
  State<_MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<_MembersView> {
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _roles = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    try {
      final members = await session.client
          .from('branch_memberships')
          .select(
            'id, user_id, is_active, roles(name, slug), profiles(full_name)',
          )
          .eq('branch_id', branch.branchId)
          .order('created_at');
      final roles = await session.client
          .from('roles')
          .select('id, name, slug')
          .eq('branch_id', branch.branchId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _members = (members as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _roles = (roles as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    if (_roles.isEmpty) {
      showSnack(context, 'No roles exist for this branch.', error: true);
      return;
    }
    final result = await showInputDialog(
      context,
      title: 'Add branch member',
      submitLabel: 'Add member',
      fields: [
        const InputField('email', 'Account email', required: true),
        InputField(
          'role',
          'Role',
          required: true,
          type: FieldType.select,
          initial: _roles.first['slug']?.toString(),
          options: {
            for (final role in _roles)
              role['slug'] as String: asText(role['name']),
          },
        ),
      ],
    );
    if (result == null) return;
    try {
      await session.client.rpc(
        'assign_branch_membership',
        params: {
          'target_branch': branch.branchId,
          'member_email': result['email'],
          'role_slug': result['role'],
        },
      );
      if (mounted) {
        showSnack(context, 'Member added.');
        await _load();
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _toggleMember(Map<String, dynamic> member) async {
    final session = SessionScope.of(context);
    try {
      await session.client
          .from('branch_memberships')
          .update({'is_active': !asBool(member['is_active'], fallback: true)})
          .eq('id', member['id']);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add member'),
          ),
        ),
        const SizedBox(height: 12),
        for (final member in _members)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  asText(
                    asMap(member['profiles'])['full_name'],
                    fallback: '?',
                  ).characters.first.toUpperCase(),
                ),
              ),
              title: Text(
                asText(
                  asMap(member['profiles'])['full_name'],
                  fallback: 'Unnamed member',
                ),
              ),
              subtitle: Text(
                '${asText(asMap(member['roles'])['name'])} • '
                '${asBool(member['is_active'], fallback: true) ? 'Active' : 'Inactive'}',
              ),
              trailing: Switch(
                value: asBool(member['is_active'], fallback: true),
                onChanged: (_) => _toggleMember(member),
              ),
            ),
          ),
        if (_members.isEmpty)
          const EmptyView(
            message: 'No members have been added to this branch.',
          ),
      ],
    );
  }
}

class _RolesView extends StatefulWidget {
  const _RolesView();

  @override
  State<_RolesView> createState() => _RolesViewState();
}

class _RolesViewState extends State<_RolesView> {
  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _permissions = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    try {
      final roles = await session.client
          .from('roles')
          .select('id, name, slug, branch_id')
          .eq('branch_id', branch.branchId)
          .order('name');
      final permissions = await session.client
          .from('permissions')
          .select('id, permission_key, description');
      if (!mounted) return;
      setState(() {
        _roles = (roles as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _permissions = (permissions as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createRole() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    final result = await showInputDialog(
      context,
      title: 'Create role',
      submitLabel: 'Create role',
      fields: const [
        InputField('name', 'Role name', required: true),
        InputField('slug', 'Role slug', required: true, hint: 'e.g. cashier'),
      ],
    );
    if (result == null) return;
    try {
      await session.client.from('roles').insert({
        'branch_id': branch.branchId,
        'name': result['name'],
        'slug': result['slug'].toString().toLowerCase().replaceAll(' ', '_'),
      });
      if (mounted) await _load();
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _managePermissions(Map<String, dynamic> role) async {
    final session = SessionScope.of(context);
    try {
      final current = await session.client
          .from('role_permissions')
          .select('permission_id')
          .eq('role_id', role['id']);
      final selected = {
        for (final row in (current as List)) row['permission_id'] as String,
      };
      if (!mounted) return;
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (context) => _PermissionDialog(
          role: role,
          permissions: _permissions,
          selected: selected,
        ),
      );
      if (result == null) return;
      await session.client
          .from('role_permissions')
          .delete()
          .eq('role_id', role['id']);
      if (result.isNotEmpty) {
        await session.client.from('role_permissions').insert([
          for (final permissionId in result)
            {'role_id': role['id'], 'permission_id': permissionId},
        ]);
      }
      if (mounted) showSnack(context, 'Role permissions saved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _createRole,
            icon: const Icon(Icons.add),
            label: const Text('Create role'),
          ),
        ),
        const SizedBox(height: 12),
        for (final role in _roles)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.security_outlined),
              title: Text(asText(role['name'])),
              subtitle: Text(asText(role['slug'])),
              trailing: OutlinedButton(
                onPressed: () => _managePermissions(role),
                child: const Text('Permissions'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.role,
    required this.permissions,
    required this.selected,
  });

  final Map<String, dynamic> role;
  final List<Map<String, dynamic>> permissions;
  final Set<String> selected;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Permissions — ${asText(widget.role['name'])}'),
    content: SizedBox(
      width: 560,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final permission in widget.permissions)
            CheckboxListTile(
              value: _selected.contains(permission['id']),
              title: Text(asText(permission['permission_key'])),
              subtitle: Text(asText(permission['description'])),
              onChanged: (value) => setState(() {
                final id = permission['id'] as String;
                if (value == true) {
                  _selected.add(id);
                } else {
                  _selected.remove(id);
                }
              }),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('Save permissions'),
      ),
    ],
  );
}

const _branchesSpec = TableSpec(
  table: 'branches',
  title: 'Branches',
  singular: 'Branch',
  orderBy: 'name',
  branchScoped: false,
  searchColumns: ['name', 'code'],
  fields: [
    FieldSpec('name', 'Branch name', required: true, list: true),
    FieldSpec('code', 'Code', required: true, list: true),
    FieldSpec(
      'is_active',
      'Active',
      type: FieldType.boolean,
      defaultValue: 'true',
      list: true,
    ),
  ],
);

const _numberingSpec = TableSpec(
  table: 'document_sequences',
  title: 'Document numbering',
  singular: 'Sequence',
  orderBy: 'document_type',
  searchColumns: ['document_type', 'prefix'],
  fields: [
    FieldSpec('document_type', 'Document type', required: true, list: true),
    FieldSpec('prefix', 'Prefix', required: true, list: true),
    FieldSpec(
      'next_number',
      'Next number',
      type: FieldType.integer,
      defaultValue: '1',
      list: true,
      min: 1,
    ),
  ],
);
