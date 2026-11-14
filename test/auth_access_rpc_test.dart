import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-in access uses anonymous-safe RPCs and never app_settings', () {
    final source = File('lib/app.dart').readAsStringSync();
    final start = source.indexOf('class _SignInScreenState');
    expect(start, greaterThanOrEqualTo(0));
    final nextClass = source.indexOf('\nclass ', start + 1);
    final block = source.substring(
      start,
      nextClass == -1 ? source.length : nextClass,
    );

    expect(block, contains("rpc('has_admin')"));
    expect(block, contains("rpc('customer_signup_allowed')"));
    expect(block, isNot(contains("from('app_settings')")));
    expect(block, isNot(contains('allow_customer_signup')));
  });

  test('profile photos upload under the signed-in user id folder', () {
    final source = File(
      'lib/screens/settings/profile_screen.dart',
    ).readAsStringSync();
    expect(source, contains(r"'$userId/avatar_"));
    expect(source, contains(".from('avatars')"));
  });
}
