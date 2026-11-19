import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  201,
  headers: const {'content-type': 'application/json'},
  request: request,
);

Map<String, dynamic> _body(http.Request request) {
  if (request.body.isEmpty) return const {};
  final decoded = jsonDecode(request.body);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
}

Future<AuthController> _admin(
  WidgetTester tester, {
  required http.Response Function(http.Request) onWrite,
  List<Map<String, dynamic>> Function(String path)? rowsFor,
}) async {
  SharedPreferences.setMockInitialValues({});
  final client = sampleSupabaseClient(onWrite: onWrite, rowsFor: rowsFor);
  final controller = AuthController(client);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  controller
    ..status = AuthStatus.ready
    ..userId = 'human-flow-user'
    ..fullName = 'Round 4 Owner'
    ..roleCode = 'admin'
    ..branches = [
      BranchAccess(
        branchId: 'test-branch',
        branchName: 'Test branch',
        branchCode: 'TEST',
        roleCode: 'admin',
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'test-branch';
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  AuthController controller,
  String route,
) async {
  await tester.pumpWidget(
    BakeryApp(
      key: ValueKey(route),
      client: controller.client,
      authController: controller,
      signInGateway: FakeSignInGateway(admin: true),
      initialLocation: route,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _clearSnackBars(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold).first;
  if (scaffold.evaluate().isEmpty) return;
  ScaffoldMessenger.of(tester.element(scaffold)).clearSnackBars();
  await tester.pumpAndSettle();
}

Finder _formField(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  ),
);

Finder _dialogTextField(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.ancestor(
    of: find.text(label),
    matching: find.byType(TextField),
  ),
);

Future<void> _selectTab(WidgetTester tester, String label) async {
  final tabBar = find.byType(TabBar).first;
  final tabs = tester.widgetList<Tab>(
    find.descendant(of: tabBar, matching: find.byType(Tab)),
  );
  final index = tabs.toList().indexWhere((tab) => tab.text == label);
  expect(index, greaterThanOrEqualTo(0), reason: 'Tab $label must exist');
  final controller = DefaultTabController.of(tester.element(tabBar));
  controller.index = index;
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String label,
  String value,
) async {
  final dropdown = find.widgetWithText(DropdownButtonFormField<String>, label);
  expect(dropdown, findsOneWidget, reason: 'Dropdown $label must be visible');
  await tester.tap(dropdown);
  await tester.pump();
  final item = find.text(value).last;
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _saveDialog(WidgetTester tester) async {
  final save = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Save'),
  );
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home Products tile -> Add product -> save name and price -> New sale finds it',
    (tester) async {
      Map<String, dynamic>? product;
      final controller = await _admin(
        tester,
        onWrite: (request) {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/products')) {
            final data = _body(request);
            product = {
              'id': 'human-product-id',
              'name': data['name'],
              'price': data['price'],
              'cost': data['cost'],
              'tax_rate': data['tax_rate'],
              'is_active': true,
              'item_id': 'human-item-id',
              'branch_id': 'test-branch',
            };
            return _json(product!, request);
          }
          if (request.method == 'PATCH' &&
              path.endsWith('/products') &&
              product != null) {
            product = {...product!, ..._body(request)};
            return _json(product!, request);
          }
          if (request.method == 'POST' && path.endsWith('/items')) {
            return _json({
              'id': 'human-item-id',
              'name': 'Linked item',
              'item_type': 'finished_good',
            }, request);
          }
          return _json(<String, dynamic>{}, request);
        },
        rowsFor: (path) => path.endsWith('/products') && product != null
            ? [product!]
            : const <Map<String, dynamic>>[],
      );

      await _pump(tester, controller, '/');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
      await tester.pumpAndSettle();
      final homeTile = find.text('Products');
      expect(homeTile, findsOneWidget, reason: 'Home grid must show Products');
      await tester.ensureVisible(homeTile);
      final homeCard = find.ancestor(
        of: homeTile,
        matching: find.byType(InkWell),
      );
      await tester.tap(homeCard.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      await tester.enterText(_formField('Name *'), 'Owner Test Cake');
      await tester.enterText(_formField('Price'), '275');
      await _saveDialog(tester);
      expect(find.text('Product saved.'), findsOneWidget);
      await _clearSnackBars(tester);

      expect(product?['name'], 'Owner Test Cake');
      // ignore: avoid_print
      print(
        'HUMAN_FLOW | saved product name=${product?['name']} price=${product?['price']}',
      );

      final productCard = find
          .ancestor(
            of: find.text('Owner Test Cake'),
            matching: find.byType(Card),
          )
          .first;
      await tester.ensureVisible(productCard);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: productCard, matching: find.byTooltip('Edit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit product'), findsOneWidget);
      await tester.enterText(_formField('Price'), '300');
      await _saveDialog(tester);
      expect(product?['price'], 300);
      await _clearSnackBars(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final newSale = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('New sale'),
      );
      expect(newSale, findsOneWidget);
      await tester.tap(newSale);
      await tester.pumpAndSettle();

      expect(find.text('Owner Test Cake'), findsWidgets);
      // ignore: avoid_print
      print('HUMAN_FLOW | New sale shows saved product "Owner Test Cake"');
      controller.dispose();
    },
  );

  testWidgets(
    'Rentals: create property, tenant and lease, generate invoice, pay part then rest',
    (tester) async {
      Map<String, dynamic>? property;
      Map<String, dynamic>? tenant;
      Map<String, dynamic>? lease;
      num paid = 0;

      Map<String, dynamic> invoice() => {
        'id': 'human-invoice-id',
        'invoice_no': 'INV-HUMAN',
        'tenant_id': tenant?['id'] ?? 'human-tenant-id',
        'lease_id': lease?['id'] ?? 'human-lease-id',
        'property_id': property?['id'] ?? 'human-property-id',
        'amount': 1000,
        'paid_amount': paid,
        'balance': 1000 - paid,
        'status': paid >= 1000
            ? 'paid'
            : paid > 0
            ? 'partial'
            : 'unpaid',
        'due_date': '2026-11-30',
        'period_start': '2026-11-01',
        'period_end': '2026-11-30',
      };

      final controller = await _admin(
        tester,
        onWrite: (request) {
          final path = request.url.path;
          final data = _body(request);
          if (request.method == 'POST' && path.endsWith('/properties')) {
            property = {
              'id': 'human-property-id',
              'name': data['name'],
              'property_type': data['property_type'],
              'branch_id': 'test-branch',
            };
            return _json(property!, request);
          }
          if (request.method == 'POST' && path.endsWith('/tenants')) {
            tenant = {'id': 'human-tenant-id', 'full_name': data['full_name']};
            return _json(tenant!, request);
          }
          if (request.method == 'POST' && path.endsWith('/leases')) {
            lease = {
              'id': 'human-lease-id',
              'lease_no': 'LEASE-HUMAN',
              'property_id': data['property_id'],
              'tenant_id': data['tenant_id'],
              'rent_amount': data['rent_amount'],
            };
            return _json(lease!, request);
          }
          if (path.contains('/rpc/fn_generate_rent_invoices')) {
            return http.Response(
              'null',
              200,
              headers: const {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.method == 'POST' && path.endsWith('/rent_payments')) {
            paid += (data['amount'] as num?) ?? 0;
            return _json({
              'id': 'payment-${paid.toInt()}',
              'invoice_id': 'human-invoice-id',
              'amount': data['amount'],
              'method': data['method'],
              'payment_date': data['payment_date'],
            }, request);
          }
          return _json(<String, dynamic>{}, request);
        },
        rowsFor: (path) {
          if (path.endsWith('/properties') && property != null) {
            return [property!];
          }
          if (path.endsWith('/tenants') && tenant != null) return [tenant!];
          if (path.endsWith('/leases') && lease != null) return [lease!];
          if (path.endsWith('/rent_invoices')) return [invoice()];
          return const <Map<String, dynamic>>[];
        },
      );

      await _pump(tester, controller, '/rentals');

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(_formField('Name'), 'Owner Test Property');
      await tester.enterText(_formField('Property type'), 'Shop');
      await _saveDialog(tester);
      expect(property?['name'], 'Owner Test Property');
      // ignore: avoid_print
      print('HUMAN_FLOW | created property ${property?['name']}');

      await _selectTab(tester, 'Tenants');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(_formField('Full name'), 'Owner Test Tenant');
      await _saveDialog(tester);
      await _clearSnackBars(tester);
      expect(tenant?['full_name'], 'Owner Test Tenant');
      // ignore: avoid_print
      print('HUMAN_FLOW | created tenant ${tenant?['full_name']}');

      await _selectTab(tester, 'Leases');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await _selectDropdown(tester, 'Property', 'Owner Test Property');
      await _selectDropdown(tester, 'Tenant', 'Owner Test Tenant');
      await tester.enterText(_formField('Rent amount'), '1000');
      await _saveDialog(tester);
      await _clearSnackBars(tester);
      expect(lease?['rent_amount'].toString(), '1000');
      // ignore: avoid_print
      print('HUMAN_FLOW | created lease rent=${lease?['rent_amount']}');

      await _selectTab(tester, 'Rent invoices');
      await tester.tap(find.text('Generate invoices'));
      await tester.pumpAndSettle();
      final generateConfirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Generate'),
      );
      expect(generateConfirm, findsOneWidget);
      await tester.tap(generateConfirm);
      await tester.pumpAndSettle();
      await _clearSnackBars(tester);
      // ignore: avoid_print
      print('HUMAN_FLOW | tapped Generate invoices and confirmed');

      await _selectTab(tester, 'Rent invoices');
      expect(find.text('Receive payment'), findsWidgets);

      for (final amount in ['400', '600']) {
        final pay = find.text('Receive payment').first;
        await tester.scrollUntilVisible(
          pay,
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('rent-invoices-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(pay);
        await tester.pumpAndSettle();
        await tester.enterText(_dialogTextField('Amount'), amount);
        final dialogPay = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Receive payment'),
        );
        await tester.tap(dialogPay);
        await tester.pumpAndSettle();
        await _clearSnackBars(tester);
        // ignore: avoid_print
        print('HUMAN_FLOW | paid $amount, invoice paid_amount=$paid');
      }

      expect(paid, 1000);
      expect(find.text('Paid'), findsWidgets);
      // ignore: avoid_print
      print('HUMAN_FLOW | invoice INV-HUMAN fully paid ($paid/1000)');
      controller.dispose();
    },
  );

  testWidgets('Stock screen shows item names and amounts', (tester) async {
    final controller = await _admin(
      tester,
      onWrite: (_) => _json(
        <String, dynamic>{},
        http.Request('POST', Uri.parse('https://sample.invalid')),
      ),
    );
    await _pump(tester, controller, '/stock');

    expect(find.text('Chocolate cake'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
    // ignore: avoid_print
    print('HUMAN_FLOW | Stock shows "Chocolate cake" with quantity 12');
    controller.dispose();
  });
}
