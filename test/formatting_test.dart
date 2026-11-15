import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/data/formatting.dart';

void main() {
  setUpAll(initializeFormattingData);

  test('dates, quantities and ETB currency format in each app locale', () {
    final date = DateTime(2026, 11, 14, 9, 25);
    for (final locale in formattingLocales) {
      expect(formatDate(date, locale: locale), isNotEmpty, reason: locale);
      expect(formatDateTime(date, locale: locale), isNotEmpty, reason: locale);
      expect(
        formatQuantity(1234.5, locale: locale),
        isNotEmpty,
        reason: locale,
      );
      expect(
        formatMoney(1234.5, locale: locale),
        contains('ETB'),
        reason: locale,
      );
    }

    expect(formattingLocale('om'), 'en');
  });

  test('CSV export neutralises formula injection', () {
    expect(csvEscape('=1+1'), "'=1+1");
    expect(csvEscape('+SUM(A1:A2)'), "'+SUM(A1:A2)");
    expect(csvEscape('-2+3'), "'-2+3");
    expect(csvEscape('@cmd'), "'@cmd");
    expect(csvEscape('\t=1+1'), "\"'\t=1+1\"");
    expect(csvEscape('normal text'), 'normal text');
    expect(csvEscape(42), '42');
  });
}
