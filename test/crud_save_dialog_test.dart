import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/core/events/data_revision.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

void _setPortal(AuthController controller) {
  controller
    ..status = AuthStatus.ready
    ..userId = 'test-user'
    ..fullName = 'Test User'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'test-branch',
        branchName: 'Test branch',
        branchCode: 'TEST',
        roleCode: 'admin',
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'test-branch';
}

Finder _formField(String label) {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    ),
  );
}

http.Response _permissionDenied(http.Request request) {
  return http.Response(
    jsonEncode({
      'code': '42501',
      'message': 'new row violates row-level security policy',
      'details': null,
      'hint': null,
    }),
    403,
    headers: const {'content-type': 'application/json'},
    request: request,
  );
}

http.Response _created(http.Request request) {
  return http.Response(
    jsonEncode({
      'id': 'new-property',
      'code': 'PROP-001',
      'name': 'Test property',
      'property_type': 'House',
      'monthly_rent': 0,
      'status': 'vacant',
      'branch_id': 'test-branch',
    }),
    201,
    headers: const {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  testWidgets(
    'a failed record save stays in the form, then a retry saves and refreshes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var failWrite = true;
      final client = sampleSupabaseClient(
        onWrite: (request) =>
            failWrite ? _permissionDenied(request) : _created(request),
      );
      final controller = AuthController(client);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      _setPortal(controller);

      await tester.pumpWidget(
        BakeryApp(
          client: client,
          authController: controller,
          signInGateway: FakeSignInGateway(admin: true),
          initialLocation: '/rentals',
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New Property'), findsOneWidget);

      await tester.enterText(_formField('Name'), 'Test property');
      await tester.enterText(_formField('Property type'), 'House');
      final revisionBefore = DataRevision.notifier.value;

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The form is still open, the typed values are intact, and the inline
      // message explains the failure without technical database text.
      expect(find.text('New Property'), findsOneWidget);
      expect(find.text('Test property'), findsOneWidget);
      expect(
        find.text('You do not have permission to do this.'),
        findsOneWidget,
      );
      expect(DataRevision.notifier.value, revisionBefore);

      // Retrying inside the same form succeeds, closes it, confirms the save,
      // and bumps the revision that refreshes the dashboard and lists.
      failWrite = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('New Property'), findsNothing);
      expect(find.text('Property saved.'), findsOneWidget);
      expect(DataRevision.notifier.value, revisionBefore + 1);

      controller.dispose();
    },
  );
}
