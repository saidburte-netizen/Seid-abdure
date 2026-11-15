import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/data/repository.dart';

/// Answers PostgREST range requests from an in-memory list, so pagination can
/// be proven without a database.
SupabaseClient pagedClient(
  List<Map<String, dynamic>> rows, {
  void Function(int start, int end)? onRange,
}) {
  return SupabaseClient(
    'https://offline.invalid',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      // postgrest 2.8 paginates with `offset` and `limit` query parameters.
      final start = int.parse(request.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '1000');
      onRange?.call(start, start + limit - 1);
      final slice = rows.skip(start).take(limit).toList();
      return http.Response(
        jsonEncode(slice),
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
}

void main() {
  test(
    'listAll fetches every page past the 1,000 row PostgREST limit',
    () async {
      final rows = [
        for (var i = 0; i < 2500; i++) {'id': 'row-$i', 'branch_id': 'b1'},
      ];
      final ranges = <(int, int)>[];
      final repository = BranchRepository(
        pagedClient(rows, onRange: (start, end) => ranges.add((start, end))),
        'b1',
      );

      final result = await repository.listAll('items');

      expect(result, hasLength(2500));
      expect(result.first['id'], 'row-0');
      expect(result.last['id'], 'row-2499');
      expect(ranges, [(0, 999), (1000, 1999), (2000, 2999)]);
    },
  );

  test('listAll stops on a short page and does not over-fetch', () async {
    final rows = [
      for (var i = 0; i < 1200; i++) {'id': 'row-$i'},
    ];
    final ranges = <(int, int)>[];
    final repository = BranchRepository(
      pagedClient(rows, onRange: (start, end) => ranges.add((start, end))),
      'b1',
    );

    final result = await repository.listAll('items');

    expect(result, hasLength(1200));
    expect(ranges, [(0, 999), (1000, 1999)]);
  });

  test('a hung read times out and retries exactly once', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://offline.invalid',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('[]', 200, request: request);
      }),
    );
    final repository = BranchRepository(
      client,
      'b1',
      readTimeout: const Duration(milliseconds: 40),
    );

    await expectLater(
      repository.list('items'),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 2, reason: 'reads retry once, then surface the failure');
  });

  test('writes are never retried', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://offline.invalid',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls++;
        throw http.ClientException('connection closed', request.url);
      }),
    );
    final repository = BranchRepository(client, 'b1');

    await expectLater(
      repository.insert('items', {'name': 'Flour'}),
      throwsA(isA<http.ClientException>()),
    );
    expect(calls, 1, reason: 'a retried write could duplicate money or stock');
  });
}
