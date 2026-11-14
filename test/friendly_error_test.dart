// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/core/errors/error_ui.dart';
import 'package:brade_and_cake_house/core/errors/friendly_error.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';

void main() {
  group('friendlyMessage', () {
    test('network and DNS failures become the offline message', () {
      final error = SocketException(
        'Failed host lookup: nmrpmypgkljmtnsvmcfn.supabase.co',
      );
      expect(
        friendlyMessage(error),
        'No internet connection. Please check your network and try again.',
      );
      expect(friendlyMessage(error), isNot(contains('SocketException')));
      expect(friendlyMessage(error), isNot(contains('nmrpmypgkljmtnsvmcfn')));
    });

    test('timeouts become the offline message', () {
      expect(
        friendlyMessage(TimeoutException('Future not completed')),
        'No internet connection. Please check your network and try again.',
      );
    });

    test('HTTP client failures become the offline message', () {
      expect(
        friendlyMessage(
          http.ClientException(
            'Connection closed before full header was received',
          ),
        ),
        'No internet connection. Please check your network and try again.',
      );
    });

    test('invalid credentials are mapped politely', () {
      final error = AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      expect(friendlyMessage(error), 'Incorrect email or password.');
      expect(friendlyMessage(error), isNot(contains('AuthException')));
    });

    test('already-registered email is mapped politely', () {
      final error = AuthException(
        'User already registered',
        statusCode: '400',
        code: 'user_already_exists',
      );
      expect(
        friendlyMessage(error),
        'This email is already registered. Try signing in.',
      );
    });

    test('weak password is mapped politely', () {
      final error = AuthException(
        'Password should be at least 8 characters',
        statusCode: '400',
      );
      expect(friendlyMessage(error), 'Password must be at least 8 characters.');
    });

    test('RLS and permission errors never expose SQL or table names', () {
      final error = PostgrestException(
        message: 'permission denied for table sales',
        code: '42501',
      );
      expect(friendlyMessage(error), 'You do not have permission to do this.');
      expect(friendlyMessage(error), isNot(contains('sales')));
      expect(friendlyMessage(error), isNot(contains('42501')));
    });

    test('server errors become a temporary-unavailable message', () {
      final error = PostgrestException(
        message: 'upstream request timeout',
        code: 'PGRST',
      );
      expect(
        friendlyMessage(error),
        'Service is temporarily unavailable. Please try again in a moment.',
      );
    });

    test('unknown failures use a safe generic message', () {
      final error = FormatException(
        'Unexpected token in table products at nmrpmypgkljmtnsvmcfn.supabase.co',
      );
      expect(friendlyMessage(error), 'Something went wrong. Please try again.');
      expect(friendlyMessage(error), isNot(contains('products')));
      expect(friendlyMessage(error), isNot(contains('nmrpmypgkljmtnsvmcfn')));
    });
  });

  group('the friendly error widget never renders raw technical text', () {
    final cases = <({String name, Object error, List<String> raw})>[
      (
        name: 'SocketException',
        error: SocketException(
          'Failed host lookup: nmrpmypgkljmtnsvmcfn.supabase.co',
        ),
        raw: const [
          'SocketException',
          'Failed host lookup',
          'nmrpmypgkljmtnsvmcfn',
          'supabase.co',
        ],
      ),
      (
        name: 'TimeoutException',
        error: TimeoutException('Future not completed'),
        raw: const ['TimeoutException', 'Future not completed'],
      ),
      (
        name: 'AuthException',
        error: AuthException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
        raw: const ['AuthException', 'Invalid login credentials'],
      ),
      (
        name: 'PostgrestException',
        error: PostgrestException(
          message: 'relation "sales" does not exist',
          code: '42P01',
          hint: 'Perhaps you meant to reference the table "public.sales".',
        ),
        raw: const [
          'PostgrestException',
          'relation',
          'sales',
          '42P01',
          'public.sales',
        ],
      ),
    ];

    for (final item in cases) {
      testWidgets('${item.name} shows only a friendly message', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FriendlyErrorBox(error: item.error)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(friendlyMessage(item.error)), findsOneWidget);
        for (final raw in item.raw) {
          expect(find.textContaining(raw), findsNothing);
        }
      });
    }
  });
}
