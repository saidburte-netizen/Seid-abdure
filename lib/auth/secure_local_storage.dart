import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase session in the platform secure store instead of
/// plain-text shared preferences.
///
/// On first launch after upgrading, an existing shared-preferences session is
/// copied into secure storage and then removed from shared preferences. Users
/// keep their session and the plain-text copy is deleted.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  @override
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final legacySession = preferences.getString(persistSessionKey);
    if (legacySession == null) return;
    // Never overwrite a session that already lives in secure storage: the
    // plain-text copy is older by definition.
    final existing = await _storage.read(key: persistSessionKey);
    if (existing == null) {
      await _storage.write(key: persistSessionKey, value: legacySession);
    }
    await preferences.remove(persistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.read(key: persistSessionKey) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);
}
