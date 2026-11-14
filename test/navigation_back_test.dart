import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/widgets/app_scaffold.dart';

const _nonRootRoutes = [
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
  '/access-denied',
];

void main() {
  testWidgets('every non-root screen shows a visible Back arrow', (
    tester,
  ) async {
    final controller = await _createController(tester);
    _setAdmin(controller);
    for (final route in _nonRootRoutes) {
      await tester.pumpWidget(
        BakeryApp(
          key: ValueKey(route),
          client: controller.client,
          authController: controller,
          initialLocation: route,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byIcon(Icons.arrow_back),
        findsOneWidget,
        reason: 'route $route must show a Back arrow',
      );
      expect(tester.takeException(), isNull, reason: 'route $route');
    }
    controller.dispose();
  });

  testWidgets(
    'the dashboard has a menu, no Back arrow, and a double-back exit',
    (tester) async {
      final controller = await _createController(tester);
      _setAdmin(controller);
      await tester.pumpWidget(
        BakeryApp(client: controller.client, authController: controller),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets('leaving a dirty page asks before discarding changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppScaffold(
          title: Text('Dirty form'),
          hasUnsavedChanges: true,
          body: TextField(),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('every Settings tile and selector has a real action', (
    tester,
  ) async {
    final controller = await _createController(tester);
    _setAdmin(controller);
    await tester.pumpWidget(
      BakeryApp(
        client: controller.client,
        authController: controller,
        initialLocation: '/settings',
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.scrollUntilVisible(
      find.byIcon(Icons.language),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, isNotEmpty);
    for (final tile in tiles) {
      expect(
        tile.onTap != null ||
            tile.onLongPress != null ||
            tile.trailing is DropdownButton,
        isTrue,
      );
    }
    final dropdowns = tester.widgetList(
      find.byWidgetPredicate((widget) => widget is DropdownButton),
    );
    expect(dropdowns, isNotEmpty);
    for (final dropdown in dropdowns) {
      expect((dropdown as dynamic).onChanged, isNotNull);
    }
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}

Future<AuthController> _createController(WidgetTester tester) async {
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
        request: request,
      ),
    ),
  );
  final controller = AuthController(client);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return controller;
}

void _setAdmin(AuthController controller) {
  controller
    ..status = AuthStatus.ready
    ..userId = 'test-user'
    ..userEmail = 'admin@example.com'
    ..fullName = 'Test Admin'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'test-branch',
        branchName: 'Test branch',
        branchCode: 'TEST',
        roleCode: 'admin',
        permissions: const {
          'pos.use',
          'sales.view',
          'production.manage',
          'inventory.view',
          'inventory.manage',
          'cash.view',
          'cash.manage',
          'hr.view',
          'hr.manage',
          'payroll.manage',
          'rentals.manage',
          'credit.manage',
          'expenses.approve',
          'expenses.manage',
          'reports.view',
          'settings.manage',
          'branches.manage',
          'users.manage',
          'audit.view',
          'units.manage',
          'categories.manage',
        },
      ),
    ]
    ..selectedBranchId = 'test-branch';
}
