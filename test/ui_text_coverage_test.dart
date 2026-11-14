import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/l10n/ui_text.dart';

/// Technical tokens that are intentionally the same in every language.
const _allowedEnglish = {
  'afaan',
  'app',
  'id',
  'oromoo',
  'sku',
  'sms',
  'tin',
  'url',
  'kpis',
  'po',
  'txn',
  'v',
  'hr',
  'etb',
  'pdf',
  'csv',
  'pos',
  'vat',
  'yyyy',
  'mm',
  'dd',
  'hh',
};

Set<String> _schemaStrings() {
  final source = File('lib/data/schema.dart').readAsStringSync();
  final titles = RegExp(
    r"title:\s*'([^']+)'",
  ).allMatches(source).map((match) => match.group(1)!);
  final labels = RegExp(
    r"FieldSpec\(\s*'[a-z0-9_]+'\s*,\s*'([^']+)'",
  ).allMatches(source).map((match) => match.group(1)!);
  return {...titles, ...labels};
}

List<String> _untranslatedWords(String english, String translated) {
  final sourceWords = RegExp(r"[A-Za-z][A-Za-z']*")
      .allMatches(english)
      .map((match) => match.group(0)!.toLowerCase())
      .where((word) => word.length > 1)
      .where((word) => !_allowedEnglish.contains(word))
      .where((word) => !word.contains("'"));
  final lower = translated.toLowerCase();
  return sourceWords
      .where(
        (word) => RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(lower),
      )
      .toList();
}

void main() {
  test('every schema title and field label is translated', () {
    final strings = _schemaStrings();
    expect(strings.length, greaterThan(300));
    for (final code in ['am', 'om']) {
      for (final english in strings) {
        final translated = uiTextForLocale(code, english);
        expect(translated.trim(), isNotEmpty, reason: '$code: $english');
        expect(
          _untranslatedWords(english, translated),
          isEmpty,
          reason: '$code: "$english" -> "$translated"',
        );
      }
    }
  });

  test('every UI phrase is translated', () {
    for (final code in ['am', 'om']) {
      for (final english in uiTextKeys) {
        final translated = uiTextForLocale(code, english);
        expect(translated.trim(), isNotEmpty, reason: '$code: $english');
        expect(
          _untranslatedWords(english, translated),
          isEmpty,
          reason: '$code: "$english" -> "$translated"',
        );
      }
    }
  });

  test('every template is translated and keeps its placeholders', () {
    final placeholder = RegExp(r'\{[a-z]+\}');
    for (final code in ['am', 'om']) {
      for (final key in uiTemplateKeys) {
        final translated = uiTemplateForLocale(code, key);
        expect(translated, isNot(key), reason: '$code template: $key');
        final source = uiTemplateSources[key] ?? key;
        expect(
          placeholder
              .allMatches(translated)
              .map((match) => match.group(0))
              .toSet(),
          placeholder.allMatches(source).map((match) => match.group(0)).toSet(),
          reason: '$code template placeholders: $key -> $translated',
        );
      }
    }
  });
}
