import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/save_flow.dart';

/// The narrow slice of the backend that the sign-in screen needs.
///
/// The screen depends on this interface instead of [SupabaseClient] so tests
/// can simulate `has_admin()`, `customer_signup_allowed()`, sign-in and
/// sign-up without a network connection or a live project. Production wiring
/// is [SupabaseSignInGateway].
abstract class SignInGateway {
  /// Returns `null` when the backend answered but the value could not be read.
  Future<bool?> hasAdmin();

  /// Returns `null` when the backend answered but the value could not be read.
  Future<bool?> customerSignupAllowed();

  Future<void> signIn({required String email, required String password});

  /// Returns true when sign-up produced a session immediately, i.e. no email
  /// confirmation is pending.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut();
}

class SupabaseSignInGateway implements SignInGateway {
  const SupabaseSignInGateway(this.client);

  final SupabaseClient client;

  @override
  Future<bool?> hasAdmin() async => readBoolOrNull(
    await SaveFlow.read(
      module: 'Sign in',
      target: 'has_admin',
      action: () => client.rpc('has_admin'),
    ),
  );

  @override
  Future<bool?> customerSignupAllowed() async => readBoolOrNull(
    await SaveFlow.read(
      module: 'Sign in',
      target: 'customer_signup_allowed',
      action: () => client.rpc('customer_signup_allowed'),
    ),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return response.session != null;
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
  }
}

/// Reads a boolean from the shapes a Postgres function may return: a bare
/// boolean, a number, a string, a single-key object or a one-row list.
bool? readBoolOrNull(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == 't' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == 'f' || text == '0' || text == 'no') {
      return false;
    }
    return null;
  }
  if (value is Map) {
    for (final key in const [
      'has_admin',
      'allowed',
      'exists',
      'result',
      'value',
    ]) {
      if (value.containsKey(key)) {
        final parsed = readBoolOrNull(value[key]);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
  if (value is List && value.isNotEmpty) return readBoolOrNull(value.first);
  return null;
}
