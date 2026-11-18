import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/data/formatting.dart';
import 'package:brade_and_cake_house/data/schema.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';
import 'package:brade_and_cake_house/l10n/ui_text.dart';
import 'package:brade_and_cake_house/theme/app_theme.dart';
import 'package:brade_and_cake_house/widgets/crud_tab.dart';

import 'support/sample_backend.dart';

const _locales = ['en', 'am', 'om'];

bool _isTextField(FieldType type) => switch (type) {
  FieldType.text ||
  FieldType.multiline ||
  FieldType.number ||
  FieldType.integer ||
  FieldType.date ||
  FieldType.datetime ||
  FieldType.time ||
  FieldType.json => true,
  _ => false,
};

bool _isDropdown(FieldType type) =>
    type == FieldType.select || type == FieldType.lookup;

int _ordinal(TableSpec spec, FieldSpec target, bool Function(FieldType) match) {
  var index = 0;
  for (final field in spec.fields) {
    if (field.generated) continue;
    if (!match(field.type)) continue;
    if (field.key == target.key) return index;
    index++;
  }
  return -1;
}

String _valueFor(FieldSpec field, String locale) {
  switch (field.type) {
    case FieldType.number:
    case FieldType.integer:
      final max = field.max;
      if (max != null && max < 100) return max.toString();
      return '100';
    case FieldType.time:
      return field.key.contains('end') ? '17:00' : '08:00';
    case FieldType.date:
      return dateOnly(DateTime.now());
    case FieldType.datetime:
      return '${dateOnly(DateTime.now())} 10:00:00';
    case FieldType.json:
      return '{}';
    default:
      return 'Test ${field.key} $locale';
  }
}

String? _payloadProblem(String table, Map<String, dynamic> payload) {
  if (payload.values.any((value) => value is DateTime)) {
    return 'payload contains a DateTime object';
  }
  num number(String key) => payload[key] as num? ?? 0;
  String text(String key) => payload[key]?.toString() ?? '';
  const positiveAmountTables = {
    'bills',
    'cash_transactions',
    'cash_transfers',
    'employee_advances',
    'payable_payments',
    'payables',
    'receivable_payments',
    'receivables',
    'rent_payments',
    'write_offs',
  };
  if (positiveAmountTables.contains(table) && number('amount') <= 0) {
    return 'amount must be greater than zero';
  }
  switch (table) {
    case 'cake_orders':
      if (number('quantity') <= 0) return 'quantity must be greater than zero';
    case 'cash_transfers':
      if (text('from_account_id') == text('to_account_id')) {
        return 'from and to accounts must differ';
      }
    case 'employees':
      if (!text('employee_no').startsWith('EMP-')) {
        return 'employee number was not generated';
      }
    case 'leases':
      final start = DateTime.tryParse(text('start_date'));
      final end = DateTime.tryParse(text('end_date'));
      if (start == null || end == null || !end.isAfter(start)) {
        return 'end_date must be after start_date';
      }
    case 'payroll_runs':
      final period = DateTime.tryParse(text('period_month'));
      if (period == null || period.day != 1) {
        return 'period_month must be the first day of a month';
      }
    case 'stock_transfers':
      if (text('from_store_id') == text('to_store_id')) {
        return 'from and to stores must differ';
      }
      if (number('quantity') <= 0) return 'quantity must be greater than zero';
  }
  return null;
}

Future<String?> _createOne(
  WidgetTester tester,
  TableSpec spec,
  String locale,
) async {
  tester.takeException();
  Map<String, dynamic>? posted;
  final client = sampleSupabaseClient(
    rowsFor: (path) => path.contains('/branches')
        ? [
            {'id': 'test-branch', 'name': 'Test branch', 'code': 'TEST'},
          ]
        : const [],
    onWrite: (request) {
      posted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'id': 'new-row'}),
        201,
        headers: const {'content-type': 'application/json'},
        request: request,
      );
    },
  );
  final controller = AuthController(client)
    ..status = AuthStatus.ready
    ..userId = 'create-test-user'
    ..fullName = 'Create Test Admin'
    ..roleCode = 'admin'
    ..locale = Locale(locale)
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

  await tester.pumpWidget(
    SessionScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...oromoFrameworkLocalizationsDelegates,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(body: CrudTab(spec: spec)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.add).first);
  await tester.pumpAndSettle();

  final dialog = find.byType(AlertDialog);
  final textFields = find.descendant(
    of: dialog,
    matching: find.byType(TextFormField),
  );
  final dropdowns = find.descendant(
    of: dialog,
    matching: find.byType(DropdownButtonFormField<String>),
  );
  final switches = find.descendant(
    of: dialog,
    matching: find.byType(SwitchListTile),
  );

  for (final field in spec.fields) {
    if (field.generated || !field.required) continue;
    if (_isTextField(field.type)) {
      final index = _ordinal(spec, field, _isTextField);
      final widget = tester.widget<TextFormField>(textFields.at(index));
      if ((widget.controller?.text ?? '').trim().isEmpty) {
        await tester.enterText(textFields.at(index), _valueFor(field, locale));
        await tester.pump();
      }
    } else if (_isDropdown(field.type)) {
      final index = _ordinal(spec, field, _isDropdown);
      final widget = tester.widget<DropdownButtonFormField<String>>(
        dropdowns.at(index),
      );
      if (widget.initialValue == null) {
        await tester.tap(dropdowns.at(index));
        await tester.pumpAndSettle();
        final items = find.byType(DropdownMenuItem<String>);
        if (items.evaluate().isEmpty) {
          controller.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          return '${spec.table}: no options for ${field.key}';
        }
        await tester.ensureVisible(items.last);
        await tester.pumpAndSettle();
        await tester.tap(items.last);
        await tester.pumpAndSettle();
      }
    } else if (field.type == FieldType.boolean) {
      final index = _ordinal(spec, field, (type) => type == FieldType.boolean);
      final widget = tester.widget<SwitchListTile>(switches.at(index));
      if (widget.value != true) {
        await tester.tap(switches.at(index));
        await tester.pump();
      }
    }
  }

  await tester.tap(find.text(uiTextForLocale(locale, 'Save')));
  await tester.pumpAndSettle();
  final exception = tester.takeException();
  controller.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  if (exception != null) return '${spec.table}: $exception';
  if (posted == null) {
    final texts = find
        .descendant(of: dialog, matching: find.byType(Text))
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .toList();
    return '${spec.table}: no insert was sent; texts=$texts';
  }
  return _payloadProblem(spec.table, posted!);
}

void main() {
  for (final locale in _locales) {
    testWidgets(
      'every create form saves in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final failures = <String>[];
        for (final spec in tableSpecs.values.where((spec) => spec.canCreate)) {
          final failure = await _createOne(tester, spec, locale);
          if (failure != null) failures.add(failure);
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}
