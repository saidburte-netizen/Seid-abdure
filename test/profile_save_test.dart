import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';
import 'package:brade_and_cake_house/screens/settings/profile_screen.dart';

http.Response _profileResponse(http.Request request) => http.Response(
  '{"id":"profile-user"}',
  200,
  headers: const {'content-type': 'application/json'},
  request: request,
);

Future<AuthController> _controller(
  WidgetTester tester,
  SupabaseClient client, {
  Duration profileWriteTimeout = const Duration(seconds: 20),
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(
    client,
    profileWriteTimeout: profileWriteTimeout,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  controller
    ..status = AuthStatus.ready
    ..userId = 'profile-user'
    ..userEmail = 'profile@example.com'
    ..fullName = 'Original Name'
    ..phone = '0911000000'
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

Widget _profileApp(AuthController controller) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    ...oromoFrameworkLocalizationsDelegates,
    ...AppLocalizations.localizationsDelegates,
  ],
  home: SessionScope(controller: controller, child: const ProfileScreen()),
);

void main() {
  testWidgets('profile save confirms the updated database row', (tester) async {
    http.Request? updateRequest;
    final client = SupabaseClient(
      'https://profile.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          updateRequest = request;
          return _profileResponse(request);
        }
        return http.Response(
          '[]',
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final controller = await _controller(tester, client);

    await tester.pumpWidget(_profileApp(controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(updateRequest, isNotNull);
    expect(updateRequest!.url.path, endsWith('/rest/v1/profiles'));
    expect(jsonDecode(updateRequest!.body), {'full_name': 'Updated Name'});
    expect(find.text('Profile updated.'), findsOneWidget);
    expect(controller.fullName, 'Updated Name');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('a stalled profile save stops and reports a friendly timeout', (
    tester,
  ) async {
    final pendingResponse = Completer<http.Response>();
    final pendingRequest = Completer<http.Request>();
    final client = SupabaseClient(
      'https://profile.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          pendingRequest.complete(request);
          return pendingResponse.future;
        }
        return http.Response(
          '[]',
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final controller = await _controller(
      tester,
      client,
      profileWriteTimeout: const Duration(milliseconds: 50),
    );

    await tester.pumpWidget(_profileApp(controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    final request = await pendingRequest.future;
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(jsonDecode(request.body), {'full_name': 'Updated Name'});
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text(
        'No internet connection. Please check your network and try again.',
      ),
      findsOneWidget,
    );
    expect(controller.fullName, 'Original Name');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    pendingResponse.complete(_profileResponse(request));
    controller.dispose();
  });
}
