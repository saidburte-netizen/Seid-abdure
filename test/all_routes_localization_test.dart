import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/core/locale/locale_preferences.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';

import 'support/fake_backend.dart';

const _routes = [
  '/',
  '/pos',
  '/sales',
  '/production',
  '/inventory',
  '/cash',
  '/people',
  '/payroll',
  '/rentals',
  '/credit',
  '/approvals',
  '/reports',
  '/notifications',
  '/settings',
  '/settings/profile',
  '/settings/security',
  '/settings/business',
  '/settings/branches',
  '/settings/accounts',
  '/settings/users',
  '/settings/role-permissions',
  '/settings/master-data',
  '/settings/audit',
  '/settings/export',
  '/settings/storage',
  '/settings/branding',
  '/settings/about',
  '/settings/help',
  '/settings/privacy',
  '/module/production',
  '/module/sales',
  '/module/pos',
  '/module/inventory',
  '/module/cash',
  '/module/people',
  '/module/payroll',
  '/module/rentals',
  '/module/credit',
  '/module/approvals',
  '/module/reports',
  '/module/notifications',
  '/module/settings',
  '/module/audit',
  '/module/media',
  '/module/unknown',
  '/sign-in',
  '/loading',
  '/profile-missing',
  '/branch-setup',
  '/access-denied',
  '/auth-error',
];

void main() {
  testWidgets('pending locale recovery restores English and notifies', (
    tester,
  ) async {
    final controller = await _createTestController(
      tester,
      preferences: {'locale': 'om', localeRecoveryPreferenceKey: true},
    );
    final preferences = await SharedPreferences.getInstance();

    expect(controller.locale?.languageCode, 'en');
    expect(controller.localeResetNotice, isTrue);
    expect(preferences.getString('locale'), 'en');
    expect(preferences.getBool(localeRecoveryPreferenceKey), isNull);

    _setPortal(controller, 'admin');
    await tester.pumpWidget(
      BakeryApp(
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('We switched back to English.'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('all portal routes build for en, am and om', (tester) async {
    final controller = await _createTestController(tester);
    final gateway = FakeSignInGateway(admin: true, signupAllowed: true);

    for (final locale in ['en', 'am', 'om']) {
      controller.locale = Locale(locale);
      _setPortal(controller, 'admin');
      for (final route in _routes) {
        await tester.pumpWidget(
          BakeryApp(
            key: ValueKey('$locale:$route'),
            client: controller.client,
            authController: controller,
            signInGateway: gateway,
            initialLocation: route,
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale, route=$route',
        );
      }
    }

    for (final locale in ['en', 'am', 'om']) {
      for (final role in ['admin', 'manager', 'staff']) {
        controller.locale = Locale(locale);
        _setPortal(controller, role);
        await tester.pumpWidget(
          BakeryApp(
            key: ValueKey('$locale:$role'),
            client: controller.client,
            authController: controller,
            signInGateway: gateway,
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale, dashboard portal=$role',
        );
      }
    }

    controller.dispose();
  });

  testWidgets('live language changes work in every direction', (tester) async {
    final controller = await _createTestController(tester);
    controller.locale = const Locale('en');

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...oromoFrameworkLocalizationsDelegates,
            ...AppLocalizations.localizationsDelegates,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context).language),
              ),
              body: const TextField(),
            ),
          ),
        ),
      ),
    );

    for (final locale in ['am', 'om', 'en', 'am', 'om']) {
      await controller.setLocale(locale);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'locale=$locale');
      expect(controller.locale?.languageCode, locale);
    }

    controller.dispose();
  });

  testWidgets('sign-in language menu switches en, am, om and back', (
    tester,
  ) async {
    final controller = await _createTestController(tester);
    controller.status = AuthStatus.signedOut;
    controller.locale = const Locale('en');

    await tester.pumpWidget(
      BakeryApp(
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: '/sign-in',
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Email'), findsOneWidget);

    Future<void> choose(String language) async {
      await tester.tap(find.byKey(const Key('sign-in-language-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language));
      await tester.pump(const Duration(milliseconds: 350));
    }

    await choose('አማርኛ');
    expect(find.text('ኢሜይል'), findsOneWidget);
    expect(controller.locale?.languageCode, 'am');

    await choose('Afaan Oromoo');
    expect(find.text('Imeelii'), findsOneWidget);
    expect(controller.locale?.languageCode, 'om');

    await choose('English');
    expect(find.text('Email'), findsOneWidget);
    expect(controller.locale?.languageCode, 'en');

    controller.dispose();
  });
}

Future<AuthController> _createTestController(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final controller = AuthController(offlineSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return controller;
}

void _setPortal(AuthController controller, String role) {
  controller
    ..status = AuthStatus.ready
    ..userId = 'test-user'
    ..fullName = 'Test User'
    ..roleCode = role
    ..branches = [
      BranchAccess(
        branchId: 'test-branch',
        branchName: 'Test branch',
        branchCode: 'TEST',
        roleCode: role,
        permissions: const {
          'pos.use',
          'sales.view',
          'production.manage',
          'inventory.view',
          'cash.view',
          'hr.view',
          'payroll.manage',
          'rentals.manage',
          'credit.manage',
          'expenses.approve',
          'reports.view',
          'settings.manage',
          'users.manage',
        },
      ),
    ]
    ..selectedBranchId = 'test-branch';
}
