import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One technical error as shown on Settings > About > Diagnostics.
///
/// This is the only place where technical details are exposed, and the screen
/// is restricted to administrators. Tokens and keys are redacted before an
/// entry is stored.
class ErrorLogEntry {
  const ErrorLogEntry({
    required this.time,
    required this.module,
    required this.target,
    required this.code,
    required this.message,
  });

  final DateTime time;
  final String module;
  final String target;
  final String code;
  final String message;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'module': module,
    'target': target,
    'code': code,
    'message': message,
  };

  static ErrorLogEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final time = DateTime.tryParse(raw['time']?.toString() ?? '');
    if (time == null) return null;
    return ErrorLogEntry(
      time: time,
      module: raw['module']?.toString() ?? '',
      target: raw['target']?.toString() ?? '',
      code: raw['code']?.toString() ?? '',
      message: raw['message']?.toString() ?? '',
    );
  }
}

/// Keeps the last 20 technical errors for the administrator diagnostics screen.
class ErrorLog {
  ErrorLog._();

  static final ErrorLog instance = ErrorLog._();

  static const int maxEntries = 20;
  static const String _storageKey = 'brade_diagnostics_errors_v1';

  final List<ErrorLogEntry> _entries = [];
  bool _loaded = false;
  Future<void>? _loading;

  List<ErrorLogEntry> get entries => List.unmodifiable(_entries);

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
                  .map(ErrorLogEntry.fromJson)
                  .whereType<ErrorLogEntry>()
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

  void record({
    required String module,
    required String target,
    required Object error,
  }) {
    final code = _codeOf(error);
    final message = _messageOf(error);
    final entry = ErrorLogEntry(
      time: DateTime.now(),
      module: module,
      target: target,
      code: code,
      message: redactSecrets(message),
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
      // Ignore storage failures; the in-memory log is still useful.
    }
  }

  String exportText() {
    if (_entries.isEmpty) return 'No technical errors recorded.';
    final buffer = StringBuffer();
    for (final entry in _entries) {
      buffer.writeln(
        '${entry.time.toIso8601String()} | ${entry.module} | '
        '${entry.target} | ${entry.code} | ${entry.message}',
      );
    }
    return buffer.toString();
  }

  static String _codeOf(Object error) {
    if (error is PostgrestException) return error.code ?? '';
    if (error is AuthException) return error.statusCode ?? '';
    return '';
  }

  static String _messageOf(Object error) {
    if (error is PostgrestException) {
      final details = error.details?.toString().trim() ?? '';
      final hint = error.hint?.toString().trim() ?? '';
      return [
        error.message,
        if (details.isNotEmpty) details,
        if (hint.isNotEmpty) hint,
      ].join(' — ');
    }
    if (error is AuthException) return error.message;
    return error.toString();
  }
}

final RegExp _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
);
final RegExp _secretKeyPattern = RegExp(
  r'sb_(?:secret|publishable)_[A-Za-z0-9_-]+',
);
final RegExp _namedSecretPattern = RegExp(
  r'(?i)(apikey|access_token|refresh_token|authorization|password|secret)'
  r'(\s*[=:]\s*)([^\s,;&]+)',
);

/// Removes credentials from any text that reaches the diagnostics screen.
String redactSecrets(String input) {
  if (input.isEmpty) return input;
  return input
      .replaceAll(_jwtPattern, '<redacted-jwt>')
      .replaceAll(_secretKeyPattern, '<redacted-key>')
      .replaceAllMapped(
        _namedSecretPattern,
        (match) => '${match.group(1)}${match.group(2)}<redacted>',
      );
}
