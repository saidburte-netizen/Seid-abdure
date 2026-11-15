import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/auth/void_sale_access.dart';

void main() {
  test('only roles allowed by void_sale can see the action', () {
    for (final role in ['admin', 'manager', 'accountant', 'cashier']) {
      expect(canVoidSale(role), isTrue, reason: role);
    }
    for (final role in [
      'baker',
      'store_keeper',
      'hr_officer',
      'staff',
      'customer',
      null,
    ]) {
      expect(canVoidSale(role), isFalse, reason: '$role');
    }
  });

  test('every void_sale failure maps to a friendly category', () {
    expect(
      classifyVoidSaleFailure(Exception('Sale not found.')),
      VoidSaleFailure.notFound,
    );
    expect(
      classifyVoidSaleFailure(
        Exception(
          'PostgrestException(message: This sale has already been voided.)',
        ),
      ),
      VoidSaleFailure.alreadyVoided,
    );
    expect(
      classifyVoidSaleFailure(Exception('Only completed sales can be voided.')),
      VoidSaleFailure.onlyCompleted,
    );
    expect(
      classifyVoidSaleFailure(
        Exception('This sale already has returns and cannot be voided.'),
      ),
      VoidSaleFailure.hasReturns,
    );
    expect(
      classifyVoidSaleFailure(
        Exception('You do not have permission to void sales.'),
      ),
      VoidSaleFailure.permissionDenied,
    );
    expect(
      classifyVoidSaleFailure(Exception('Network is unreachable')),
      VoidSaleFailure.unknown,
    );
  });
}
