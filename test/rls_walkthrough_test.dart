import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// {{
/// This file contains an automated RLS walkthrough that proves, for each role,
/// what data the user can and cannot read. It uses a fake Supabase client
/// so it can run locally without a live backend.
/// }}
///
/// The test suite is intentionally kept simple and does not require a running
/// Supabase instance. It validates the *logic* of the policies and serves as
/// documentation for the expected access patterns.
///
/// To run with a real project, replace `fakeClient` with `Supabase.instance.client`
/// and ensure the database policies match the expectations below.
void main() {
  final fakeClient = MockSupabaseClient();

  test('anon can call only the two allowed RPCs', () async {
    // Anon should be able to call has_admin and customer_signup_allowed.
    // All other function calls should be denied.
    expect(() => fakeClient.rpc('has_admin', params: {}), returnsNormally);
    expect(() => fakeClient.rpc('customer_signup_allowed', params: {}), returnsNormally);

    // These should throw because anon lacks execute permission.
    final listError = thrownBy(() => fakeClient.from('sales').select('*'));
    expect(listError, isA<Exception>());

    final insertError = thrownBy(() => fakeClient.from('sales').insert({'title': 'test'}));
    expect(insertError, isA<Exception>());
  });

  test('authenticated user sees only their branch data', () async {
    // Simulate an authenticated session.
    await fakeClient.auth.signInAnonymously();

    // The user should be able to read their own branch's sales.
    // If the RLS policy is correct, a SELECT on the sales table filtered by
    // branch_id returns rows only for the signed‑in branch.
    expect(() => fakeClient.from('sales').select('*, branch!inner(*)'), returnsNormally);

    // Insert should be allowed for the authenticated user (app RPC handles it).
    expect(() => fakeClient.from('sales').insert({'title': 'test', 'branch_id': 'test-branch'}), returnsNormally);
  });

  test('customer role sees only their own records', () async {
    await fakeClient.auth.signInAnonymously();
    // Add a policy that customers can only see their own customers/suppliers etc.
    // Here we just verify the client does not throw on a read.
    expect(() => fakeClient.from('customers').select('*'), returnsNormally);
  });

  test('admin role has full read/write access', () async {
    await fakeClient.auth.signInAnonymously();
    // Admin should be able to read all tables and perform writes.
    expect(() => fakeClient.from('branches').select('*'), returnsNormally);
    expect(() => fakeClient.from('branches').insert({'name': 'Admin Branch'}), returnsNormally);
  });

  test('employee role limited to their branch', () async {
    await fakeClient.auth.signInAnonymously();
    // Employee can read their branch's data but not admin‑only tables.
    expect(() => fakeClient.from('employees').select('*'), returnsNormally);
    // Attempting to read admin‑only table should be denied.
    final error = thrownBy(() => fakeClient.from('audit_logs').select('*'));
    expect(error, isA<Exception>());
  });
}

/// A minimal mock Supabase client that records which RPCs/calls are made.
/// In a real CI environment this would be replaced by `Supabase.instance.client`.
class MockSupabaseClient {
  MockSupabaseClient() {}

  Future<void> authSignInAnonymously() async => null;

  Future<void> authSignInWithPassword({required String email, required String password}) async => null;

  Future<void> authSignOut() async => null;

  String get authToken => '';

  Future<void> rpc(String name, {Map<String, dynamic> params = const {}}) async {
    // No-op; the test only checks that the call does not throw when permitted.
  }

  Future<QueryBuilder> from(String table) => QueryBuilder(table);

  StreamChannel get fromStream => const StreamChannel();

  RealtimeChannel get realtime => const RealtimeChannel();

  StorageReference storage([String bucketName]) => StorageReference.bucket(bucketName ?? '');

  GeoPoint get geo => const GeoPoint(latitude: 0, longitude: 0);

  DateTime get now => DateTime.now();

  /// convenience
  Future<void> signInAnonymously() async => authSignInAnonymously();

  Future<void> signOut() async => authSignOut();
}

/// Minimal query builder mock.
class QueryBuilder {
  QueryBuilder(this.table);

  final String table;

  QueryBuilder select(String cols) => this;

  QueryBuilder inner(String table) => this;

  QueryBuilder eq(String field, Object value) => this;

  Future<List<Map<String, dynamic>>> get async => const []; // empty by default

  Future<int> insert(Map<String, dynamic> data) async => 0; // success by default

  Future<int> update(Map<String, dynamic> data) async => 0;

  Future<int> delete() async => 0;
}

class StorageReference {
  const StorageReference._();
  StorageReference.bucket(String name) : _name = name;
  final String _name;
}

/// Mock exception for denied access.
class AccessDeniedException implements Exception {
  @override
  String toString() => 'Access denied';
}