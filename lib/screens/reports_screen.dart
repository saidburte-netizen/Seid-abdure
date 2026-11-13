import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../data/export.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/module_scaffold.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _report = 'sales';
  late DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  static const _reports = {
    'dashboard': 'Executive dashboard',
    'sales': 'Sales report',
    'inventory': 'Inventory valuation',
    'production': 'Production report',
    'profit_and_loss': 'Profit & loss',
    'receivables': 'Receivables',
    'payables': 'Payables',
    'rentals': 'Rentals',
    'payroll': 'Payroll report',
    'export': 'Full branch export',
  };

  bool get _usesDates => const {
        'sales',
        'production',
        'profit_and_loss',
      }.contains(_report);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null && _error == null && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, Object?> params = {'target_branch': branch.branchId};
      if (_usesDates) {
        params['from_date'] = dateOnly(_range.start);
        params['to_date'] = dateOnly(_range.end);
      }
      Object? response;
      if (_report == 'payroll') {
        final repo = BranchRepository(session.client, branch.branchId);
        final runs = await repo.list(
          'payroll_runs',
          orderBy: 'period_start',
          ascending: false,
          limit: 1,
        );
        if (runs.isEmpty) {
          throw Exception('No payroll run exists yet.');
        }
        response = await session.client.rpc('report_payroll', params: {
          'target_run': runs.first['id'],
        });
      } else if (_report == 'export') {
        response = await session.client.rpc('export_branch_data', params: params);
      } else {
        response = await session.client.rpc('report_$_report', params: params);
      }
      if (!mounted) return;
      setState(() => _data = asMap(response));
    } catch (error) {
      if (mounted) {
        setState(() => _error = readableError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _range,
    );
    if (range == null) return;
    setState(() => _range = range);
    await _load();
  }

  Future<void> _exportCsv() async {
    final data = _data;
    if (data == null) return;
    final rows = flattenReport(data);
    final csv = rowsToCsv(rows);
    final path = await saveCsvFile('brade_and_cake_$_report', csv);
    if (!mounted) return;
    if (path == null) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) showSnack(context, 'CSV copied to the clipboard.');
      return;
    }
    await showInfoDialog(
      context,
      title: 'Report exported',
      content: 'CSV written to:\n$path',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ModuleScaffold(
      title: 'Reports & analytics',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: _report,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Report'),
                      items: [
                        for (final entry in _reports.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _report = value);
                        _load();
                      },
                    ),
                  ),
                  if (_usesDates)
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        '${formatDate(_range.start)} – ${formatDate(_range.end)}',
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Run report'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _data == null ? null : _exportCsv,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SectionCard(
              title: 'Report error',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (_data != null) ...[
            PageHeader(
              title: _reports[_report] ?? 'Report',
              subtitle: _usesDates
                  ? '${formatDate(_range.start)} to ${formatDate(_range.end)}'
                  : 'Current position',
            ),
            SectionCard(
              title: _reports[_report] ?? 'Report',
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              child: JsonView(value: _data!),
            ),
          ],
        ],
      ),
    );
  }
}
