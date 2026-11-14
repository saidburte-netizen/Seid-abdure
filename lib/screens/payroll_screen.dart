import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/pdf_export.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  Future<void> _generate(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> run,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Generate payslips?',
      message:
          'The database will calculate gross pay, tax, pension, advances and net pay.',
      confirmLabel: 'Generate',
    );
    if (!confirmed) return;
    try {
      await session.client.rpc(
        'fn_generate_payroll',
        params: {'p_run_id': run['id']},
      );
      if (context.mounted) showSnack(context, 'Payslips generated.');
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> run,
    String status,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Mark payroll ${prettyLabel(status)}?',
      message:
          'This updates the payroll run and lets the database apply its totals.',
      confirmLabel: prettyLabel(status),
    );
    if (!confirmed) return;
    try {
      final values = <String, dynamic>{'status': status};
      if (status == 'approved') {
        values['approved_by'] = session.userId;
        values['approved_at'] = nowIso();
      }
      if (status == 'paid') values['paid_at'] = nowIso();
      await session.client
          .from('payroll_runs')
          .update(values)
          .eq('id', run['id']);
      if (context.mounted) {
        showSnack(context, 'Payroll marked ${prettyLabel(status)}.');
      }
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  Future<void> _payslip(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> slip,
  ) async {
    try {
      final employee = await session.client
          .from('employees')
          .select('full_name, employee_no, job_title')
          .eq('id', slip['employee_id'])
          .maybeSingle();
      final branch = session.selectedBranch;
      final bytes = await BrandPdf.document(
        title: 'Payslip',
        documentNumber: asText(slip['id']).substring(0, 8).toUpperCase(),
        branchName: branch?.branchName ?? 'Main branch',
        subtitle: asText(slip['created_at']).split('T').first,
        partyLabel: 'Employee',
        partyName: asText(employee?['full_name']),
        details: [
          ('Employee no', asText(employee?['employee_no'])),
          ('Job title', asText(employee?['job_title'])),
          ('Gross pay', formatMoney(slip['gross_pay'])),
          ('Deductions', formatMoney(slip['total_deductions'])),
          ('Net pay', formatMoney(slip['net_pay'])),
        ],
        columns: const [
          PdfColumn('Component', 'component'),
          PdfColumn('Amount', 'amount', numeric: true),
        ],
        rows: [
          {'component': 'Base salary', 'amount': slip['base_salary']},
          {'component': 'Allowances', 'amount': slip['allowances']},
          {'component': 'Overtime', 'amount': slip['overtime_amount']},
          {'component': 'Bonus', 'amount': slip['bonus']},
          {'component': 'Income tax', 'amount': slip['income_tax']},
          {'component': 'Pension', 'amount': slip['pension_employee']},
          {
            'component': 'Advance deduction',
            'amount': slip['advance_deduction'],
          },
          {'component': 'Other deductions', 'amount': slip['other_deductions']},
          {'component': 'Net pay', 'amount': slip['net_pay']},
        ],
        note: 'This payslip is generated from the live payroll ledger.',
      );
      await BrandPdf.share(
        fileName: 'payslip_${employee?['employee_no'] ?? slip['id']}',
        bytes: bytes,
        subject: 'Brade and Cake House payslip',
      );
    } catch (error) {
      if (context.mounted) {
        showSnack(context, readableError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'Payroll',
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Payroll runs'),
                Tab(text: 'Payslips'),
                Tab(text: 'Tax brackets'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('payroll_runs'),
                    readPermission: 'payroll.manage',
                    writePermission: 'payroll.manage',
                    actions: (row) {
                      if (!session.can('payroll.manage')) return const [];
                      final status = asText(row['status']);
                      return [
                        if (status == 'draft')
                          CrudRowAction(
                            label: 'Generate payslips',
                            icon: Icons.calculate_outlined,
                            onPressed: (row) =>
                                _generate(context, session, row),
                          ),
                        if (status == 'draft')
                          CrudRowAction(
                            label: 'Approve run',
                            icon: Icons.check_circle_outline,
                            onPressed: (row) =>
                                _setStatus(context, session, row, 'approved'),
                          ),
                        if (status == 'approved')
                          CrudRowAction(
                            label: 'Mark paid',
                            icon: Icons.payments_outlined,
                            onPressed: (row) =>
                                _setStatus(context, session, row, 'paid'),
                          ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('payslips'),
                    readPermission: 'payroll.manage',
                    alwaysReadOnly: true,
                    actions: (row) => [
                      CrudRowAction(
                        label: 'Payslip PDF',
                        icon: Icons.print_outlined,
                        onPressed: (row) => _payslip(context, session, row),
                      ),
                    ],
                  ),
                  CrudTab(
                    spec: specFor('tax_brackets'),
                    readPermission: 'payroll.manage',
                    writePermission: 'payroll.manage',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
