import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/data/repository.dart';

void main() {
  test(
    'branch repository scopes reads and writes to the selected branch',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '{"id":"00000000-0000-0000-0000-000000000001",'
            '"branch_id":"branch-1","name":"Test"}',
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final repository = BranchRepository(client, 'branch-1');
      await repository.list('items');
      expect(requests.last.url.queryParameters['branch_id'], 'eq.branch-1');

      final inserted = await repository.insert('items', {'name': 'Test'});
      expect(inserted['branch_id'], 'branch-1');
      expect(jsonDecode(requests.last.body)['branch_id'], 'branch-1');

      await repository.list('app_settings', branchScoped: false);
      expect(
        requests.last.url.queryParameters.containsKey('branch_id'),
        isFalse,
      );
    },
  );
}
