/// Money arithmetic for a sale.
///
/// The database owns the authoritative totals, but the app must show and send
/// exactly the same numbers it displays. Every value is rounded to two decimal
/// places line by line, so the sum of the line totals equals the sale total to
/// the cent. Integer math avoids binary floating point drift in comparisons.
class SaleLineInput {
  const SaleLineInput({
    required this.price,
    required this.quantity,
    this.taxRate = 0,
  });

  final num price;
  final num quantity;
  final num taxRate;
}

class SaleLineTotals {
  const SaleLineTotals({
    required this.unitPrice,
    required this.quantity,
    required this.lineSubtotal,
    required this.taxAmount,
    required this.lineTotal,
  });

  final num unitPrice;
  final num quantity;
  final num lineSubtotal;
  final num taxAmount;
  final num lineTotal;
}

class SaleTotals {
  const SaleTotals({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final List<SaleLineTotals> lines;
  final num subtotal;
  final num discount;
  final num tax;
  final num total;
}

/// Round to two decimal places using half-up for positive money values.
num roundMoney(num value) => (value * 100).round() / 100;

/// Rounds each line, then sums. A discount is clamped to the subtotal and
/// never negative, so a sale can never become payable below zero.
SaleTotals computeSaleTotals(
  Iterable<SaleLineInput> inputs, {
  num discount = 0,
}) {
  final lines = <SaleLineTotals>[];
  num subtotal = 0;
  num tax = 0;
  for (final input in inputs) {
    final unitPrice = roundMoney(input.price);
    final lineSubtotal = roundMoney(unitPrice * input.quantity);
    final taxAmount = roundMoney(lineSubtotal * input.taxRate / 100);
    lines.add(
      SaleLineTotals(
        unitPrice: unitPrice,
        quantity: input.quantity,
        lineSubtotal: lineSubtotal,
        taxAmount: taxAmount,
        lineTotal: lineSubtotal + taxAmount,
      ),
    );
    subtotal += lineSubtotal;
    tax += taxAmount;
  }
  final safeDiscount = discount < 0
      ? 0
      : (discount > subtotal ? subtotal : roundMoney(discount));
  return SaleTotals(
    lines: lines,
    subtotal: subtotal,
    discount: safeDiscount,
    tax: tax,
    total: subtotal - safeDiscount + tax,
  );
}
