import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/data/formatting.dart';
import 'package:brade_and_cake_house/data/sale_math.dart';

void main() {
  setUpAll(initializeFormattingData);

  test('rounds to two decimals without binary drift', () {
    expect(roundMoney(59.97000000000001), 59.97);
    expect(roundMoney(0.49000000000000005), 0.49);
    expect(roundMoney(12.5), 12.5);
    expect(roundMoney(0.125), 0.13);
    expect(roundMoney(0), 0);
  });

  test('multiplies repeating unit prices without cents drift', () {
    final cases = <(num, num, num)>[
      (19.99, 3, 59.97),
      (0.07, 7, 0.49),
      (33.33, 3, 99.99),
      (19.99, 999, 19970.01),
      (0.01, 1000, 10.00),
    ];
    for (final (price, quantity, expected) in cases) {
      final totals = computeSaleTotals([
        SaleLineInput(price: price, quantity: quantity),
      ]);
      expect(totals.subtotal, expected, reason: '$price x $quantity');
      expect(totals.total, expected, reason: '$price x $quantity');
    }
  });

  test('rounds tax per line and keeps line totals consistent', () {
    final totals = computeSaleTotals([
      const SaleLineInput(price: 12.35, quantity: 2, taxRate: 15),
      const SaleLineInput(price: 4.99, quantity: 3),
    ]);

    expect(totals.lines[0].lineSubtotal, 24.70);
    expect(totals.lines[0].taxAmount, 3.71);
    expect(totals.lines[0].lineTotal, 28.41);
    expect(totals.lines[1].lineSubtotal, 14.97);
    expect(totals.lines[1].taxAmount, 0);
    expect(totals.subtotal, 39.67);
    expect(totals.tax, 3.71);
    expect(totals.total, 43.38);

    final sumOfLines = totals.lines.fold<num>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    expect(sumOfLines, totals.total);
  });

  test('line totals always add up to the sale total', () {
    final totals = computeSaleTotals([
      const SaleLineInput(price: 3.33, quantity: 3, taxRate: 7.5),
      const SaleLineInput(price: 0.99, quantity: 7, taxRate: 15),
      const SaleLineInput(price: 125.5, quantity: 1, taxRate: 0),
      const SaleLineInput(price: 45.67, quantity: 2, taxRate: 10),
    ]);
    final sumOfLines = totals.lines.fold<num>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    expect(sumOfLines, totals.total);
    expect(totals.total, totals.subtotal + totals.tax);
  });

  test('fractional quantities keep exact cents', () {
    final totals = computeSaleTotals([
      const SaleLineInput(price: 100, quantity: 0.5, taxRate: 15),
    ]);
    expect(totals.subtotal, 50);
    expect(totals.tax, 7.5);
    expect(totals.total, 57.5);
  });

  test('discount is clamped and never makes a sale negative', () {
    final order = [const SaleLineInput(price: 19.99, quantity: 2)];

    expect(computeSaleTotals(order, discount: 5).total, 34.98);
    expect(computeSaleTotals(order, discount: -10).discount, 0);
    expect(computeSaleTotals(order, discount: 999).discount, 39.98);
    expect(computeSaleTotals(order, discount: 999).total, 0);
    expect(computeSaleTotals(order, discount: 0.125).discount, 0.13);
  });

  test('empty cart totals zero and never throws', () {
    final totals = computeSaleTotals(const []);
    expect(totals.lines, isEmpty);
    expect(totals.subtotal, 0);
    expect(totals.tax, 0);
    expect(totals.total, 0);
  });

  test('ETB totals display with two decimals in en, am and om', () {
    final totals = computeSaleTotals([
      const SaleLineInput(price: 1234.5, quantity: 1),
    ]);
    for (final locale in formattingLocales) {
      final text = formatMoney(totals.total, locale: locale);
      expect(text, contains('ETB'), reason: locale);
      expect(text, contains('1,234.50'), reason: locale);
    }
  });

  test('the POS write path uses integer-safe math, not double arithmetic', () {
    final source = File('lib/screens/pos_screen.dart').readAsStringSync();
    expect(source, contains('computeSaleTotals('));
    expect(source, contains('totals.lines'));
    expect(source, isNot(contains('double ')));
    expect(source, isNot(contains('toStringAsFixed(4)')));
  });
}
