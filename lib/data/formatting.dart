import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

const formattingLocales = ['en', 'am', 'om'];

final Map<String, NumberFormat> _currencyFormats = {};
final Map<String, NumberFormat> _quantityFormats = {};
final Map<String, DateFormat> _dateFormats = {};
final Map<String, DateFormat> _dateTimeFormats = {};
final Map<String, DateFormat> _timeFormats = {};

Future<void> initializeFormattingData() async {
  for (final locale in formattingLocales) {
    await initializeDateFormatting(locale);
  }
}

String formattingLocale(String? languageCode) => switch (languageCode) {
      'om' => 'en',
      'am' => 'am',
      _ => 'en',
    };

/// Shared formatting helpers. Money is always displayed in Ethiopian Birr and
/// numbers are parsed defensively because PostgREST may return numeric columns
/// as either `num` or `String` depending on the PostgreSQL type.
String formatMoney(Object? value, {String? locale}) {
  final language = formattingLocale(locale);
  final format = _currencyFormats.putIfAbsent(
    language,
    () => NumberFormat.currency(
      locale: language,
      symbol: 'ETB ',
      decimalDigits: 2,
    ),
  );
  return format.format(asNum(value));
}

String formatQuantity(Object? value, {String? locale}) {
  final language = formattingLocale(locale);
  final format = _quantityFormats.putIfAbsent(
    language,
    () => NumberFormat('#,##0.###', language),
  );
  return format.format(asNum(value));
}

String formatDate(Object? value, {String? locale}) {
  final parsed = asDateTime(value);
  if (parsed == null) return '—';
  final language = formattingLocale(locale);
  final format = _dateFormats.putIfAbsent(
    language,
    () => DateFormat('yyyy-MM-dd', language),
  );
  return format.format(parsed);
}

String formatDateTime(Object? value, {String? locale}) {
  final parsed = asDateTime(value);
  if (parsed == null) return '—';
  final language = formattingLocale(locale);
  final format = _dateTimeFormats.putIfAbsent(
    language,
    () => DateFormat('yyyy-MM-dd HH:mm', language),
  );
  return format.format(parsed);
}

String formatTime(Object? value, {String? locale}) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse('2000-01-01 $raw');
  if (parsed != null) {
    final language = formattingLocale(locale);
    final format = _timeFormats.putIfAbsent(
      language,
      () => DateFormat('HH:mm', language),
    );
    return format.format(parsed);
  }
  return raw.length > 5 ? raw.substring(0, 5) : raw;
}

String dateOnly(DateTime value, {String? locale}) {
  final language = formattingLocale(locale);
  final format = _dateFormats.putIfAbsent(
    language,
    () => DateFormat('yyyy-MM-dd', language),
  );
  return format.format(value);
}

String nowIso() => DateTime.now().toUtc().toIso8601String();

num asNum(Object? value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString().replaceAll(',', '')) ?? 0;
}

String asText(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is bool) return value ? 'Yes' : 'No';
  return value.toString();
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == 'true' || text == 't' || text == '1' || text == 'yes';
}

DateTime? asDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is List) return value.map(asMap).toList();
  return const [];
}

String prettyLabel(String key) => key
    .replaceAll('_', ' ')
    .replaceAll('.', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

String csvEscape(Object? value) {
  var text = value == null ? '' : value.toString();
  // Prevent CSV formula injection in Excel and similar spreadsheet apps.
  if (value is String &&
      text.isNotEmpty &&
      const ['=', '+', '-', '@', '\t', '\r'].contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String rowsToCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final columns = <String>{};
  for (final row in rows) {
    columns.addAll(row.keys);
  }
  final ordered = columns.toList()..sort();
  final buffer = StringBuffer()..writeln(ordered.map(csvEscape).join(','));
  for (final row in rows) {
    buffer.writeln(
      ordered.map((column) {
        final value = row[column];
        if (value is Map || value is List) {
          return csvEscape(jsonEncode(value));
        }
        return csvEscape(value);
      }).join(','),
    );
  }
  return buffer.toString();
}

/// Flattens nested report JSON into display rows. Lists of objects become
/// multiple rows, primitives become label/value pairs.
List<Map<String, dynamic>> flattenReport(Object? value) {
  if (value is List) {
    return value.map((item) {
      if (item is Map) return _flattenMap(item);
      return <String, dynamic>{'value': item};
    }).toList();
  }
  if (value is Map) {
    final map = _flattenMap(value);
    return [
      for (final entry in map.entries)
        {'metric': prettyLabel(entry.key), 'value': entry.value},
    ];
  }
  return [
    {'value': value},
  ];
}

Map<String, dynamic> _flattenMap(
  Map<dynamic, dynamic> source, [
  String prefix = '',
]) {
  final result = <String, dynamic>{};
  for (final entry in source.entries) {
    final key = prefix.isEmpty ? entry.key.toString() : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map) {
      result.addAll(_flattenMap(value, key));
    } else if (value is List) {
      result[key] = value.length;
    } else {
      result[key] = value;
    }
  }
  return result;
}
