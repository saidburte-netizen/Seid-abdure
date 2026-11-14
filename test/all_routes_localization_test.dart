import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';
import 'package:brade_and_cake_house/screens/approvals_screen.dart';
import 'package:brade_and_cake_house/screens/cash_screen.dart';
import 'package:brade_and_cake_house/screens/credit_screen.dart';
import 'package:brade_and_cake_house/screens/dashboard_screen.dart';
import 'package:brade_and_cake_house/screens/inventory_screen.dart';
import 'package:brade_and_cake_house/screens/notifications_screen.dart';
import 'package:brade_and_cake_house/screens/payroll_screen.dart';
import 'package:brade_and_cake_house/screens/people_screen.dart';
import 'package:brade_and_cake_house/screens/pos_screen.dart';
import 'package:brade_and_cake_house/screens/production_screen.dart';
import 'package:brade_and_cake_house/screens/rentals_screen.dart';
import 'package:brade_and_cake_house/screens/reports_screen.dart';
import 'package:brade_and_cake_house/screens/sales_screen.dart';
import 'package:brade_and_cake_house/screens/settings_screen.dart';

typedef _RouteCase = ({String path, Widget Function() page});

final _routes = <_RouteCase>[
  (path: '/', page: DashboardScreen.new),
  (path: '/pos', page: PosScreen.new),
  (path: '/sales', page: SalesScreen.new),
  (path: '/production', page: ProductionScreen.new),
  (path: '/inventory', page: InventoryScreen.new),
  (path: '/cash', page: CashScreen.new),
  (path: '/people', page: PeopleScreen.new),
  (path: '/payroll', page: PayrollScreen.new),
  (path: '/rentals', page: RentalsScreen.new),
  (path: '/credit', page: CreditScreen.new),
  (path: '/approvals', page: ApprovalsScreen.new),
  (path: '/reports', page: ReportsScreen.new),
  (path: '/notifications', page: NotificationsScreen.new),
  (path: '/settings', page: SettingsScreen.new),
];

void main() {
  testWidgets('all portal routes build for en, am and om', (tester) async {
    final controller = await _createTestController(tester);

    for (final locale in ['en', 'am', 'om']) {
      _setPortal(controller, 'admin');
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          for (final route in _routes)
            GoRoute(
              path: route.path,
              builder: (context, state) => route.page(),
            ),
        ],
      );
      await tester.pumpWidget(
        SessionScope(
          controller: controller,
          child: MaterialApp.router(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              ...oromoFrameworkLocalizationsDelegates,
              ...AppLocalizations.localizationsDelegates,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      for (final route in _routes) {
        if (route.path != '/') router.go(route.path);
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale, route=${route.path}',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }

    for (final locale in ['en', 'am', 'om']) {
      for (final role in ['admin', 'manager', 'staff']) {
        _setPortal(controller, role);
        await tester.pumpWidget(
          SessionScope(
            controller: controller,
            child: MaterialApp(
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                ...oromoFrameworkLocalizationsDelegates,
                ...AppLocalizations.localizationsDelegates,
              ],
              home: const DashboardScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale, portal=$role',
        );
      }
    }

    controller.dispose();
    await controller.client.dispose();
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
          localizationsDelegates: [
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
    await controller.client.dispose();
  });
}

Future<AuthController> _createTestController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: const {'content-type': 'application/json'},
      ),
    ),
  );
  final controller = AuthController(client);
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
