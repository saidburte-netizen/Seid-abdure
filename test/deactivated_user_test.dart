import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';

void main() {
  testWidgets('a deactivated profile is signed out with a notice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://offline.invalid',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/rest/v1/profiles')) {
          return http.Response(
            '{"id":"deactivated-user","full_name":"Gone","role_code":"admin",'
            '"branch_id":null,"is_active":false,"language":"en"}',
            200,
            headers: const {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('{}', 200, request: request);
      }),
    );
    final controller = AuthController(client);
    await tester.pump(const Duration(milliseconds: 20));

    final session = Session.fromJson({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {
        'id': 'deactivated-user',
        'aud': 'authenticated',
        'email': 'gone@example.com',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    })!;
    await controller.debugLoadSession(session);

    expect(controller.status, AuthStatus.signedOut);
    expect(controller.userId, isNull);
    expect(controller.roleCode, isNull);
    expect(controller.branches, isEmpty);
    expect(controller.signInNotice, contains('deactivated'));
  });
}
