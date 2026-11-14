import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = _readCatalog('en');

  for (final locale in ['am', 'om']) {
    test('app_$locale.arb contains every English key and placeholder', () {
      final translated = _readCatalog(locale);
      final englishKeys = _messageKeys(english);

      expect(translated.keys, containsAll(englishKeys));
      for (final key in englishKeys) {
        expect(
          _placeholders(translated[key]),
          _placeholders(english[key]),
          reason: '$key placeholders differ in app_$locale.arb',
        );
      }
    });
  }
}

Map<String, dynamic> _readCatalog(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messageKeys(Map<String, dynamic> catalog) =>
    catalog.keys.where((key) => !key.startsWith('@'));

Set<String> _placeholders(Object? value) {
  if (value is! String) return const {};
  return RegExp(
    r'\{([A-Za-z_]\w*)',
  ).allMatches(value).map((match) => match[1]!).toSet();
}
