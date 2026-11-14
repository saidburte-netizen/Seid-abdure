import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../brand/brand.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final tabs = <(String, Widget)>[
      ('Account', const _AccountTab()),
      if (session.can('settings.manage'))
        (
          'App settings',
          CrudTab(
            spec: specFor('app_settings'),
            readPermission: 'settings.manage',
            writePermission: 'settings.manage',
          ),
        ),
      if (session.can('branches.manage'))
        (
          'Branches',
          CrudTab(
            spec: specFor('branches'),
            readPermission: 'branches.manage',
            writePermission: 'branches.manage',
          ),
        ),
      if (session.can('users.manage'))
        (
          'Users',
          CrudTab(
            spec: specFor('profiles'),
            readPermission: 'users.manage',
            writePermission: 'users.manage',
          ),
        ),
      if (session.can('settings.manage')) ...[
        (
          'Roles',
          CrudTab(
            spec: specFor('roles'),
            readPermission: 'settings.manage',
            alwaysReadOnly: true,
          ),
        ),
        (
          'Permissions',
          CrudTab(
            spec: specFor('permissions'),
            readPermission: 'settings.manage',
            alwaysReadOnly: true,
          ),
        ),
        (
          'Role permissions',
          CrudTab(
            spec: specFor('role_permissions'),
            readPermission: 'settings.manage',
            alwaysReadOnly: true,
          ),
        ),
      ],
      if (session.can('audit.view'))
        (
          'Audit log',
          CrudTab(
            spec: specFor('audit_logs'),
            readPermission: 'audit.view',
            alwaysReadOnly: true,
          ),
        ),
      if (session.can('settings.manage')) ('Storage', const _StorageTab()),
      if (session.can('settings.manage')) ('Branding', const _BrandingTab()),
    ];
    return ModuleScaffold(
      title: 'Settings & administration',
      body: DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in tabs) Tab(text: tab.$1)],
            ),
            Expanded(
              child: TabBarView(children: [for (final tab in tabs) tab.$2]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTab extends StatefulWidget {
  const _AccountTab();

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  final _name = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final session = SessionScope.of(context);
      _name.text = session.fullName ?? '';
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = SessionScope.of(context);
    setState(() => _saving = true);
    try {
      await session.updateProfileName(_name.text);
      if (mounted) showSnack(context, 'Profile updated.');
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'My profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              Text('Email: ${session.userEmail ?? '—'}'),
              Text('Role: ${branch?.roleLabel ?? '—'}'),
              Text('Branch: ${branch?.branchName ?? '—'}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Language & appearance',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: session.locale?.languageCode ?? 'en',
                decoration: const InputDecoration(labelText: 'Language'),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                  DropdownMenuItem(value: 'om', child: Text('Afaan Oromoo')),
                ],
                onChanged: (value) => session.setLocale(value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThemeMode>(
                initialValue: session.themeMode,
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) session.setThemeMode(value);
                },
              ),
            ],
          ),
        ),
        SectionCard(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: session.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandingTab extends StatelessWidget {
  const _BrandingTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SectionCard(
        title: 'Official brand',
        child: Column(
          children: [
            Image.asset(Brand.logoAsset, width: 180, height: 180),
            const SizedBox(height: 12),
            Text(
              Brand.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              Brand.slogan,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      const SectionCard(
        title: 'Brand assets',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logo: assets/branding/logo.png'),
            Text(
              'Adaptive icon foreground: assets/branding/icon_foreground.png',
            ),
            Text('Notification icon: assets/branding/notification_icon.png'),
            SizedBox(height: 8),
            Text(
              'The uploaded logo is used exactly as supplied for the app icon, '
              'splash screen, receipt, invoice, payslip, and report headers.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _StorageTab extends StatefulWidget {
  const _StorageTab();

  @override
  State<_StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<_StorageTab> {
  static const _buckets = [
    ('product-images', 'Public product photos'),
    ('branding', 'Public logo and brand assets'),
    ('receipts', 'Private sales receipt PDFs'),
    ('employee-documents', 'Private employee documents'),
    ('contracts', 'Private lease and supplier contracts'),
  ];

  Future<List<Map<String, dynamic>>> _list(String bucket) async {
    final session = SessionScope.of(context);
    final files = await session.client.storage.from(bucket).list();
    return files
        .map(
          (file) => {
            'name': file.name,
            'created_at': file.createdAt,
            'bucket': bucket,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Supabase Storage buckets used by the application. Public buckets can '
        'be read directly; private buckets require authenticated access and '
        'storage policies.',
      ),
      const SizedBox(height: 12),
      for (final bucket in _buckets)
        Card(
          child: ExpansionTile(
            title: Text(bucket.$1),
            subtitle: Text(bucket.$2),
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _list(bucket.$1),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Cannot list this bucket with the current role. '
                        'Uploads are still available through the database URL '
                        'fields.\n${snapshot.error}',
                      ),
                    );
                  }
                  final files = snapshot.data ?? const [];
                  if (files.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No files in this bucket.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final file in files.take(20))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(file['name'] as String),
                          subtitle: Text(file['bucket'] as String),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
    ],
  );
}
