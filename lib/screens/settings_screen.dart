import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../brand/brand.dart';
import '../core/logging/app_logger.dart';
import '../data/save_flow.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand_ui.dart';
import '../widgets/common.dart';
import '../l10n/ui_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _runningAlerts = false;

  Future<void> _runAlerts() async {
    final strings = AppLocalizations.of(context);
    setState(() => _runningAlerts = true);
    try {
      await SaveFlow.write(
        module: strings.settings,
        target: 'fn_generate_alerts',
        action: () => SessionScope.of(context).client.rpc('fn_generate_alerts'),
      );
      if (!mounted) return;
      showSnack(context, strings.alertsGenerated);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _runningAlerts = false);
    }
  }

  Future<void> _setLanguage(String? value) async {
    if (value == null) return;
    try {
      await SessionScope.of(context).setLocale(value);
    } catch (error) {
      if (mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final strings = AppLocalizations.of(context);
    final isAdmin = session.selectedBranch?.isAdmin ?? false;
    final canBusiness =
        session.can('settings.manage') || session.can('branches.manage');
    final canMasterData = [
      'units.manage',
      'categories.manage',
      'expenses.manage',
      'hr.manage',
      'payroll.manage',
    ].any(session.can);
    final branch = session.selectedBranch;
    return AppScaffold(
      title: Text(strings.settings),
      kpiStrip: KpiStrip(
        items: [
          KpiItem(
            label: uiText(context, 'Branch'),
            value: branch?.branchName ?? '—',
          ),
          KpiItem(
            label: uiText(context, 'Role'),
            value: branch?.roleLabel ?? '—',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _section(context, 'Account'),
          _tile(
            context,
            icon: Icons.person_outline,
            title: strings.profile,
            subtitle: session.userEmail ?? '',
            route: '/settings/profile',
          ),
          _tile(
            context,
            icon: Icons.lock_outline,
            title: strings.security,
            subtitle: strings.changePassword,
            route: '/settings/security',
          ),
          _tile(
            context,
            icon: Icons.notifications_outlined,
            title: strings.notificationCenter,
            route: '/notifications',
          ),
          _tile(
            context,
            icon: Icons.tune_outlined,
            title: strings.notificationPreferences,
            route: '/notifications?tab=preferences',
          ),
          _section(context, strings.languageAppearance),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(strings.language),
            subtitle: Text(switch (session.locale?.languageCode) {
              'am' => 'አማርኛ',
              'om' => 'Afaan Oromoo',
              _ => 'English',
            }),
            trailing: DropdownButton<String>(
              value: session.locale?.languageCode ?? 'en',
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                DropdownMenuItem(value: 'om', child: LText('Afaan Oromoo')),
              ],
              onChanged: _setLanguage,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(strings.theme),
            trailing: DropdownButton<ThemeMode>(
              value: session.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) session.setThemeMode(value);
              },
            ),
          ),
          if (canBusiness) ...[
            _section(context, 'Business administration'),
            if (session.can('settings.manage'))
              _tile(
                context,
                icon: Icons.storefront_outlined,
                title: strings.businessSettings,
                subtitle: uiText(
                  context,
                  'Name, slogan, currency, tax and default language',
                ),
                route: '/settings/business',
              ),
            if (session.can('branches.manage'))
              _tile(
                context,
                icon: Icons.account_tree_outlined,
                title: uiText(context, 'Branches'),
                route: '/settings/branches',
              ),
            _tile(
              context,
              icon: Icons.savings_outlined,
              title: uiText(context, 'Stores & cash accounts'),
              route: '/settings/accounts',
            ),
            if (isAdmin && session.can('users.manage'))
              _tile(
                context,
                icon: Icons.manage_accounts_outlined,
                title: uiText(context, 'Users & roles'),
                subtitle: uiText(
                  context,
                  'Assign branch, role and active status',
                ),
                route: '/settings/users',
              ),
            if (isAdmin)
              _tile(
                context,
                icon: Icons.admin_panel_settings_outlined,
                title: strings.rolePermissions,
                route: '/settings/role-permissions',
              ),
            if (canMasterData)
              _tile(
                context,
                icon: Icons.dataset_outlined,
                title: strings.masterData,
                subtitle: uiText(
                  context,
                  'Units, categories, departments, shifts and tax',
                ),
                route: '/settings/master-data',
              ),
            if (session.can('audit.view'))
              _tile(
                context,
                icon: Icons.history,
                title: strings.auditLog,
                subtitle: uiText(
                  context,
                  'Filter by table, user, action and date',
                ),
                route: '/settings/audit',
              ),
            if (session.can('reports.view'))
              _tile(
                context,
                icon: Icons.download_outlined,
                title: strings.dataExport,
                subtitle: uiText(
                  context,
                  'PDF with logo, CSV with every visible column',
                ),
                route: '/settings/export',
              ),
            if (session.can('settings.manage')) ...[
              _tile(
                context,
                icon: Icons.storage_outlined,
                title: uiText(context, 'Storage'),
                route: '/settings/storage',
              ),
              _tile(
                context,
                icon: Icons.workspace_premium_outlined,
                title: uiText(context, 'Branding'),
                route: '/settings/branding',
              ),
              ListTile(
                leading: const Icon(Icons.notification_add_outlined),
                title: Text(strings.runAlerts),
                subtitle: const LText(
                  'Creates stock, credit and rent alerts now.',
                ),
                trailing: _runningAlerts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline),
                enabled: !_runningAlerts,
                onTap: _runAlerts,
              ),
            ],
          ],
          _section(context, 'Support'),
          _tile(
            context,
            icon: Icons.info_outline,
            title: strings.about,
            subtitle: '${Brand.appName} • ${Brand.slogan}',
            route: '/settings/about',
          ),
          _tile(
            context,
            icon: Icons.help_outline,
            title: strings.helpContact,
            route: '/settings/help',
          ),
          _tile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: strings.privacyPolicy,
            route: '/settings/privacy',
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label) =>
      SectionBar(title: label);

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}

class BrandingScreen extends StatelessWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: Text(AppLocalizations.of(context).about),
    body: const _BrandingTab(),
  );
}

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppScaffold(title: LText('Storage'), body: _StorageTab());
}

class _BrandingTab extends StatelessWidget {
  const _BrandingTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SectionCard(
        title: uiText(context, 'Official brand'),
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
      SectionCard(
        title: uiText(context, 'Brand assets'),
        child: const Column(
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
    ('avatars', 'Public profile photos'),
    ('branding', 'Public logo and brand assets'),
    ('receipts', 'Private sales receipt PDFs'),
    ('employee-documents', 'Private employee documents'),
    ('contracts', 'Private lease and supplier contracts'),
  ];

  Future<List<Map<String, dynamic>>> _list(String bucket) async {
    try {
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
    } catch (error, stack) {
      AppLogger.error('Could not list storage bucket', error, stack);
      rethrow;
    }
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
                      child: FriendlyErrorBox(error: snapshot.error!),
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
