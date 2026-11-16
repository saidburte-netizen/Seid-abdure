import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/core/logging/save_diagnostics.dart';

import 'support/fake_backend.dart';

const _branch = {'id': 'branch-1', 'name': 'Main', 'code': 'MAIN'};

Future<AuthController> _readyController(
  WidgetTester tester,
  SupabaseClient client,
) async {
  final controller = AuthController(client);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  controller
    ..status = AuthStatus.ready
    ..userId = 'admin-user'
    ..userEmail = 'admin@example.com'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'branch-1',
        branchName: 'Main',
        branchCode: 'MAIN',
        roleCode: 'admin',
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'branch-1';
  return controller;
}

Widget _app(AuthController controller) => BakeryApp(
  client: controller.client,
  authController: controller,
  signInGateway: FakeSignInGateway(admin: true),
  initialLocation: '/cash',
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _openNewCashAccount(WidgetTester tester) async {
  await tester.pumpWidget(_app(_testController!));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Accounts'));
  final addButton = find.byTooltip('Add').hitTestable();
  await _pumpUntilFound(tester, addButton);
  await tester.tap(addButton);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.byType(TextFormField).at(0), 'seya');
  await tester.enterText(find.byType(TextFormField).at(2), '17000');
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Cash drawer').last);
  await tester.pump(const Duration(milliseconds: 300));
}

AuthController? _testController;

http.Response _jsonResponse(http.Request request, Object value) =>
    http.Response(
      jsonEncode(value),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SaveDiagnostics.instance.resetForTesting();
    _testController = null;
  });

  testWidgets(
    'cash account form sends the insert and waits for its result',
    (tester) async {
      http.Request? insertRequest;
      final client = SupabaseClient(
        'https://cash.test',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/cash_accounts')) {
            insertRequest = request;
            return _jsonResponse(request, [
              {'id': 'cash-1'},
            ]);
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/branches')) {
            return _jsonResponse(request, [_branch]);
          }
          return _jsonResponse(request, []);
        }),
      );
      _testController = await _readyController(tester, client);
      await _openNewCashAccount(tester);

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(insertRequest, isNotNull);
      await tester.pump(const Duration(milliseconds: 100));

      expect(jsonDecode(insertRequest!.body), containsPair('name', 'seya'));
      expect(
        jsonDecode(insertRequest!.body),
        containsPair('opening_balance', 17000),
      );
      expect(find.text('Saving…'), findsNothing);
      expect(tester.takeException(), isNull);
      final attemptId = SaveDiagnostics.instance.entries.first.attemptId;
      expect(
        SaveDiagnostics.instance.entries
            .where((entry) => entry.attemptId == attemptId)
            .map((entry) => entry.step)
            .toList(),
        [
          'bumped',
          'response received',
          'request sent',
          'session ok',
          'validated',
        ],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      _testController!.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'resuming during an in-flight save preserves its dialog',
    (tester) async {
      final pendingResponse = Completer<http.Response>();
      final pendingRequest = Completer<http.Request>();
      final client = SupabaseClient(
        'https://cash.test',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/cash_accounts')) {
            pendingRequest.complete(request);
            return pendingResponse.future;
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/branches')) {
            return _jsonResponse(request, [_branch]);
          }
          return _jsonResponse(request, []);
        }),
      );
      _testController = await _readyController(tester, client);
      await _openNewCashAccount(tester);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(pendingRequest.isCompleted, isTrue);
      final request = await pendingRequest.future;

      _testController!.debugSetLastActivity(
        DateTime.now().subtract(const Duration(minutes: 31)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(_testController!.status, AuthStatus.ready);
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      pendingResponse.complete(
        _jsonResponse(request, [
          {'id': 'cash-1'},
        ]),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      _testController!.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'restarts on cash accounts after an interrupted unsent save',
    (tester) async {
      const attemptId = 'interrupted-cash-account';
      SharedPreferences.setMockInitialValues({
        'brade_save_breadcrumbs_v1': jsonEncode([
          {
            'attemptId': attemptId,
            'time': DateTime.now().toIso8601String(),
            'module': 'Cash accounts',
            'target': 'cash_accounts',
            'step': 'validated',
          },
        ]),
      });
      SaveDiagnostics.instance.resetForTesting();

      final client = SupabaseClient(
        'https://cash.test',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => _jsonResponse(
            request,
            request.method == 'GET' && request.url.path.endsWith('/branches')
                ? [_branch]
                : [],
          ),
        ),
      );
      _testController = await _readyController(tester, client);
      await tester.pumpWidget(_app(_testController!));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(
          'The previous cash account was not saved. Re-enter it and save again.',
        ),
        findsOneWidget,
      );
      expect(SaveDiagnostics.instance.pendingRecovery?.attemptId, attemptId);

      await tester.tap(find.text('Dismiss'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('The previous cash account was not saved.'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      _testController!.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
