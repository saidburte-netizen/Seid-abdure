import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

export '../core/errors/friendly_error.dart';

/// A thin, branch-scoped data access layer.
///
/// Every write that changes money, stock or credit must use a database RPC.
/// This repository is for ordinary master data and read models only.
class BranchRepository {
  BranchRepository(
    this.client,
    this.branchId, {
    this.readTimeout = const Duration(seconds: 20),
  });

  final SupabaseClient client;
  final String branchId;

  /// Read timeout. Tests shorten it; production keeps 20 seconds.
  final Duration readTimeout;

  /// Retries idempotent reads once with a short backoff. Writes are never
  /// retried because a retried write can duplicate money or stock.
  Future<T> _read<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action().timeout(readTimeout);
      } catch (error) {
        if (attempt >= 1 || !_isRetryableRead(error)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  bool _isRetryableRead(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }
    if (error is PostgrestException) {
      final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
      return text.contains('timeout') ||
          text.contains('temporarily unavailable') ||
          text.contains('upstream') ||
          text.contains('connection');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> list(
    String table, {
    String columns = '*',
    String? orderBy,
    bool ascending = true,
    bool branchScoped = true,
    Map<String, Object?> equals = const {},
    int limit = 500,
  }) => _listPage(
    table,
    columns: columns,
    orderBy: orderBy,
    ascending: ascending,
    branchScoped: branchScoped,
    equals: equals,
    offset: 0,
    limit: limit,
  );

  /// Fetches every page. Use this for exports and reports, never for a
  /// screen that only needs the first page.
  Future<List<Map<String, dynamic>>> listAll(
    String table, {
    String columns = '*',
    String? orderBy,
    bool ascending = true,
    bool branchScoped = true,
    Map<String, Object?> equals = const {},
    int pageSize = 1000,
  }) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _listPage(
        table,
        columns: columns,
        orderBy: orderBy,
        ascending: ascending,
        branchScoped: branchScoped,
        equals: equals,
        offset: offset,
        limit: pageSize,
      );
      all.addAll(page);
      if (page.length < pageSize) return all;
      offset += pageSize;
    }
  }

  Future<List<Map<String, dynamic>>> _listPage(
    String table, {
    required String columns,
    required String? orderBy,
    required bool ascending,
    required bool branchScoped,
    required Map<String, Object?> equals,
    required int offset,
    required int limit,
  }) async {
    dynamic query = client.from(table).select(columns);
    if (branchScoped && branchId.isNotEmpty) {
      query = query.eq('branch_id', branchId);
    }
    for (final entry in equals.entries) {
      query = query.eq(entry.key, entry.value);
    }
    if (orderBy != null) query = query.order(orderBy, ascending: ascending);
    query = query.range(offset, offset + limit - 1);
    final rows = await _read(() async => await query);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> first(
    String table, {
    String columns = '*',
    bool branchScoped = true,
    Map<String, Object?> equals = const {},
  }) async {
    final rows = await list(
      table,
      columns: columns,
      branchScoped: branchScoped,
      equals: equals,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> values, {
    bool branchScoped = true,
  }) async {
    final payload = Map<String, dynamic>.from(values);
    if (branchScoped && branchId.isNotEmpty) {
      payload['branch_id'] = branchId;
    }
    final row = await client.from(table).insert(payload).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> update(
    String table,
    Object id,
    Map<String, dynamic> values, {
    String primaryKey = 'id',
  }) async {
    final row = await client
        .from(table)
        .update(values)
        .eq(primaryKey, id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> delete(
    String table,
    Object id, {
    String primaryKey = 'id',
  }) async {
    await client.from(table).delete().eq(primaryKey, id);
  }

  Future<Object?> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => client.rpc(function, params: params);

  Future<List<Map<String, dynamic>>> lookup(
    String table, {
    String labelColumn = 'name',
    bool branchScoped = true,
    Map<String, Object?> equals = const {},
  }) => list(
    table,
    columns: 'id,$labelColumn',
    branchScoped: branchScoped,
    equals: equals,
    orderBy: labelColumn,
    limit: 500,
  );

  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> values, {
    String onConflict = 'id',
  }) async {
    final row = await client
        .from(table)
        .upsert(values, onConflict: onConflict)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> appSetting(String key) =>
      first('app_settings', branchScoped: false, equals: {'key': key});
}
