import 'package:supabase_flutter/supabase_flutter.dart';

export '../core/errors/friendly_error.dart';

/// A thin, branch-scoped data access layer.
///
/// Every write that changes money, stock or credit must use a database RPC.
/// This repository is for ordinary master data and read models only.
class BranchRepository {
  BranchRepository(this.client, this.branchId);

  final SupabaseClient client;
  final String branchId;

  Future<List<Map<String, dynamic>>> list(
    String table, {
    String columns = '*',
    String? orderBy,
    bool ascending = true,
    bool branchScoped = true,
    Map<String, Object?> equals = const {},
    int limit = 500,
  }) async {
    dynamic query = client.from(table).select(columns);
    if (branchScoped && branchId.isNotEmpty) {
      query = query.eq('branch_id', branchId);
    }
    for (final entry in equals.entries) {
      query = query.eq(entry.key, entry.value);
    }
    if (orderBy != null) query = query.order(orderBy, ascending: ascending);
    query = query.limit(limit);
    final rows = await query;
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
