import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/secure_local_storage.dart';
import 'core/errors/error_ui.dart';
import 'core/locale/locale_preferences.dart';
import 'core/logging/app_logger.dart';
import 'data/formatting.dart';

const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _rawSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
Future<void> main() async {
  var firstFrameRendered = false;
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        firstFrameRendered = true;
      });

      SupabaseClient? client;
      Future<void> restartApp() async {
        runApp(BakeryApp(client: client));
      }

      Future<void> resetLanguage() async {
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString('locale', 'en');
          await preferences.setBool(localeRecoveryPreferenceKey, true);
          await restartApp();
        } catch (error, stack) {
          AppLogger.error('Could not reset the saved language', error, stack);
        }
      }

      void reportError(String message, Object error, StackTrace? stack) {
        AppLogger.error(message, error, stack);
        if (!firstFrameRendered) unawaited(_markLocaleForRecovery());
      }

      FlutterError.onError = (details) {
        reportError('Uncaught Flutter error', details.exception, details.stack);
        if (kDebugMode) FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        reportError('Uncaught platform error', error, stack);
        return true;
      };
      ErrorWidget.builder = (details) {
        reportError(
          'Widget rendering failed',
          details.exception,
          details.stack,
        );
        return FriendlyCrashView(
          onRetry: restartApp,
          onResetLanguage: resetLanguage,
        );
      };

      await initializeFormattingData();
      final url = _cleanUrl(_rawSupabaseUrl);
      final key = _cleanKey(
        _rawSupabasePublishableKey.isNotEmpty
            ? _rawSupabasePublishableKey
            : _rawSupabaseAnonKey,
      );
      if (_isValidSupabaseUrl(url) && key.isNotEmpty) {
        await Supabase.initialize(
          url: url,
          publishableKey: key,
          authOptions: FlutterAuthClientOptions(
            localStorage: SecureLocalStorage(
              persistSessionKey: _sessionStorageKey(url),
            ),
          ),
        );
        client = Supabase.instance.client;
      }
      runApp(BakeryApp(client: client));
    },
    (error, stack) {
      AppLogger.error('Uncaught zoned error', error, stack);
      if (!firstFrameRendered) unawaited(_markLocaleForRecovery());
    },
  );
}

Future<void> _markLocaleForRecovery() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final savedLocale = preferences.getString('locale');
    if (savedLocale != null && savedLocale != 'en') {
      await preferences.setBool(localeRecoveryPreferenceKey, true);
    }
  } catch (recoveryError, recoveryStack) {
    AppLogger.error(
      'Could not schedule saved-language recovery after an error',
      recoveryError,
      recoveryStack,
    );
  }
}

String _cleanUrl(String value) {
  final trimmed = value.trim();
  return trimmed.endsWith('/')
      ? trimmed.replaceFirst(RegExp(r'/+$'), '')
      : trimmed;
}

String _cleanKey(String value) => value.trim();

String _sessionStorageKey(String url) =>
    'sb-${Uri.parse(url).host.split('.').first}-auth-token';

bool _isValidSupabaseUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
