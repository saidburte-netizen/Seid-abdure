import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/auth_controller.dart';
import '../../brand/brand.dart';
import '../../core/build_info.dart';
import '../../core/logging/save_diagnostics.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/common.dart';
import '../../l10n/ui_text.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final isAdmin = SessionScope.maybeOf(context)?.isAdmin == true;
    return AppScaffold(
      title: Text(strings.about),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Image.asset(
              Brand.logoAsset,
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 28),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = BuildInfo.version.isNotEmpty
                  ? BuildInfo.version
                  : (info?.version ?? uiText(context, 'Unknown'));
              final buildNumber = BuildInfo.buildNumber.isNotEmpty
                  ? BuildInfo.buildNumber
                  : (info?.buildNumber ?? uiText(context, 'Unknown'));
              return SectionCard(
                title: strings.about,
                child: Column(
                  children: [
                    _AboutRow(label: strings.appTitle, value: Brand.appName),
                    _AboutRow(label: strings.slogan, value: Brand.slogan),
                    _AboutRow(label: strings.versionLabel, value: version),
                    _AboutRow(
                      label: uiText(context, 'Build number'),
                      value: buildNumber,
                    ),
                    _AboutRow(
                      label: uiText(context, 'Commit'),
                      value: BuildInfo.shortSha,
                    ),
                    _AboutRow(
                      label: uiText(context, 'Branch'),
                      value: BuildInfo.branch,
                    ),
                    _AboutRow(
                      label: strings.language,
                      value: 'English • አማርኛ • Afaan Oromoo',
                    ),
                  ],
                ),
              );
            },
          ),
          const SectionCard(
            child: Text(
              'Brade and Cake House is a complete bakery, shop and property '
              'management system. Sales, stock, cash, payroll, rentals, credit '
              'and reporting are updated through the live business database.',
            ),
          ),
          if (isAdmin) const _SaveDiagnosticsPanel(),
        ],
      ),
    );
  }
}

class _SaveDiagnosticsPanel extends StatefulWidget {
  const _SaveDiagnosticsPanel();

  @override
  State<_SaveDiagnosticsPanel> createState() => _SaveDiagnosticsPanelState();
}

class _SaveDiagnosticsPanelState extends State<_SaveDiagnosticsPanel> {
  @override
  void initState() {
    super.initState();
    unawaited(SaveDiagnostics.instance.load());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: SaveDiagnostics.instance,
    builder: (context, _) {
      final entries = SaveDiagnostics.instance.entries.take(80);
      return SectionCard(
        title: 'Save diagnostics',
        child: entries.isEmpty
            ? const Text('No save attempts recorded.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        '${entry.time.toLocal().toIso8601String()} | '
                        '${entry.module} | ${entry.target} | ${entry.step}',
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.helpContact),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: uiText(context, 'Getting help'),
            child: const Text(
              'For account access, role changes, or a correction to a business '
              'record, contact your branch administrator or the business owner. '
              'Administrators can manage users in Settings → Users.',
            ),
          ),
          SectionCard(
            title: uiText(context, 'Before you report a problem'),
            child: const Text(
              'Check that the device has internet access, then pull down to '
              'refresh the screen. The app never shows technical error text; '
              'the message on screen is safe to share with your administrator.',
            ),
          ),
          SectionCard(
            title: uiText(context, 'Support information to include'),
            child: const Text(
              'Tell your administrator what you were doing, the screen name, '
              'the exact friendly message shown, and the time it happened.',
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppScaffold(
      title: Text(strings.privacyPolicy),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: uiText(context, 'What we store'),
            child: const Text(
              'The app stores the business records you enter: sales, stock, '
              'cash, staff, payroll, rentals, credit, customers, suppliers and '
              'settings. Account email, name, phone, avatar, role and language '
              'are stored in your organization\'s Supabase project.',
            ),
          ),
          SectionCard(
            title: uiText(context, 'Who can see it'),
            child: const Text(
              'Access follows the role and branch permissions configured by '
              'your administrator. Sensitive operations are restricted to the '
              'roles that need them.',
            ),
          ),
          SectionCard(
            title: uiText(context, 'Device storage'),
            child: const Text(
              'The device stores your selected language, theme and branch, and '
              'your sign-in session in the platform secure store. Business '
              'records remain in the organization database; the app keeps no '
              'offline copy of them.',
            ),
          ),
          SectionCard(
            title: uiText(context, 'Your choices'),
            child: const Text(
              'You can change your profile, password, language and notification '
              'preferences in Settings. Ask an administrator to deactivate an '
              'account that should no longer have access.',
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
