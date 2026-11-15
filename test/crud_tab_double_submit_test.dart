import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/data/schema.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';
import 'package:brade_and_cake_house/widgets/crud_tab.dart';

SupabaseClient _oneRowClient() {
  return SupabaseClient(
    'https://offline.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode([
          {'id': 'w1', 'name': 'Widget', 'branch_id': 'b1'},
        ]),
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
}

const _spec = TableSpec(
  table: 'widgets',
  title: 'Widgets',
  singular: 'Widget',
  fields: [FieldSpec('name', 'Name', list: true)],
  canCreate: false,
  canEdit: false,
  canDelete: false,
);

void main() {
  testWidgets('a row action cannot be fired twice while it is running', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AuthController(_oneRowClient());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    controller
      ..status = AuthStatus.ready
      ..userId = 'test-user'
      ..roleCode = 'admin'
      ..branches = [
        BranchAccess(
          branchId: 'b1',
          branchName: 'Main',
          branchCode: 'MAIN',
          roleCode: 'admin',
          permissions: const {'*'},
        ),
      ]
      ..selectedBranchId = 'b1';

    final gate = Completer<void>();
    var calls = 0;
    var running = 0;
    var maxRunning = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...oromoFrameworkLocalizationsDelegates,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: SessionScope(
          controller: controller,
          child: Scaffold(
            body: CrudTab(
              spec: _spec,
              actions: (row) => [
                CrudRowAction(
                  label: 'Generate',
                  onPressed: (row) async {
                    calls++;
                    running++;
                    if (running > maxRunning) maxRunning = running;
                    await gate.future;
                    running--;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Widget'), findsOneWidget);

    Future<void> chooseGenerate() async {
      await tester.tap(find.byTooltip('Row actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pump();
    }

    await chooseGenerate();
    expect(calls, 1);

    // The menu closes after the first tap; reopen it and tap again while the
    // first call is still in flight.
    await chooseGenerate();
    expect(calls, 1, reason: 'a double tap must not fire the RPC twice');
    expect(maxRunning, 1);

    gate.complete();
    await tester.pumpAndSettle();

    // Once the first call finishes the action is available again.
    await chooseGenerate();
    expect(calls, 2);

    controller.dispose();
  });
}
