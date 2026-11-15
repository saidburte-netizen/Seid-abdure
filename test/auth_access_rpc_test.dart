import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-in access uses anonymous-safe RPCs and never app_settings', () {
    final gatewaySource = File(
      'lib/auth/sign_in_gateway.dart',
    ).readAsStringSync();
    expect(gatewaySource, contains("rpc('has_admin')"));
    expect(gatewaySource, contains("rpc('customer_signup_allowed')"));
    expect(gatewaySource, isNot(contains("from('app_settings')")));
    expect(gatewaySource, isNot(contains('allow_customer_signup')));

    final appSource = File('lib/app.dart').readAsStringSync();
    final start = appSource.indexOf('class _SignInScreenState');
    expect(start, greaterThanOrEqualTo(0));
    final nextClass = appSource.indexOf('\nclass ', start + 1);
    final block = appSource.substring(
      start,
      nextClass == -1 ? appSource.length : nextClass,
    );
    // The screen talks to the injected gateway, never to a table or the
    // Supabase client directly.
    expect(block, contains('widget.gateway.hasAdmin()'));
    expect(block, contains('widget.gateway.customerSignupAllowed()'));
    expect(block, contains('widget.gateway.signIn('));
    expect(block, isNot(contains("from('app_settings')")));
    expect(block, isNot(contains("rpc('")));
  });

  test('profile photos upload under the signed-in user id folder', () {
    final source = File(
      'lib/screens/settings/profile_screen.dart',
    ).readAsStringSync();
    expect(source, contains(r"'$userId/avatar_"));
    expect(source, contains(".from('avatars')"));
  });
}
