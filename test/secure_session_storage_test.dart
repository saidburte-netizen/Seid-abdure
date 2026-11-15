import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/auth/secure_local_storage.dart';

void main() {
  const key = 'sb-session-key';
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('moves a legacy plain-text session into secure storage', () async {
    await preferences.setString(key, '{"access_token":"legacy"}');
    final storage = SecureLocalStorage(persistSessionKey: key);

    await storage.initialize();

    expect(await storage.accessToken(), '{"access_token":"legacy"}');
    expect(await storage.hasAccessToken(), isTrue);
    expect(preferences.getString(key), isNull, reason: 'plain copy is deleted');
  });

  test('does not overwrite a newer secure session with a stale copy', () async {
    const secure = FlutterSecureStorage();
    await secure.write(key: key, value: '{"access_token":"new"}');
    await preferences.setString(key, '{"access_token":"old"}');
    final storage = SecureLocalStorage(persistSessionKey: key);

    await storage.initialize();

    expect(await storage.accessToken(), '{"access_token":"new"}');
    expect(preferences.getString(key), isNull);
  });

  test('new sessions are written to secure storage only', () async {
    final storage = SecureLocalStorage(persistSessionKey: key);

    await storage.initialize();
    await storage.persistSession('{"access_token":"fresh"}');

    expect(await storage.accessToken(), '{"access_token":"fresh"}');
    expect(preferences.getString(key), isNull);
    expect(
      await const FlutterSecureStorage().read(key: key),
      contains('fresh'),
    );
  });

  test('removing the session clears secure storage', () async {
    final storage = SecureLocalStorage(persistSessionKey: key);
    await storage.persistSession('{"access_token":"fresh"}');

    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
  });
}
