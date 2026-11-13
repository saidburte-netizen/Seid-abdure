import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Payroll',
      body: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Runs'),
                Tab(text: 'Payslips'),
                Tab(text: 'Payslip lines'),
                Tab(text: 'Advances'),
                Tab(text: 'Components'),
                Tab(text: 'Employee components'),
                Tab(text: 'Settings'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: _runsSpec,
                    readPermission: 'payroll.read',
                    alwaysReadOnly: true,
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: session.can('payroll.write')
                              ? () => _runPayroll(session)
                              : null,
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: const Text('Run payroll'),
                        ),
                      ),
                    ),
                    actions: (row) {
                      if (row['status'] != 'draft' ||
                          !session.can('payroll.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve / pay',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) => _approvePayroll(session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: _payslipsSpec,
                    readPermission: 'payroll.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: _payslipLinesSpec,
                    readPermission: 'payroll.read',
                    alwaysReadOnly: true,
                  ),
                  CrudTab(
                    spec: advancesSpec,
                    readPermission: 'payroll.read',
                    writePermission: 'payroll.write',
                  ),
                  CrudTab(
                    spec: salaryComponentsSpec,
                    readPermission: 'payroll.read',
                    writePermission: 'payroll.write',
                  ),
                  CrudTab(
                    spec: employeeComponentsSpec,
                    readPermission: 'payroll.read',
                    writePermission: 'payroll.write',
                  ),
                  const _PayrollSettingsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runPayroll(AuthController session) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      ),
    );
    if (range == null) return;
    final notes = await showInputDialog(
      context,
      title: 'Run payroll',
      submitLabel: 'Run payroll',
      fields: const [
        InputField('notes', 'Notes', type: FieldType.multiline),
      ],
    );
    if (notes == null) return;
    try {
      final response = await session.client.rpc('run_payroll', params: {
        'target_branch': branch.branchId,
        'target_period_start': dateOnly(range.start),
        'target_period_end': dateOnly(range.end),
        'payroll_notes': notes['notes'] ?? '',
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Payroll run generated',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }

  Future<void> _approvePayroll(
    AuthController session,
    Map<String, dynamic> run,
  ) async {
    final branch = session.selectedBranch;
    if (branch == null) return;
    final repo = BranchRepository(session.client, branch.branchId);
    final accounts = await repo.list('cash_accounts', orderBy: 'name');
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovePayrollDialog(
        run: run,
        accounts: accounts,
      ),
    );
    if (choice == null) return;
    try {
      final response = await session.client.rpc('approve_payroll', params: {
        'target_run': run['id'],
        'target_account': choice == 'none' ? null : choice,
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Payroll approved',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _runsSpec = TableSpec(
  table: 'payroll_runs',
  title: 'Payroll runs',
  singular: 'Payroll run',
  orderBy: 'period_start',
  ascending: false,
  searchColumns: ['status', 'notes'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('period_start', 'Period start', type: FieldType.date, list: true),
    FieldSpec('period_end', 'Period end', type: FieldType.date, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, list: true, options: {
      'draft': 'Draft', 'approved': 'Approved', 'paid': 'Paid', 'cancelled': 'Cancelled',
    }),
    FieldSpec('gross_total', 'Gross', type: FieldType.number, list: true),
    FieldSpec('deduction_total', 'Deductions', type: FieldType.number, list: true),
    FieldSpec('net_total', 'Net', type: FieldType.number, list: true),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const _payslipsSpec = TableSpec(
  table: 'payslips',
  title: 'Payslips',
  singular: 'Payslip',
  orderBy: 'generated_at',
  ascending: false,
  searchColumns: ['payslip_number'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('payslip_number', 'Payslip number', list: true),
    FieldSpec('payroll_run_id', 'Run', type: FieldType.lookup, lookupTable: 'payroll_runs', lookupLabel: 'period_start', list: true),
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', list: true),
    FieldSpec('gross_pay', 'Gross', type: FieldType.number, list: true),
    FieldSpec('total_deductions', 'Deductions', type: FieldType.number, list: true),
    FieldSpec('net_pay', 'Net', type: FieldType.number, list: true),
    FieldSpec('days_worked', 'Days worked', type: FieldType.number, list: true),
    FieldSpec('overtime_hours', 'Overtime hours', type: FieldType.number, list: true),
  ],
);

const _payslipLinesSpec = TableSpec(
  table: 'payslip_lines',
  title: 'Payslip lines',
  singular: 'Payslip line',
  orderBy: 'line_type',
  branchScoped: false,
  searchColumns: ['name', 'line_type'],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('payslip_id', 'Payslip', type: FieldType.lookup, lookupTable: 'payslips', lookupLabel: 'payslip_number', list: true),
    FieldSpec('name', 'Component', list: true),
    FieldSpec('line_type', 'Type', type: FieldType.select, list: true, options: {
      'earning': 'Earning', 'deduction': 'Deduction',
    }),
    FieldSpec('amount', 'Amount', type: FieldType.number, list: true),
  ],
);

class _ApprovePayrollDialog extends StatefulWidget {
  const _ApprovePayrollDialog({required this.run, required this.accounts});

  final Map<String, dynamic> run;
  final List<Map<String, dynamic>> accounts;

  @override
  State<_ApprovePayrollDialog> createState() => _ApprovePayrollDialogState();
}

class _ApprovePayrollDialogState extends State<_ApprovePayrollDialog> {
  String _account = 'none';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Approve payroll'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net pay: ${formatMoney(widget.run['net_total'])}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a cash account to mark the run paid, or approve it without payment.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _account,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pay from account'),
                items: [
                  const DropdownMenuItem(
                    value: 'none',
                    child: Text('Approve without payment'),
                  ),
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account['id'] as String,
                      child: Text(asText(account['name'])),
                    ),
                ],
                onChanged: (value) => setState(() => _account = value ?? 'none'),
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
            onPressed: () => Navigator.of(context).pop(_account),
            child: const Text('Approve'),
          ),
        ],
      );
}

class _PayrollSettingsView extends StatefulWidget {
  const _PayrollSettingsView();

  @override
  State<_PayrollSettingsView> createState() => _PayrollSettingsViewState();
}

class _PayrollSettingsViewState extends State<_PayrollSettingsView> {
  final _pensionEmployee = TextEditingController();
  final _pensionEmployer = TextEditingController();
  final _incomeTax = TextEditingController();
  final _overtime = TextEditingController();
  final _monthlyHours = TextEditingController();
  Future<void>? _loading;
  bool _saving = false;
  BranchRepository? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final branch = session.selectedBranch;
    if (branch != null) {
      _repo = BranchRepository(session.client, branch.branchId);
      _loading ??= _load();
    }
  }

  Future<void> _load() async {
    final row = await _repo!.first('payroll_settings');
    if (!mounted) return;
    if (row == null) {
      _pensionEmployee.text = '7';
      _pensionEmployer.text = '11';
      _incomeTax.text = '15';
      _overtime.text = '1.5';
      _monthlyHours.text = '208';
    } else {
      _pensionEmployee.text = (asNum(row['pension_employee_rate']) * 100).toString();
      _pensionEmployer.text = (asNum(row['pension_employer_rate']) * 100).toString();
      _incomeTax.text = (asNum(row['income_tax_rate']) * 100).toString();
      _overtime.text = asNum(row['overtime_multiplier']).toString();
      _monthlyHours.text = asNum(row['standard_monthly_hours']).toString();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pensionEmployee.dispose();
    _pensionEmployer.dispose();
    _incomeTax.dispose();
    _overtime.dispose();
    _monthlyHours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AsyncView<void>(
        future: _loading ?? Future.value(),
        onRetry: () async => setState(() => _loading = _load()),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Payroll settings',
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _number('Pension employee rate (%)', _pensionEmployee),
                      _number('Pension employer rate (%)', _pensionEmployer),
                      _number('Income tax rate (%)', _incomeTax),
                      _number('Overtime multiplier', _overtime),
                      _number('Standard monthly hours', _monthlyHours),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save settings'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _number(String label, TextEditingController controller) => SizedBox(
        width: 240,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final values = {
        'pension_employee_rate': asNum(_pensionEmployee.text) / 100,
        'pension_employer_rate': asNum(_pensionEmployer.text) / 100,
        'income_tax_rate': asNum(_incomeTax.text) / 100,
        'overtime_multiplier': asNum(_overtime.text),
        'standard_monthly_hours': asNum(_monthlyHours.text),
      };
      final existing = await _repo!.first('payroll_settings');
      if (existing == null) {
        await _repo!.insert('payroll_settings', values);
      } else {
        await _repo!.update('payroll_settings', existing['branch_id'], values,
            primaryKey: 'branch_id');
      }
      if (mounted) showSnack(context, 'Payroll settings saved.');
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
