import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/sign_in_gateway.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';

import 'support/fake_backend.dart';

Future<void> pumpSignIn(WidgetTester tester, SignInGateway gateway) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...oromoFrameworkLocalizationsDelegates,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: SignInScreen(gateway: gateway),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> fillCredentials(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'cashier@example.com');
  await tester.enterText(fields.at(1), 'correct horse battery');
}

void main() {
  testWidgets('shows customer sign-up when admin exists and sign-up is open', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(admin: true, signupAllowed: true);
    await pumpSignIn(tester, gateway);

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Create the first account'), findsNothing);
    expect(
      find.text('Contact the administrator to get an account.'),
      findsNothing,
    );
  });

  testWidgets('hides sign-up when the administrator closed it', (tester) async {
    final gateway = FakeSignInGateway(admin: true, signupAllowed: false);
    await pumpSignIn(tester, gateway);

    expect(find.text('Create account'), findsNothing);
    expect(find.text('Create the first account'), findsNothing);
    expect(
      find.text('Contact the administrator to get an account.'),
      findsOneWidget,
    );
  });

  testWidgets('offers first-account creation when no administrator exists', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(admin: false);
    await pumpSignIn(tester, gateway);

    expect(find.text('Create the first account'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('has_admin failure keeps the form and hides create options', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(
      adminError: const SocketException('Network is unreachable'),
    );
    await pumpSignIn(tester, gateway);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Create the first account'), findsNothing);
    expect(
      find.text(
        'No internet connection. Please check your network and try again.',
      ),
      findsOneWidget,
    );

    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join('\n')
        .toLowerCase();
    expect(visible, isNot(contains('socketexception')));
    expect(visible, isNot(contains('network is unreachable')));
  });

  testWidgets('has_admin returning nothing hides create options quietly', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(admin: null);
    await pumpSignIn(tester, gateway);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Create the first account'), findsNothing);
    expect(
      find.text('Contact the administrator to get an account.'),
      findsOneWidget,
    );
  });

  testWidgets('customer_signup_allowed failure hides the sign-up button', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(
      admin: true,
      signupError: const SocketException('Network is unreachable'),
    );
    await pumpSignIn(tester, gateway);

    expect(find.text('Create account'), findsNothing);
    expect(
      find.text('Contact the administrator to get an account.'),
      findsOneWidget,
    );
  });

  testWidgets('valid credentials call the gateway once', (tester) async {
    final gateway = FakeSignInGateway(admin: true);
    await pumpSignIn(tester, gateway);

    await fillCredentials(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(gateway.signInCalls, 1);
    expect(gateway.lastEmail, 'cashier@example.com');
    expect(gateway.lastPassword, 'correct horse battery');
  });

  testWidgets('invalid email never reaches the gateway', (tester) async {
    final gateway = FakeSignInGateway(admin: true);
    await pumpSignIn(tester, gateway);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'not-an-email');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(gateway.signInCalls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('a second tap is ignored while the first sign-in is pending', (
    tester,
  ) async {
    final completer = Completer<void>();
    final gateway = _BlockingGateway(completer);
    await pumpSignIn(tester, gateway);
    await fillCredentials(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(gateway.signInCalls, 1);

    await tester.tap(find.text('Signing in…'), warnIfMissed: false);
    await tester.pump();
    expect(gateway.signInCalls, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('failed sign-in shows a friendly message, never the raw error', (
    tester,
  ) async {
    final gateway = FakeSignInGateway(
      admin: true,
      signInError: const SocketException('Network is unreachable'),
    );
    await pumpSignIn(tester, gateway);
    await fillCredentials(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(
        'No internet connection. Please check your network and try again.',
      ),
      findsOneWidget,
    );
    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join('\n')
        .toLowerCase();
    expect(visible, isNot(contains('socketexception')));
    expect(visible, isNot(contains('network is unreachable')));
  });
}

class _BlockingGateway extends FakeSignInGateway {
  _BlockingGateway(this.gate) : super(admin: true);

  final Completer<void> gate;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    await gate.future;
  }
}
