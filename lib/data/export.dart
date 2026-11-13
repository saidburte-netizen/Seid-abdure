import 'dart:io';

import 'package:flutter/foundation.dart';

/// Writes a CSV to the device's temporary directory. On web, callers should
/// copy the CSV to the clipboard instead because the browser has no file path.
Future<String?> saveCsvFile(String name, String content) async {
  if (kIsWeb) return null;
  final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '')
      .replaceAll('-', '');
  final file = File('${Directory.systemTemp.path}/${safe}_$stamp.csv');
  await file.writeAsString(content);
  return file.path;
}
