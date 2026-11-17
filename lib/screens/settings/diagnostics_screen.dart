import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../core/logging/error_log.dart';
import '../../core/logging/save_trace.dart';
import '../../l10n/ui_text.dart';
import '../../widgets/common.dart';
import '../../widgets/module_scaffold.dart';

/// Administrator-only technical view of the last save attempts.
///
/// This is the one screen where table names and SQLSTATE values may appear.
/// It is intentionally not linked for non-administrators.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Future<void>? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loading ??= Future.wait([
      SaveTrace.instance.load(),
      ErrorLog.instance.load(),
    ]);
  }

  Future<void> _clear() async {
    await SaveTrace.instance.clear();
    await ErrorLog.instance.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.isAdmin) {
      return ModuleScaffold(
        title: uiText(context, 'Diagnostics'),
        body: EmptyView(message: uiText(context, 'Administrator access only.')),
      );
    }
    return ModuleScaffold(
      title: uiText(context, 'Diagnostics'),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Clear'),
          onPressed: _clear,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final traces = SaveTrace.instance.entries;
          final errors = ErrorLog.instance.entries;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                uiText(context, 'Save breadcrumbs'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (traces.isEmpty)
                Text(uiText(context, 'No save breadcrumbs recorded.'))
              else
                for (final entry in traces)
                  _TraceTile(
                    title: '${entry.module} · ${entry.target}',
                    subtitle:
                        '${entry.step} · ${entry.time.toIso8601String()}'
                        '${entry.detail == null ? '' : '\n${entry.detail}'}',
                  ),
              const SizedBox(height: 24),
              Text(
                uiText(context, 'Technical errors'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (errors.isEmpty)
                Text(uiText(context, 'No technical errors recorded.'))
              else
                for (final entry in errors)
                  _TraceTile(
                    title: '${entry.module} · ${entry.target}',
                    subtitle:
                        '${entry.code.isEmpty ? '—' : entry.code} · '
                        '${entry.time.toIso8601String()}\n${entry.message}',
                    danger: true,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TraceTile extends StatelessWidget {
  const _TraceTile({
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          danger ? Icons.error_outline : Icons.timeline,
          color: danger ? scheme.error : scheme.primary,
        ),
        title: Text(title),
        subtitle: SelectableText(subtitle),
      ),
    );
  }
}
