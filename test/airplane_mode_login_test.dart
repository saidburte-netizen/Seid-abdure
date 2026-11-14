import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';

void main() {
  testWidgets('airplane mode sign-in shows only the friendly offline message', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        throw const SocketException('Network is unreachable');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...oromoFrameworkLocalizationsDelegates,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: SignInScreen(client: client),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'cashier@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text(
        'No internet connection. Please check your network and try again.',
      ),
      findsOneWidget,
    );
    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join('\n');
    expect(visible.toLowerCase(), isNot(contains('socketexception')));
    expect(visible.toLowerCase(), isNot(contains('network is unreachable')));
    expect(visible.toLowerCase(), isNot(contains('clientexception')));
    expect(visible.toLowerCase(), isNot(contains('stack trace')));
  });
}
