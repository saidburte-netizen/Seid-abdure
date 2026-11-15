import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/sign_in_gateway.dart';

/// A Supabase client backed by an in-memory transport.
///
/// Every request is answered locally with an empty JSON array, so tests can
/// never reach a live project. Use [FakeSignInGateway] for sign-in behaviour.
SupabaseClient offlineSupabaseClient() {
  return SupabaseClient(
    'https://offline.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
}

/// Scriptable stand-in for the sign-in backend.
class FakeSignInGateway implements SignInGateway {
  FakeSignInGateway({
    this.admin,
    this.signupAllowed,
    this.adminError,
    this.signupError,
    this.signInError,
  });

  bool? admin;
  bool? signupAllowed;
  Object? adminError;
  Object? signupError;
  Object? signInError;

  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<bool?> hasAdmin() async {
    if (adminError != null) throw adminError!;
    return admin;
  }

  @override
  Future<bool?> customerSignupAllowed() async {
    if (signupError != null) throw signupError!;
    return signupAllowed;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    signUpCalls++;
    lastEmail = email;
    return false;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
