import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/save_flow.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';
import '../l10n/ui_text.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  Future<void> _decideLeave(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> leave,
    bool approve,
  ) async {
    try {
      await SaveFlow.write(
        module: 'People & HR',
        target: 'leave_requests',
        action: () => session.client
            .from('leave_requests')
            .update({
              'status': approve ? 'approved' : 'rejected',
              'approved_by': session.userId,
              'decided_at': nowIso(),
            })
            .eq('id', leave['id']),
      );
      if (context.mounted) {
        showSnack(context, approve ? 'Leave approved.' : 'Leave rejected.');
      }
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  Future<void> _requestLeave(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> employee,
  ) async {
    try {
      final types = await session.client
          .from('leave_types')
          .select()
          .order('name');
      if (!context.mounted) return;
      if (types.isEmpty) {
        showSnack(
          context,
          uiText(context, 'Create a leave type before requesting leave.'),
          error: true,
        );
        return;
      }
      final request = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _LeaveDialog(
          employeeName: asText(employee['full_name']),
          types: [for (final row in types) Map<String, dynamic>.from(row)],
        ),
      );
      if (request == null || !context.mounted) return;
      await SaveFlow.write(
        module: 'People & HR',
        target: 'leave_requests',
        action: () => session.client.from('leave_requests').insert({
          'employee_id': employee['id'],
          'leave_type_id': request['type'],
          'start_date': request['start'],
          'end_date': request['end'],
          'days': request['days'],
          'status': 'pending',
        }),
      );
      if (context.mounted) {
        showSnack(context, uiText(context, 'Leave request saved.'));
      }
    } catch (error) {
      if (context.mounted) showFriendlyError(context, error);
    }
  }

  Future<void> _attendance(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> employee, {
    required String action,
  }) async {
    final today = dateOnly(DateTime.now());
    try {
      final existing = await session.client
          .from('attendance')
          .select()
          .eq('employee_id', employee['id'])
          .eq('work_date', today)
          .maybeSingle();
      await SaveFlow.write(
        module: 'People & HR',
        target: 'attendance',
        action: () async {
          if (existing == null) {
            await session.client.from('attendance').insert({
              'employee_id': employee['id'],
              'work_date': today,
              'status': 'present',
              'clock_in': nowIso(),
              if (action == 'clock_out') 'clock_out': nowIso(),
            });
            return;
          }
          final values = <String, dynamic>{'status': 'present'};
          if (action == 'clock_in') {
            values['clock_in'] = existing['clock_in'] ?? nowIso();
          } else if (action == 'clock_out') {
            values['clock_in'] = existing['clock_in'] ?? nowIso();
            values['clock_out'] = nowIso();
          } else {
            values['clock_in'] = existing['clock_in'] ?? nowIso();
          }
          await session.client
              .from('attendance')
              .update(values)
              .eq('id', existing['id']);
        },
      );
      if (context.mounted) {
        showSnack(context, uiText(context, 'Attendance saved.'));
      }
    } catch (error) {
      if (context.mounted) showFriendlyError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'People & HR'),
      kpiKinds: const [KpiKind.staffPresent, KpiKind.todaySales],
      body: DefaultTabController(
        length: 10,
        child: Column(
          children: [
            const AppTabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Employees'),
                Tab(text: 'Departments'),
                Tab(text: 'Documents'),
                Tab(text: 'Shifts'),
                Tab(text: 'Employee shifts'),
                Tab(text: 'Attendance'),
                Tab(text: 'Leave types'),
                Tab(text: 'Leave requests'),
                Tab(text: 'Advances'),
                Tab(text: 'HR notes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: specFor('employees'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                    actions: (row) {
                      if (!session.can('hr.manage')) return const [];
                      return [
                        CrudRowAction(
                          label: uiText(context, 'Clock in'),
                          icon: Icons.login,
                          onPressed: (row) => _attendance(
                            context,
                            session,
                            row,
                            action: 'clock_in',
                          ),
                        ),
                        CrudRowAction(
                          label: uiText(context, 'Clock out'),
                          icon: Icons.logout,
                          onPressed: (row) => _attendance(
                            context,
                            session,
                            row,
                            action: 'clock_out',
                          ),
                        ),
                        CrudRowAction(
                          label: uiText(context, 'Mark present'),
                          icon: Icons.check_circle_outline,
                          onPressed: (row) => _attendance(
                            context,
                            session,
                            row,
                            action: 'present',
                          ),
                        ),
                        CrudRowAction(
                          label: uiText(context, 'Request leave'),
                          icon: Icons.beach_access_outlined,
                          onPressed: (row) =>
                              _requestLeave(context, session, row),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('departments'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('employee_documents'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('shifts'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('employee_shifts'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('attendance'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('leave_types'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('leave_requests'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                    actions: (row) {
                      if (!session.can('hr.manage') ||
                          row['status'] != 'pending') {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: uiText(context, 'Approve leave'),
                          icon: Icons.check_circle_outline,
                          onPressed: (row) =>
                              _decideLeave(context, session, row, true),
                        ),
                        CrudRowAction(
                          label: uiText(context, 'Reject leave'),
                          icon: Icons.cancel_outlined,
                          danger: true,
                          onPressed: (row) =>
                              _decideLeave(context, session, row, false),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: specFor('employee_advances'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
                  ),
                  CrudTab(
                    spec: specFor('hr_notes'),
                    readPermission: 'hr.view',
                    writePermission: 'hr.manage',
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

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({required this.employeeName, required this.types});

  final String employeeName;
  final List<Map<String, dynamic>> types;

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  String? _typeId;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _typeId = widget.types.first['id']?.toString();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    if (_typeId == null) {
      setState(() => _error = uiText(context, 'Choose a leave type.'));
      return;
    }
    if (_end.isBefore(_start)) {
      setState(
        () => _error = uiText(context, 'End date cannot be before start date.'),
      );
      return;
    }
    final days = _end.difference(_start).inDays + 1;
    Navigator.of(context).pop({
      'type': _typeId,
      'start': dateOnly(_start),
      'end': dateOnly(_end),
      'days': days,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, 'Request leave')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employeeName),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _typeId,
              decoration: InputDecoration(
                labelText: '${uiText(context, 'Leave type')} *',
              ),
              items: [
                for (final type in widget.types)
                  DropdownMenuItem(
                    value: type['id'].toString(),
                    child: Text(asText(type['name'])),
                  ),
              ],
              onChanged: (value) => setState(() => _typeId = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(uiText(context, 'Start date')),
              subtitle: Text(formatDate(_start)),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(uiText(context, 'End date')),
              subtitle: Text(formatDate(_end)),
              onTap: () => _pickDate(false),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, 'Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(uiText(context, 'Save'))),
      ],
    );
  }
}
