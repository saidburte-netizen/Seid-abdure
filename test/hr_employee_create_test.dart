import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/ui_text.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

void main() {
  for (final locale in const ['en', 'am', 'om']) {
    testWidgets('HR employee save works in $locale', (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Map<String, dynamic>? posted;
      final client = sampleSupabaseClient(
        rowsFor: (path) => path.contains('/branches')
            ? [
                {'id': 'test-branch', 'name': 'Test branch', 'code': 'TEST'},
              ]
            : const [],
        onWrite: (request) {
          posted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'employee-$locale',
              'employee_no': posted?['employee_no'],
              'full_name': posted?['full_name'],
              'branch_id': posted?['branch_id'],
            }),
            201,
            headers: const {'content-type': 'application/json'},
            request: request,
          );
        },
      );
      final controller = AuthController(client);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      controller
        ..status = AuthStatus.ready
        ..userId = 'hr-test-user'
        ..fullName = 'HR Test Admin'
        ..roleCode = 'admin'
        ..locale = Locale(locale)
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

      await tester.pumpWidget(
        BakeryApp(
          key: ValueKey('hr-$locale'),
          client: client,
          authController: controller,
          signInGateway: FakeSignInGateway(admin: true),
          initialLocation: '/people',
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsWidgets);
      await tester.enterText(fields.at(1), 'Sales person $locale');
      await tester.tap(find.text(uiTextForLocale(locale, 'Save')));
      await tester.pumpAndSettle();

      expect(posted, isNotNull, reason: 'employee insert was not sent');
      expect(posted!['full_name'], 'Sales person $locale');
      expect(posted!['branch_id'], 'test-branch');
      expect(posted!['employee_no'], startsWith('EMP-'));
      expect(posted!['employee_no'], isNot('EMP-000001'));
      controller.dispose();
    });
  }
}
