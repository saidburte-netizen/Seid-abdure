import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/schema.dart';
import '../widgets/common.dart';
import '../widgets/crud_tab.dart';
import '../widgets/module_scaffold.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  Future<void> _decide(
    BuildContext context,
    AuthController session,
    Map<String, dynamic> approval,
    bool approve,
  ) async {
    final note = await showInputDialog(
      context,
      title: approve ? 'Approve request' : 'Reject request',
      submitLabel: approve ? 'Approve' : 'Reject',
      fields: [
        InputField(
          'note',
          approve ? 'Note (optional)' : 'Rejection reason',
          required: !approve,
          type: FieldType.multiline,
        ),
      ],
    );
    if (note == null) return;
    try {
      await session.client
          .from('approvals')
          .update({
            'status': approve ? 'approved' : 'rejected',
            'approver_id': session.userId,
            'decision_note': note['note'],
            'decided_at': nowIso(),
          })
          .eq('id', approval['id']);
      if (context.mounted) {
        showSnack(context, approve ? 'Request approved.' : 'Request rejected.');
      }
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
      title: 'Approvals',
      body: CrudTab(
        spec: specFor('approvals'),
        readPermission: 'expenses.approve',
        writePermission: 'expenses.approve',
        actions: (row) {
          if (!session.can('expenses.approve') || row['status'] != 'pending') {
            return const [];
          }
          return [
            CrudRowAction(
              label: 'Approve',
              icon: Icons.check_circle_outline,
              onPressed: (row) => _decide(context, session, row, true),
            ),
            CrudRowAction(
              label: 'Reject',
              icon: Icons.cancel_outlined,
              danger: true,
              onPressed: (row) => _decide(context, session, row, false),
            ),
          ];
        },
      ),
    );
  }
}
