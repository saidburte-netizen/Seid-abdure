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

/* Simple redaction: replace known secret prefixes with <redacted>.
   Called from showFriendlyError only. */
String redactSecrets(String input) {
  if (input.isEmpty) return input;
  // Redact JWT tokens
  input = input.replaceAll(_jwtPattern, '<redacted-jwt>');
  // Redact sb_secret_ and sb_publishable_ keys
  input = input.replaceAll(_secretKeyPattern, '<redacted-key>');
  // Reduce any remaining api key patterns
  input = input.replaceAll('api_key=', 'api_key=<redacted>');
  input = input.replaceAll('API_KEY=', 'API_KEY=<redacted>');
  // Reduce any remaining access token patterns
  input = input.replaceAll('access_token=', 'access_token=<redacted>');
  input = input.replaceAll('ACCESS_TOKEN=', 'ACCESS_TOKEN=<redacted>');
  // Reduce any remaining refresh token patterns
  input = input.replaceAll('refresh_token=', 'refresh_token=<redacted>');
  input = input.replaceAll('REFRESH_TOKEN=', 'REFRESH_TOKEN=<redacted>');
  // Reduce any remaining authorization patterns
  input = input.replaceAll('authorization=', 'authorization=<redacted>');
  input = input.replaceAll('AUTHORIZATION=', 'AUTHORIZATION=<redacted>');
  // Reduce any remaining password patterns
  input = input.replaceAll('password=', 'password=<redacted>');
  input = input.replaceAll('PASSWORD=', 'PASSWORD=<redacted>');
  // Reduce any remaining secret patterns
  input = input.replaceAll('secret=', 'secret=<redacted>');
  input = input.replaceAll('SECRET=', 'SECRET=<redacted>');
  return input;
}
