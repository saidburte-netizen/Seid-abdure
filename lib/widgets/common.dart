import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'brand_ui.dart';

export '../core/errors/error_ui.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: BrandColors.deepGreen,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      border: Border.fromBorderSide(
        BorderSide(color: BrandColors.gold, width: 1),
      ),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BrandColors.ivory,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrandColors.cream.withValues(alpha: 0.88),
                  ),
                ),
              ),
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: padding,
    title: title,
    trailing: trailing,
    child: child,
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      KpiCard(label: label, value: value, icon: icon, onTap: onTap);
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    this.message = 'Nothing here yet.',
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 42,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onErrorContainer,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.future,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LoadingView();
      }
      if (snapshot.hasError) {
        return ErrorView(
          message: readableError(context, snapshot.error!),
          onRetry: onRetry,
        );
      }
      if (!snapshot.hasData) return const EmptyView();
      return builder(context, snapshot.data as T);
    },
  );
}

Future<bool> confirmDiscardChanges(BuildContext context) async {
  final strings = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.discardChangesTitle),
      content: Text(strings.discardChangesMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(strings.keepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(strings.discard),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: error
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              )
            : Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
      ),
    );
}

Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required Object? content,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: content is String
            ? SelectableText(content)
            : JsonView(value: content),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

class JsonView extends StatelessWidget {
  const JsonView({required this.value, super.key});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value is Map || value is List) {
      final rows = flattenReport(value);
      if (rows.isEmpty) return const Text('No data.');
      return ReportTable(rows: rows);
    }
    return SelectableText(asText(value, fallback: '—'));
  }
}

/// A compact, horizontally scrollable table used for reports and JSON details.
class ReportTable extends StatelessWidget {
  const ReportTable({required this.rows, this.columns, super.key});

  final List<Map<String, dynamic>> rows;
  final List<String>? columns;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyView(message: 'No rows returned.');
    final keys =
        columns ?? (rows.expand((row) => row.keys).toSet().toList()..sort());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 22,
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 60,
        columns: [
          for (final key in keys) DataColumn(label: Text(prettyLabel(key))),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final key in keys) DataCell(_ReportCell(value: row[key])),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReportCell extends StatelessWidget {
  const _ReportCell({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value is Map || value is List) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          jsonEncode(value),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final text = value == null ? '—' : asText(value);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {this.style, super.key});

  final Object? value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(formatMoney(value), style: style);
}

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.can(permission)) return child;
    return fallback ??
        const EmptyView(
          icon: Icons.lock_outline,
          message: 'You do not have permission for this area.',
        );
  }
}

Future<void> copyText(BuildContext context, String text, String label) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, '$label copied to clipboard.');
}
