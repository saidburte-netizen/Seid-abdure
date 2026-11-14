import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';

void main() {
  testWidgets('Oromo locale can open a Material date picker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('om'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          ...oromoFrameworkLocalizationsDelegates,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Oromo date picker regression')),
            body: TextButton(
              onPressed: () {
                unawaited(
                  showDatePicker(
                    context: context,
                    initialDate: DateTime(2026),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  ),
                );
              },
              child: const Text('Open date picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open date picker'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Oromo date picker regression'), findsOneWidget);
    expect(
      Localizations.of<CupertinoLocalizations>(
        tester.element(find.byType(Scaffold)),
        CupertinoLocalizations,
      ),
      isNotNull,
    );
  });
}
