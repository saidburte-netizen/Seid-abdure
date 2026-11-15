import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
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
      await session.client.from('leave_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'approved_by': session.userId,
        'decided_at': nowIso(),
      }).eq('id', leave['id']);
      if (context.mounted) {
        showSnack(context, approve ? 'Leave approved.' : 'Leave rejected.');
      }
    } catch (error) {
      if (context.mounted) {
        showFriendlyError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ModuleScaffold(
      title: uiText(context, 'People & HR'),
      body: DefaultTabController(
        length: 10,
        child: Column(
          children: [
            const TabBar(
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
