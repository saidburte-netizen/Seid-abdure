import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/export.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import 'common.dart';

class CrudRowAction {
  const CrudRowAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool danger;
  final Future<void> Function(Map<String, dynamic> row) onPressed;
}

class LookupOption {
  const LookupOption(this.id, this.label);

  final String id;
  final String label;
}

class _CrudSnapshot {
  const _CrudSnapshot(this.rows, this.lookups);

  final List<Map<String, dynamic>> rows;
  final Map<String, List<LookupOption>> lookups;
}

/// A reusable, permission-aware table with generated create/edit forms.
///
/// The widget intentionally handles master data only. Financial and stock
/// mutations are exposed through [actions], which call SECURITY DEFINER RPCs.
class CrudTab extends StatefulWidget {
  const CrudTab({
    required this.spec,
    this.writePermission,
    this.readPermission,
    this.actions,
    this.filters = const {},
    this.header,
    this.footer,
    this.emptyMessage,
    this.onChanged,
    this.alwaysReadOnly = false,
    super.key,
  });

  final TableSpec spec;
  final String? writePermission;
  final String? readPermission;
  final List<CrudRowAction> Function(Map<String, dynamic> row)? actions;
  final Map<String, Object?> filters;
  final Widget? header;
  final Widget? footer;
  final String? emptyMessage;
  final VoidCallback? onChanged;
  final bool alwaysReadOnly;

  @override
  State<CrudTab> createState() => _CrudTabState();
}

