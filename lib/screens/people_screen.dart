import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: 'People & HR',
      body: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Employees'),
                Tab(text: 'Attendance'),
                Tab(text: 'Leave requests'),
                Tab(text: 'Shifts'),
                Tab(text: 'Leave types'),
                Tab(text: 'Attendance summary'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CrudTab(
                    spec: employeesSpec,
                    readPermission: 'people.read',
                    writePermission: 'people.write',
                  ),
                  CrudTab(
                    spec: attendanceSpec,
                    readPermission: 'people.read',
                    writePermission: 'people.write',
                  ),
                  CrudTab(
                    spec: leaveRequestsSpec,
                    readPermission: 'people.read',
                    writePermission: 'people.write',
                    actions: (row) {
                      if (row['status'] != 'pending' ||
                          !session.can('people.write')) {
                        return const [];
                      }
                      return [
                        CrudRowAction(
                          label: 'Approve leave',
                          icon: Icons.check_circle_outline,
                          onPressed: (row) =>
                              _reviewLeave(session, row, true),
                        ),
                        CrudRowAction(
                          label: 'Reject leave',
                          icon: Icons.cancel_outlined,
                          danger: true,
                          onPressed: (row) =>
                              _reviewLeave(session, row, false),
                        ),
                      ];
                    },
                  ),
                  CrudTab(
                    spec: shiftsSpec,
                    readPermission: 'people.read',
                    writePermission: 'people.write',
                  ),
                  CrudTab(
                    spec: leaveTypesSpec,
                    readPermission: 'people.read',
                    writePermission: 'people.write',
                  ),
                  CrudTab(
                    spec: _attendanceSummarySpec,
                    readPermission: 'people.read',
                    alwaysReadOnly: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewLeave(
    AuthController session,
    Map<String, dynamic> request,
    bool approve,
  ) async {
    final note = await showInputDialog(
      context,
      title: approve ? 'Approve leave request' : 'Reject leave request',
      submitLabel: approve ? 'Approve' : 'Reject',
      fields: [
        InputField(
          'note',
          'Review note',
          type: FieldType.multiline,
          required: !approve,
        ),
      ],
    );
    if (note == null) return;
    try {
      final response = await session.client.rpc('review_leave_request', params: {
        'target_request': request['id'],
        'approve': approve,
        'note': note['note'] ?? '',
      });
      if (mounted) {
        await showInfoDialog(
          context,
          title: approve ? 'Leave approved' : 'Leave rejected',
          content: response,
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, readableError(error), error: true);
    }
  }
}

const _attendanceSummarySpec = TableSpec(
  table: 'attendance_monthly',
  title: 'Attendance summary',
  singular: 'Attendance summary',
  orderBy: 'month',
  ascending: false,
  branchScoped: true,
  searchColumns: [],
  canCreate: false,
  canEdit: false,
  canDelete: false,
  fields: [
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', list: true),
    FieldSpec('month', 'Month', type: FieldType.date, list: true),
    FieldSpec('days_worked', 'Days worked', type: FieldType.number, list: true),
    FieldSpec('days_absent', 'Days absent', type: FieldType.number, list: true),
    FieldSpec('days_leave', 'Days leave', type: FieldType.number, list: true),
    FieldSpec('overtime_hours', 'Overtime hours', type: FieldType.number, list: true),
  ],
);
