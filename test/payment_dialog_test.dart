import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/widgets/payment_dialog.dart';

void main() {
  testWidgets('keeps a fractional payment open until its save completes', (
    tester,
  ) async {
    final pendingSave = Completer<void>();
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => PaymentDialog(
                  title: 'Record payment',
                  accounts: const [
                    {'id': 'cash-1', 'name': 'Cash'},
                  ],
                  maximum: 3,
                  onSave: (payment) {
                    submitted = payment;
                    return pendingSave.future;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0.25');
    await tester.tap(find.text('Record payment'));
    await tester.pump();

    expect(submitted?['amount'], 0.25);
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(PaymentDialog), findsOneWidget);

    pendingSave.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PaymentDialog), findsNothing);
  });

  testWidgets('rejects a payment greater than its outstanding balance', (
    tester,
  ) async {
    var saveCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (context) => PaymentDialog(
                  title: 'Record payment',
                  accounts: const [
                    {'id': 'cash-1', 'name': 'Cash'},
                  ],
                  maximum: 3,
                  onSave: (_) async {
                    saveCalled = true;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3.01');
    await tester.tap(find.text('Record payment'));
    await tester.pump();

    expect(saveCalled, isFalse);
    expect(find.text('Amount cannot exceed ETB 3.00.'), findsOneWidget);
    expect(find.byType(PaymentDialog), findsOneWidget);
  });
}
