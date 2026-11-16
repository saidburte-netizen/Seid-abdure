import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class SaveBreadcrumb {
  const SaveBreadcrumb({
    required this.attemptId,
    required this.time,
    required this.module,
    required this.target,
    required this.step,
  });

  final String attemptId;
  final DateTime time;
  final String module;
  final String target;
  final String step;

  Map<String, Object?> toJson() => {
    'attemptId': attemptId,
    'time': time.toIso8601String(),
    'module': module,
    'target': target,
    'step': step,
  };

  static SaveBreadcrumb? fromJson(Object? value) {
    if (value is! Map) return null;
    final time = DateTime.tryParse(value['time']?.toString() ?? '');
    if (time == null) return null;
    return SaveBreadcrumb(
      attemptId: value['attemptId']?.toString() ?? '',
      time: time,
      module: value['module']?.toString() ?? '',
      target: value['target']?.toString() ?? '',
      step: value['step']?.toString() ?? '',
    );
  }
}

class SaveDiagnostics extends ChangeNotifier {
  SaveDiagnostics._();

  static final SaveDiagnostics instance = SaveDiagnostics._();
  static const _storageKey = 'brade_save_breadcrumbs_v1';
  static const _maxEntries = 160;
  static const _pendingSteps = {
    'validated',
    'session ok',
    'request sent',
    'response received',
  };

  final List<SaveBreadcrumb> _entries = [];
  Future<void> _persistTail = Future<void>.value();
  Future<void>? _loading;
  bool _loaded = false;
  int _nextId = 0;

  List<SaveBreadcrumb> get entries => List.unmodifiable(_entries);

  SaveBreadcrumb? get pendingRecovery {
    return _pendingRecoveryFor(null);
  }

  SaveBreadcrumb? pendingRecoveryFor(String target) {
    return _pendingRecoveryFor(target);
  }

  SaveBreadcrumb? _pendingRecoveryFor(String? target) {
    final seen = <String>{};
    for (final entry in _entries) {
      if (!seen.add(entry.attemptId)) continue;
      if (target != null && entry.target != target) continue;
      return _pendingSteps.contains(entry.step) ? entry : null;
    }
    return null;
  }

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries
            ..clear()
            ..addAll(
              decoded
                  .map(SaveBreadcrumb.fromJson)
                  .whereType<SaveBreadcrumb>()
                  .take(_maxEntries),
            );
        }
      }
    } catch (error, stack) {
      AppLogger.error('Could not load save diagnostics', error, stack);
    } finally {
      _loaded = true;
      _loading = null;
      notifyListeners();
    }
  }

  String begin({required String module, required String target}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    record(attemptId: id, module: module, target: target, step: 'validated');
    return id;
  }

  void record({
    required String attemptId,
    required String module,
    required String target,
    required String step,
  }) {
    _entries.add(
      SaveBreadcrumb(
        attemptId: attemptId,
        time: DateTime.now(),
        module: module,
        target: target,
        step: step,
      ),
    );
    _entries.sort((a, b) => b.time.compareTo(a.time));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
    _queuePersist();
  }

  void _queuePersist() {
    _persistTail = _persistTail.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _storageKey,
          jsonEncode([for (final entry in _entries) entry.toJson()]),
        );
      } catch (error, stack) {
        AppLogger.error('Could not save save diagnostics', error, stack);
      }
    });
  }

  @visibleForTesting
  Future<void> flush() => _persistTail;

  @visibleForTesting
  void resetForTesting() {
    _entries.clear();
    _loaded = false;
    _loading = null;
    _nextId = 0;
  }
}
