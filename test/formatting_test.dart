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
}
