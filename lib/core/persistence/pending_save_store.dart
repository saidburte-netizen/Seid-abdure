import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A save that was in progress when the process last stopped.
///
/// The payload itself is deliberately not stored: forms can contain private
/// business data and restoring half a payload is worse than asking the user to
/// re-enter it. The route lets the app return to the screen where the save was
/// attempted so the user sees a clear "not saved" message in context.
class PendingSave {
  const PendingSave({
    required this.route,
    required this.module,
    required this.target,
    required this.startedAt,
  });

  final String route;
  final String module;
  final String target;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
    'route': route,
    'module': module,
    'target': target,
    'startedAt': startedAt.toIso8601String(),
  };

  static PendingSave? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final startedAt = DateTime.tryParse(raw['startedAt']?.toString() ?? '');
    if (startedAt == null) return null;
    return PendingSave(
      route: raw['route']?.toString() ?? '/',
      module: raw['module']?.toString() ?? '',
      target: raw['target']?.toString() ?? '',
      startedAt: startedAt,
    );
  }
}

/// Persists the fact that a save started, so a process death cannot silently
/// lose both the dialog and the explanation.
class PendingSaveStore {
  PendingSaveStore._();

  static final PendingSaveStore instance = PendingSaveStore._();

  static const String _storageKey = 'brade_pending_save_v1';

  Future<void> begin({
    required String route,
    required String module,
    required String target,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(
          PendingSave(
            route: route,
            module: module,
            target: target,
            startedAt: DateTime.now(),
          ).toJson(),
        ),
      );
    } catch (_) {
      // A storage failure must not stop the save attempt.
    }
  }

  Future<PendingSave?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      return PendingSave.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<PendingSave?> take() async {
    final pending = await read();
    if (pending != null) await clear();
    return pending;
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Ignore.
    }
  }
}
