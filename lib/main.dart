import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/errors/error_ui.dart';
import 'core/logging/app_logger.dart';

const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _rawSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLogger.error(
          'Uncaught Flutter error',
          details.exception,
          details.stack,
        );
        if (kDebugMode) FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.error('Uncaught platform error', error, stack);
        return true;
      };
      ErrorWidget.builder = (details) => const FriendlyCrashView();

      SupabaseClient? client;
      final url = _cleanUrl(_rawSupabaseUrl);
      final key = _cleanKey(
        _rawSupabasePublishableKey.isNotEmpty
            ? _rawSupabasePublishableKey
            : _rawSupabaseAnonKey,
      );
      if (_isValidSupabaseUrl(url) && key.isNotEmpty) {
        await Supabase.initialize(url: url, publishableKey: key);
        client = Supabase.instance.client;
      }
      runApp(ProviderScope(child: BakeryApp(client: client)));
    },
    (error, stack) {
      AppLogger.error('Uncaught zoned error', error, stack);
    },
  );
}

String _cleanUrl(String value) {
  final trimmed = value.trim();
  return trimmed.endsWith('/')
      ? trimmed.replaceFirst(RegExp(r'/+$'), '')
      : trimmed;
}

String _cleanKey(String value) => value.trim();

bool _isValidSupabaseUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
