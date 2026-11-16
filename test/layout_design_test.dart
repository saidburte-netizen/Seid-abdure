import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/auth/auth_controller.dart';
import 'package:brade_and_cake_house/l10n/ui_text.dart';

import 'support/fake_backend.dart';
import 'support/sample_backend.dart';

/// Main working screens. Each is checked at 360x800 in light and dark mode and
/// in English, Amharic and Afaan Oromoo.
const _screens = [
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
];

/// Settings sub-pages only need the text, tap-target and overflow guard.
const _settingsRoutes = [
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
];

const _authRoutes = [
  '/sign-in',
  '/loading',
  '/profile-missing',
  '/branch-setup',
  '/auth-error',
];

const _size = Size(360, 800);
const _greenFloor = 25.0;
const _greenCeiling = 55.0;

void main() {
  for (final route in _screens) {
    testWidgets('$route: compact layout in light English', (tester) async {
      final result = await _pump(
        tester,
        route,
        locale: 'en',
        mode: ThemeMode.light,
      );
      _expectHeader(result);
      _expectNoTechnicalText(result);
      _expectTitleWhole(result);
      _expectTapTargets(tester, result);
      _expectNoOverflow(result);
      _expectGreenShare(result);

      final first = find.byKey(const Key('first-record'));
      if (first.evaluate().isNotEmpty) {
        final top = tester.getTopLeft(first).dy;
        expect(
          top,
          lessThanOrEqualTo(_size.height * 0.45),
          reason: '$route: first record starts at ${top.toStringAsFixed(1)} dp',
        );
      }

      // The same screen must survive a 1.3x text scale without truncating the
      // title or overflowing.
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump(const Duration(milliseconds: 200));
      final scaled = _inspect(tester, _Pending(route, result.key));
      _expectHeader(scaled);
      _expectTitleWhole(scaled);
      _expectNoOverflow(scaled);
    });

    for (final variant in const [
      (locale: 'en', mode: ThemeMode.dark),
      (locale: 'am', mode: ThemeMode.light),
      (locale: 'am', mode: ThemeMode.dark),
      (locale: 'om', mode: ThemeMode.light),
      (locale: 'om', mode: ThemeMode.dark),
    ]) {
      testWidgets(
        '$route: compact layout in ${variant.mode.name} ${variant.locale}',
        (tester) async {
          final result = await _pump(
            tester,
            route,
            locale: variant.locale,
            mode: variant.mode,
          );
          _expectHeader(result);
          _expectNoTechnicalText(result);
          _expectTitleWhole(result);
          _expectTapTargets(tester, result);
          _expectNoOverflow(result);
        },
      );
    }
  }

  for (final route in _settingsRoutes) {
    testWidgets('$route: no technical text or overflow', (tester) async {
      final result = await _pump(
        tester,
        route,
        locale: 'en',
        mode: ThemeMode.light,
      );
      _expectHeader(result);
      _expectNoTechnicalText(result);
      _expectTitleWhole(result);
      _expectTapTargets(tester, result);
      _expectNoOverflow(result);
    });
  }

  for (final route in _authRoutes) {
    testWidgets('$route: no technical text or overflow', (tester) async {
      final result = await _pump(
        tester,
        route,
        locale: 'en',
        mode: ThemeMode.light,
        signedIn: false,
      );
      _expectNoTechnicalText(result);
      _expectNoOverflow(result);
    });
  }
}

class _Result {
  _Result({
    required this.route,
    required this.headerHeight,
    required this.texts,
    required this.title,
    required this.exception,
    required this.greenShare,
    required this.key,
  });

  final String route;
  final double headerHeight;
  final List<String> texts;
  final RenderParagraph? title;
  final Object? exception;
  final double greenShare;
  final GlobalKey key;
}

Future<_Result> _pump(
  WidgetTester tester,
  String route, {
  required String locale,
  required ThemeMode mode,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    (call) async => null,
  );

  final controller = AuthController(sampleSupabaseClient());
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  if (signedIn) {
    _setAdmin(controller);
  } else {
    switch (route) {
      case '/sign-in':
        controller.status = AuthStatus.signedOut;
      case '/loading':
        controller.status = AuthStatus.loading;
      case '/profile-missing':
        controller.status = AuthStatus.needsMembership;
      case '/branch-setup':
        controller
          ..status = AuthStatus.ready
          ..roleCode = 'admin'
          ..branches = const []
          ..selectedBranchId = null;
      case '/auth-error':
        controller.status = AuthStatus.error;
    }
  }
  await controller.setLocale(locale);
  await controller.setThemeMode(mode);

  final captureKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: BakeryApp(
        key: ValueKey('$route-$locale-${mode.name}'),
        client: controller.client,
        authController: controller,
        signInGateway: FakeSignInGateway(admin: true),
        initialLocation: route,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));

  final inspected = _inspect(tester, _Pending(route, captureKey));
  final share = (locale == 'en' && mode == ThemeMode.light)
      ? await _sampleGreen(captureKey, tester)
      : 0.0;
  final result = _Result(
    route: inspected.route,
    headerHeight: inspected.headerHeight,
    texts: inspected.texts,
    title: inspected.title,
    exception: inspected.exception,
    greenShare: share,
    key: inspected.key,
  );
  // ignore: avoid_print
  print(
    'LAYOUT | ${route.padRight(24)} | ${locale.padRight(2)} | '
    '${mode.name.padRight(5)} | header ${result.headerHeight.toStringAsFixed(1)} '
    '| green ${result.greenShare.toStringAsFixed(1)}%',
  );
  controller.dispose();
  return result;
}

