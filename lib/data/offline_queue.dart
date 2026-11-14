import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'formatting.dart';
import 'repository.dart';

class PendingSale {
  PendingSale({
    required this.clientId,
    required this.branchId,
    required this.items,
    required this.payments,
    required this.createdAt,
    this.customerId,
    this.discount = 0,
    this.notes = '',
    this.attempts = 0,
    this.lastError,
  });

  final String clientId;
  final String branchId;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;
  final String? customerId;
  final num discount;
  final String notes;
  final DateTime createdAt;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'branch_id': branchId,
        'items': items,
        'payments': payments,
        'customer_id': customerId,
        'discount': discount,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
      };

  static PendingSale fromJson(Map<String, dynamic> json) => PendingSale(
        clientId: json['client_id'] as String,
        branchId: json['branch_id'] as String,
        items: asMapList(json['items']),
        payments: asMapList(json['payments']),
        customerId: json['customer_id'] as String?,
        discount: asNum(json['discount']),
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] as String?,
      );
}

/// Durable, client-side queue for sales captured while the device is offline.
/// The server assigns the authoritative sale number and validates stock and
/// credit; the client only owns the idempotency key.
class OfflineQueue {
  OfflineQueue._(this._preferences);

  static const _storageKey = 'offline_sales_v1';
  final SharedPreferences _preferences;

  static Future<OfflineQueue> create() async =>
      OfflineQueue._(await SharedPreferences.getInstance());

  List<PendingSale> all() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => PendingSale.fromJson(asMap(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<PendingSale> forBranch(String branchId) =>
      all().where((sale) => sale.branchId == branchId).toList();

  int countForBranch(String branchId) => forBranch(branchId).length;

  Future<PendingSale> enqueue({
    required String branchId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? customerId,
    num discount = 0,
    String notes = '',
  }) async {
    final pending = PendingSale(
      clientId: const Uuid().v4(),
      branchId: branchId,
      items: items,
      payments: payments,
      customerId: customerId,
      discount: discount,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _write([...all(), pending]);
    return pending;
  }

  Future<void> remove(String clientId) async {
    await _write(all().where((sale) => sale.clientId != clientId).toList());
  }

  Future<void> updateError(String clientId, String error) async {
    final rows = all();
    for (final row in rows) {
      if (row.clientId == clientId) {
        row.attempts += 1;
        row.lastError = error;
      }
    }
    await _write(rows);
  }

  Future<OfflineSyncResult> sync(SupabaseClient client, String branchId) async {
    final pending = forBranch(branchId);
    var succeeded = 0;
    final failures = <String>[];
    for (final sale in pending) {
      try {
        await client.rpc(
          'sync_offline_sale',
          params: {
            'target_branch': branchId,
            'p_device_id': 'flutter-client',
            'p_client_id': sale.clientId,
            'p_payload': {
              'items': sale.items,
              'payments': sale.payments,
              'customer_id': sale.customerId,
              'discount': sale.discount,
              'notes': sale.notes,
              'created_at': sale.createdAt.toIso8601String(),
            },
          },
        );
        await remove(sale.clientId);
        succeeded += 1;
      } catch (error) {
        final message = readableError(error);
        await updateError(sale.clientId, message);
        failures.add(message);
      }
    }
    return OfflineSyncResult(
      succeeded: succeeded,
      failed: failures.length,
      message: failures.isEmpty ? null : failures.first,
    );
  }

  Future<void> _write(List<PendingSale> rows) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(rows.map((row) => row.toJson()).toList()),
    );
  }
}

class OfflineSyncResult {
  const OfflineSyncResult({
    required this.succeeded,
    required this.failed,
    this.message,
  });

  final int succeeded;
  final int failed;
  final String? message;
}
