import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'error_log.dart';

/// One breadcrumb from a save attempt.
///
/// Breadcrumbs are deliberately small and technical. They are only shown on
/// the administrator diagnostics screen, never to normal users.
class SaveTraceEntry {
  const SaveTraceEntry({
    required this.time,
    required this.module,
    required this.target,
    required this.step,
    this.detail,
  });

  final DateTime time;
  final String module;
  final String target;
  final String step;
  final String? detail;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'module': module,
    'target': target,
    'step': step,
    if (detail != null) 'detail': detail,
  };

  static SaveTraceEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final time = DateTime.tryParse(raw['time']?.toString() ?? '');
    if (time == null) return null;
    return SaveTraceEntry(
      time: time,
      module: raw['module']?.toString() ?? '',
      target: raw['target']?.toString() ?? '',
      step: raw['step']?.toString() ?? '',
      detail: raw['detail']?.toString(),
    );
  }
}

/// A single save attempt. Marking steps is intentionally synchronous so a
/// trace can never be the reason a save waits.
class SaveTraceToken {
  SaveTraceToken._({
    required this.module,
    required this.target,
    required this.startedAt,
  });

  final String module;
  final String target;
  final DateTime startedAt;

  void mark(String step, {String? detail}) {
    SaveTrace.instance.mark(
      module: module,
      target: target,
      step: step,
      detail: detail,
    );
  }

  void fail(Object error) {
    mark('failed', detail: error.runtimeType.toString());
  }
}

/// Keeps the last [maxEntries] save breadcrumbs, including across a process
/// restart. If Android kills the app while a save is stuck, the next launch
/// still shows exactly how far the save got.
class SaveTrace {
  SaveTrace._();

  static final SaveTrace instance = SaveTrace._();

  static const int maxEntries = 120;
  static const String _storageKey = 'brade_save_trace_v1';

  final List<SaveTraceEntry> _entries = [];
  bool _loaded = false;
  Future<void>? _loading;

  List<SaveTraceEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries
            ..clear()
            ..addAll(
              decoded
                  .map(SaveTraceEntry.fromJson)
                  .whereType<SaveTraceEntry>()
                  .take(maxEntries),
            );
        }
      }
    } catch (_) {
      // Diagnostics must never break the app.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  SaveTraceToken begin({required String module, required String target}) {
    final token = SaveTraceToken._(
      module: module,
      target: target,
      startedAt: DateTime.now(),
    );
    mark(module: module, target: target, step: 'started');
    return token;
  }

  void mark({
    required String module,
    required String target,
    required String step,
    String? detail,
  }) {
    final entry = SaveTraceEntry(
      time: DateTime.now(),
      module: module,
      target: target,
      step: step,
      detail: detail == null ? null : redactSecrets(detail),
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    unawaited(_persist());
  }

  Future<void> clear() async {
    _entries.clear();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode([for (final entry in _entries) entry.toJson()]),
      );
    } catch (_) {
      // Ignore storage failures; the in-memory trace is still useful.
    }
  }

  String exportText() {
    if (_entries.isEmpty) return 'No save breadcrumbs recorded.';
    final buffer = StringBuffer();
    for (final entry in _entries) {
      buffer.writeln(
        '${entry.time.toIso8601String()} | ${entry.module} | '
        '${entry.target} | ${entry.step}'
        '${entry.detail == null ? '' : ' | ${entry.detail}'}',
      );
    }
    return buffer.toString();
  }
}
