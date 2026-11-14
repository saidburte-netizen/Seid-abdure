import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brade_and_cake_house/app.dart';
import 'package:brade_and_cake_house/l10n/app_localizations.dart';
import 'package:brade_and_cake_house/l10n/oromo_framework_localizations.dart';
import 'package:brade_and_cake_house/theme/app_theme.dart';

/// Produces a visual artifact for the offline sign-in requirement and keeps
/// the friendly-message assertions in the same test.
void main() {
  testWidgets('airplane mode sign-in evidence screenshot', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        throw const SocketException('Network is unreachable');
      }),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...oromoFrameworkLocalizationsDelegates,
            ...AppLocalizations.localizationsDelegates,
          ],
          home: SignInScreen(client: client),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'cashier@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    const friendly =
        'No internet connection. Please check your network and try again.';
    expect(find.text(friendly), findsOneWidget);
    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join('\n')
        .toLowerCase();
    expect(visible, isNot(contains('socketexception')));
    expect(visible, isNot(contains('network is unreachable')));
    expect(visible, isNot(contains('clientexception')));
    expect(visible, isNot(contains('stack trace')));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/evidence')
        ..createSync(recursive: true);
      final file = File('${directory.path}/airplane-mode-login.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      // ignore: avoid_print
      print('EVIDENCE ${file.path} (${await file.length()} bytes)');
    });
  });
}
