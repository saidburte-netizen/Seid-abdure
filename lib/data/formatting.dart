import 'dart:convert';

import 'package:intl/intl.dart';

/// Shared formatting helpers. Money is always displayed in Ethiopian Birr and
/// numbers are parsed defensively because PostgREST may return numeric columns
/// as either `num` or `String` depending on the PostgreSQL type.
final NumberFormat _currency = NumberFormat.currency(
  locale: 'en',
  symbol: 'ETB ',
  decimalDigits: 2,
);
final NumberFormat _quantity = NumberFormat('#,##0.###', 'en');
final DateFormat _date = DateFormat('yyyy-MM-dd');
final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');
final DateFormat _time = DateFormat('HH:mm');

String formatMoney(Object? value) => _currency.format(asNum(value));

String formatQuantity(Object? value) => _quantity.format(asNum(value));

String formatDate(Object? value) {
  final parsed = asDateTime(value);
  return parsed == null ? '—' : _date.format(parsed);
}

String formatDateTime(Object? value) {
  final parsed = asDateTime(value);
  return parsed == null ? '—' : _dateTime.format(parsed);
}

String formatTime(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse('2000-01-01 $raw');
  if (parsed != null) return _time.format(parsed);
  return raw.length > 5 ? raw.substring(0, 5) : raw;
}

String dateOnly(DateTime value) => _date.format(value);

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
  final text = value == null ? '' : value.toString();
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
    buffer.writeln(ordered
        .map((column) {
          final value = row[column];
          if (value is Map || value is List) return csvEscape(jsonEncode(value));
          return csvEscape(value);
        })
        .join(','));
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

Map<String, dynamic> _flattenMap(Map<dynamic, dynamic> source, [String prefix = '']) {
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