class _CrudTabState extends State<CrudTab> {
  final _search = TextEditingController();
  late Future<_CrudSnapshot> _future;
  bool _started = false;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _future = _load();
    }
  }

  @override
  void didUpdateWidget(covariant CrudTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.table != widget.spec.table ||
        oldWidget.filters != widget.filters) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  BranchRepository get _repo {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    return BranchRepository(session.client, branch?.branchId ?? '');
  }

  bool get _canRead {
    final session = SessionScope.of(context);
    return widget.readPermission == null || session.can(widget.readPermission!);
  }

  bool get _canWrite {
    if (widget.alwaysReadOnly) return false;
    final session = SessionScope.of(context);
    return widget.writePermission == null || session.can(widget.writePermission!);
  }

  Future<_CrudSnapshot> _load() async {
    final repo = _repo;
    final rows = await repo.list(
      widget.spec.table,
      orderBy: widget.spec.orderBy,
      ascending: widget.spec.ascending,
      branchScoped: widget.spec.branchScoped,
      equals: widget.filters,
      limit: widget.spec.limit,
    );
    final lookups = <String, List<LookupOption>>{};
    for (final field in widget.spec.fields) {
      if (field.type != FieldType.lookup || field.lookupTable == null) continue;
      final options = await repo.lookup(
        field.lookupTable!,
        labelColumn: field.lookupLabel,
        branchScoped: field.lookupBranchScoped,
        equals: field.lookupEquals,
      );
      lookups[field.key] = [
        for (final option in options)
          LookupOption(
            option['id'] as String,
            option[field.lookupLabel]?.toString() ??
                option['id']?.toString() ??
                '—',
          ),
      ];
    }
    return _CrudSnapshot(rows, lookups);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    if (_query.trim().isEmpty) return rows;
    final needle = _query.toLowerCase();
    final columns = widget.spec.searchColumns.isEmpty
        ? widget.spec.fields.map((field) => field.key).toList()
        : widget.spec.searchColumns;
    return rows.where((row) {
      for (final column in columns) {
        if (row[column]?.toString().toLowerCase().contains(needle) ?? false) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return const EmptyView(
        icon: Icons.lock_outline,
        message: 'You do not have permission to view this list.',
      );
    }
    return AsyncView<_CrudSnapshot>(
      future: _future,
      onRetry: _refresh,
      builder: (context, snapshot) {
        final rows = _filtered(snapshot.rows);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) widget.header!,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Search ${widget.spec.title.toLowerCase()}',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: rows.isEmpty
                        ? null
                        : () => _export(context, snapshot, rows),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('CSV'),
                  ),
                  if (_canWrite && widget.spec.canCreate)
                    FilledButton.icon(
                      onPressed: () => _openForm(context, snapshot, null),
                      icon: const Icon(Icons.add),
                      label: Text('New ${widget.spec.singular.toLowerCase()}'),
                    ),
                ],
              ),
            ),
            if (widget.spec.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Text(
                  widget.spec.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyView(
                      icon: Icons.table_rows_outlined,
                      message: widget.emptyMessage ??
                          'No ${widget.spec.title.toLowerCase()} found.',
                      action: _canWrite && widget.spec.canCreate
                          ? FilledButton(
                              onPressed: () =>
                                  _openForm(context, snapshot, null),
                              child: Text(
                                  'Create ${widget.spec.singular.toLowerCase()}'),
                            )
                          : null,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 760) {
                          return _buildCards(context, snapshot, rows);
                        }
                        return _buildTable(context, snapshot, rows);
                      },
                    ),
            ),
            if (widget.footer != null) widget.footer!,
          ],
        );
      },
    );
  }

  Widget _buildTable(
    BuildContext context,
    _CrudSnapshot snapshot,
    List<Map<String, dynamic>> rows,
  ) {
    final columns = widget.spec.effectiveListColumns;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: [
            for (final key in columns)
              DataColumn(
                label: Text(
                  widget.spec.field(key)?.label ?? prettyLabel(key),
                ),
              ),
            const DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  for (final key in columns)
                    DataCell(_valueWidget(
                      context,
                      widget.spec.field(key),
                      row[key],
                      snapshot.lookups,
                    )),
                  DataCell(_actionsWidget(context, snapshot, row)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCards(
    BuildContext context,
    _CrudSnapshot snapshot,
    List<Map<String, dynamic>> rows,
  ) =>
      ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final row = rows[index];
          final titleKey = widget.spec.effectiveListColumns.isEmpty
              ? widget.spec.fields.first.key
              : widget.spec.effectiveListColumns.first;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _display(widget.spec.field(titleKey), row[titleKey],
                              snapshot.lookups),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _actionsWidget(context, snapshot, row),
                    ],
                  ),
                  for (final key
                      in widget.spec.effectiveListColumns.skip(1).take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              widget.spec.field(key)?.label ??
                                  prettyLabel(key),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: _valueWidget(
                              context,
                              widget.spec.field(key),
                              row[key],
                              snapshot.lookups,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget _valueWidget(
    BuildContext context,
    FieldSpec? field,
    Object? value,
    Map<String, List<LookupOption>> lookups,
  ) {
    final text = _display(field, value, lookups);
    if (field?.type == FieldType.boolean || field?.type == FieldType.select) {
      final color = field?.type == FieldType.boolean && value == true
          ? Theme.of(context).colorScheme.primary
          : null;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }

  String _display(
    FieldSpec? field,
    Object? value,
    Map<String, List<LookupOption>> lookups,
  ) {
    if (value == null || value.toString().isEmpty) return '—';
    if (field == null) return asText(value);
    if (field.type == FieldType.lookup) {
      final options = lookups[field.key] ?? const [];
      for (final option in options) {
        if (option.id == value) return option.label;
      }
      return asText(value);
    }
    if (field.type == FieldType.select) {
      return field.options[value.toString()] ?? prettyLabel(value.toString());
    }
    if (field.type == FieldType.boolean) {
      return value == true ? 'Yes' : 'No';
    }
    if (field.type == FieldType.number || field.type == FieldType.integer) {
      return formatQuantity(value);
    }
    if (field.type == FieldType.date) return formatDate(value);
    if (field.type == FieldType.time) return formatTime(value);
    return asText(value);
  }

  Widget _actionsWidget(
    BuildContext context,
    _CrudSnapshot snapshot,
    Map<String, dynamic> row,
  ) {
    final custom = widget.actions?.call(row) ?? const <CrudRowAction>[];
    final session = SessionScope.of(context);
    final canEdit = _canWrite && widget.spec.canEdit;
    final canDelete = _canWrite && widget.spec.canDelete;
    final canExport = session.can('reports.export');
    if (custom.isEmpty && !canEdit && !canDelete && !canExport) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Row actions',
      onSelected: (value) async {
        if (value == 'edit') {
          await _openForm(context, snapshot, row);
        } else if (value == 'delete') {
          await _delete(context, row);
        } else if (value == 'copy') {
          await copyText(
            context,
            row.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n'),
            'Row',
          );
        } else {
          for (final action in custom) {
            if (action.label == value) {
              try {
                await action.onPressed(row);
                if (context.mounted) {
                  await _refresh();
                  widget.onChanged?.call();
                }
              } catch (error) {
                if (context.mounted) {
                  showSnack(context, readableError(error), error: true);
                }
              }
            }
          }
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
        if (canExport)
          const PopupMenuItem(
            value: 'copy',
            child: ListTile(
              leading: Icon(Icons.copy_outlined),
              title: Text('Copy row'),
            ),
          ),
        for (final action in custom)
          PopupMenuItem(
            value: action.label,
            child: ListTile(
              leading: Icon(
                action.icon,
                color: action.danger
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(
                action.label,
                style: action.danger
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final id = row[widget.spec.primaryKey];
    if (id == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${widget.spec.singular.toLowerCase()}?',
      message:
          'This permanently removes the record. Records referenced by transactions cannot be deleted.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await _repo.delete(widget.spec.table, id,
          primaryKey: widget.spec.primaryKey);
      if (context.mounted) {
        showSnack(context, '${widget.spec.singular} deleted.');
        await _refresh();
        widget.onChanged?.call();
      }
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _openForm(
    BuildContext context,
    _CrudSnapshot snapshot,
    Map<String, dynamic>? row,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CrudFormDialog(
        spec: widget.spec,
        row: row,
        lookups: snapshot.lookups,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      if (row == null) {
        await _repo.insert(
          widget.spec.table,
          result,
          branchScoped: widget.spec.branchScoped,
        );
      } else {
        await _repo.update(
          widget.spec.table,
          row[widget.spec.primaryKey],
          result,
          primaryKey: widget.spec.primaryKey,
        );
      }
      if (context.mounted) {
        showSnack(context, '${widget.spec.singular} saved.');
        await _refresh();
        widget.onChanged?.call();
      }
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _export(
    BuildContext context,
    _CrudSnapshot snapshot,
    List<Map<String, dynamic>> rows,
  ) async {
    final csv = rowsToCsv(rows);
    final path = await saveCsvFile(widget.spec.table, csv);
    if (!context.mounted) return;
    final session = SessionScope.of(context);
    if (path == null || !session.can('reports.export')) {
      await copyText(context, csv, 'CSV');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.spec.title} exported'),
        content: SelectableText('Saved to:\n$path\n\n${rows.length} rows.'),
        actions: [
          TextButton(
            onPressed: () => copyText(context, csv, 'CSV'),
            child: const Text('Copy CSV'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _CrudFormDialog extends StatefulWidget {
  const _CrudFormDialog({
    required this.spec,
    required this.row,
    required this.lookups,
  });

  final TableSpec spec;
  final Map<String, dynamic>? row;
  final Map<String, List<LookupOption>> lookups;

  @override
  State<_CrudFormDialog> createState() => _CrudFormDialogState();
}

class _CrudFormDialogState extends State<_CrudFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.spec.fields) {
      final raw = widget.row?[field.key] ?? field.defaultValue;
      if (field.type == FieldType.boolean) {
        _values[field.key] = raw == null ? false : asBool(raw);
      } else if (field.type == FieldType.date) {
        _values[field.key] = raw == null ? null : asDateTime(raw);
        _controllers[field.key] = TextEditingController(
          text: _values[field.key] == null
              ? ''
              : dateOnly(_values[field.key] as DateTime),
        );
      } else if (field.type == FieldType.time) {
        final text = raw?.toString() ?? '';
        _controllers[field.key] =
            TextEditingController(text: text.length > 5 ? text.substring(0, 5) : text);
      } else {
        _controllers[field.key] = TextEditingController(
          text: raw == null ? '' : raw.toString(),
        );
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(
        widget.row == null
            ? 'New ${widget.spec.singular.toLowerCase()}'
            : 'Edit ${widget.spec.singular.toLowerCase()}',
      ),
      content: SizedBox(
        width: media.width > 720 ? 640 : media.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final field in widget.spec.fields)
                  SizedBox(
                    width: field.width ??
                        ((media.width > 720 ? 640 : media.width * 0.9) / 2) - 8,
                    child: _buildField(context, field),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, FieldSpec field) {
    switch (field.type) {
      case FieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: _values[field.key] == true,
          onChanged: (value) => setState(() => _values[field.key] = value),
        );
      case FieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _controllers[field.key]?.text.isEmpty ?? true
              ? null
              : _controllers[field.key]!.text,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
          items: [
            for (final entry in field.options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          validator: (value) =>
              field.required && value == null ? 'Required' : null,
          onChanged: (value) {
            _controllers[field.key]?.text = value ?? '';
            _values[field.key] = value;
          },
        );
      case FieldType.lookup:
        final options = widget.lookups[field.key] ?? const <LookupOption>[];
        final current = _controllers[field.key]?.text;
        final valid = options.any((option) => option.id == current);
        return DropdownButtonFormField<String>(
          initialValue: valid ? current : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          validator: (value) {
            if (!field.required) return null;
            return value == null || value.isEmpty ? 'Required' : null;
          },
          onChanged: (value) {
            _controllers[field.key]?.text = value ?? '';
            _values[field.key] = value;
          },
        );
      case FieldType.date:
        return TextFormField(
          controller: _controllers[field.key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: 'YYYY-MM-DD',
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          validator: (value) => field.required &&
                  (value == null || value.isEmpty)
              ? 'Required'
              : null,
          onTap: () async {
            final now = DateTime.now();
            final selected = await showDatePicker(
              context: context,
              initialDate: _values[field.key] as DateTime? ?? now,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
            );
            if (selected != null) {
              setState(() {
                _values[field.key] = selected;
                _controllers[field.key]!.text = dateOnly(selected);
              });
            }
          },
        );
      case FieldType.number:
      case FieldType.integer:
        return TextFormField(
          controller: _controllers[field.key],
          keyboardType: TextInputType.numberWithOptions(
            decimal: field.type == FieldType.number,
          ),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
          validator: (value) {
            if (field.required && (value == null || value.trim().isEmpty)) {
              return 'Required';
            }
            if (value == null || value.trim().isEmpty) return null;
            final number = num.tryParse(value.trim());
            if (number == null) return 'Enter a number';
            if (field.min != null && number < field.min!) {
              return 'Must be at least ${field.min}';
            }
            if (field.max != null && number > field.max!) {
              return 'Must be at most ${field.max}';
            }
            return null;
          },
        );
      case FieldType.multiline:
        return TextFormField(
          controller: _controllers[field.key],
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
          validator: (value) => field.required &&
                  (value == null || value.trim().isEmpty)
              ? 'Required'
              : null,
        );
      case FieldType.text:
      case FieldType.time:
        return TextFormField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint ?? (field.type == FieldType.time ? 'HH:MM' : null),
          ),
          validator: (value) => field.required &&
                  (value == null || value.trim().isEmpty)
              ? 'Required'
              : null,
        );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{};
    for (final field in widget.spec.fields) {
      if (field.type == FieldType.boolean) {
        payload[field.key] = _values[field.key] == true;
        continue;
      }
      final text = _controllers[field.key]?.text.trim() ?? '';
      switch (field.type) {
        case FieldType.number:
          payload[field.key] = text.isEmpty ? null : num.tryParse(text);
        case FieldType.integer:
          payload[field.key] = text.isEmpty ? null : int.tryParse(text);
        case FieldType.lookup:
          payload[field.key] = text.isEmpty ? null : text;
        case FieldType.date:
        case FieldType.time:
        case FieldType.text:
        case FieldType.multiline:
          payload[field.key] = text.isEmpty && field.required ? null : text;
        case FieldType.select:
          payload[field.key] = text.isEmpty ? null : text;
        case FieldType.boolean:
          break;
      }
    }
    if (mounted) Navigator.of(context).pop(payload);
  }
}