class _Pending {
  const _Pending(this.route, this.key);
  final String route;
  final GlobalKey key;
}

_Result _inspect(WidgetTester tester, _Pending pending) {
  final header = find.byKey(const Key('app-header'));
  final headerHeight = header.evaluate().isEmpty
      ? 0.0
      : tester.getSize(header).height;

  RenderParagraph? title;
  if (header.evaluate().isNotEmpty) {
    final titleFinder = find
        .descendant(of: header, matching: find.byType(Text))
        .first;
    final object = tester.renderObject(titleFinder);
    if (object is RenderParagraph) title = object;
  }

  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.trim().isNotEmpty) texts.add(data);
  }

  final exception = tester.takeException();

  return _Result(
    route: pending.route,
    headerHeight: headerHeight,
    texts: texts,
    title: title,
    exception: exception,
    greenShare: 0,
    key: pending.key,
  );
}

void _expectHeader(_Result result) {
  if (result.headerHeight <= 0) return;
  expect(
    result.headerHeight,
    lessThanOrEqualTo(_size.height * 0.22 + 0.5),
    reason:
        '${result.route}: header is ${result.headerHeight.toStringAsFixed(1)} dp '
        '(budget ${(_size.height * 0.22).toStringAsFixed(1)} dp)',
  );
}

void _expectTitleWhole(_Result result) {
  final title = result.title;
  if (title == null) return;
  expect(
    title.didExceedMaxLines,
    isFalse,
    reason: '${result.route}: the main title is truncated',
  );
}

void _expectNoTechnicalText(_Result result) {
  final rawKey = RegExp(r'^[a-z]+[A-Z][A-Za-z]*$');
  final viewName = RegExp(r'\bv_[a-z_]+');
  final sql = RegExp(
    r'\bselect\s+\*|\bselect\b.+\bfrom\b',
    caseSensitive: false,
  );
  final forbidden = <String>[
    'searchrecords',
    'newrecord',
    'editrecord',
    'deleterecord',
    'norecords',
    'createrecord',
    'live table',
    'public.',
    'uuid',
  ];
  for (final text in result.texts) {
    final lower = text.toLowerCase();
    expect(
      rawKey.hasMatch(text) || uiTemplateKeys.contains(text),
      isFalse,
      reason: '${result.route}: raw localization key "$text" is visible',
    );
    expect(
      viewName.hasMatch(text) ||
          sql.hasMatch(text) ||
          forbidden.any(lower.contains),
      isFalse,
      reason: '${result.route}: technical text "$text" is visible',
    );
  }
}

void _expectTapTargets(WidgetTester tester, _Result result) {
  for (final finder in [
    find.byType(IconButton),
    find.byType(FloatingActionButton),
  ]) {
    for (final element in finder.evaluate()) {
      final widget = find.byElementPredicate(
        (candidate) => candidate == element,
      );
      final size = tester.getSize(widget);
      expect(
        size.width >= 47.5 && size.height >= 47.5,
        isTrue,
        reason:
            '${result.route}: tap target ${size.width}x${size.height} is below 48 dp',
      );
    }
  }
}

void _expectNoOverflow(_Result result) {
  expect(
    result.exception,
    isNull,
    reason: '${result.route}: rendering threw ${result.exception}',
  );
}

void _expectGreenShare(_Result result) {
  // Pixel sampling is done by [_sampleGreen] for the light-English pass; when
  // it was not measured (0) the guard is skipped.
  if (result.greenShare <= 0) return;
  expect(
    result.greenShare,
    inInclusiveRange(_greenFloor, _greenCeiling),
    reason:
        '${result.route}: green share ${result.greenShare.toStringAsFixed(1)}% '
        'is outside $_greenFloor-$_greenCeiling%',
  );
}

Future<double> _sampleGreen(GlobalKey key, WidgetTester tester) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  var green = 0;
  var total = 0;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    for (var i = 0; i < data!.lengthInBytes; i += 4) {
      final r = data.getUint8(i);
      final g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      final a = data.getUint8(i + 3);
      if (a < 8) continue;
      total++;
      if (g > r * 1.18 && g > b * 1.12 && g > 25) green++;
    }
    image.dispose();
  });
  return green * 100 / total;
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
        permissions: const {'*'},
      ),
    ]
    ..selectedBranchId = 'test-branch';
}
