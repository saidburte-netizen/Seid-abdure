import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

/// The small, user-facing set of error categories used by the app.
///
/// Nothing outside this file should need to inspect an exception in order to
/// decide what a customer sees.
enum FriendlyErrorKind {
  offline,
  serviceUnavailable,
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  permissionDenied,
  emailNotConfirmed,
  duplicateRecord,
  recordInUse,
  sessionExpired,
  tooManyAttempts,
  unknown,
}

/// Converts any exception into a short, polite, localized message.
///
/// Technical details are deliberately never included. When no localization is
/// supplied (for example from a unit test) English is used.
String friendlyMessage(Object error, {AppLocalizations? strings}) {
  final l10n = strings ?? AppLocalizationsEn();
  return switch (classifyError(error)) {
    FriendlyErrorKind.offline => l10n.errorNoInternet,
    FriendlyErrorKind.serviceUnavailable => l10n.errorServiceUnavailable,
    FriendlyErrorKind.invalidCredentials => l10n.errorInvalidCredentials,
    FriendlyErrorKind.emailAlreadyRegistered =>
      l10n.errorEmailAlreadyRegistered,
    FriendlyErrorKind.weakPassword => l10n.errorWeakPassword,
    FriendlyErrorKind.permissionDenied => l10n.errorPermissionDenied,
    FriendlyErrorKind.emailNotConfirmed => l10n.errorEmailNotConfirmed,
    FriendlyErrorKind.duplicateRecord => l10n.errorDuplicateRecord,
    FriendlyErrorKind.recordInUse => l10n.errorRecordInUse,
    FriendlyErrorKind.sessionExpired => l10n.errorSessionExpired,
    FriendlyErrorKind.tooManyAttempts => l10n.errorTooManyAttempts,
    FriendlyErrorKind.unknown => l10n.errorSomethingWentWrong,
  };
}

/// Localized version for call sites that have a [BuildContext].
String readableError(BuildContext context, Object error) =>
    friendlyMessage(error, strings: AppLocalizations.of(context));

extension FriendlyErrorBuildContext on BuildContext {
  String friendlyError(Object error) => readableError(this, error);
}

FriendlyErrorKind classifyError(Object error) {
  final text = _technicalText(error);

  if (_isOffline(error, text)) return FriendlyErrorKind.offline;
  if (_isServerUnavailable(error, text)) {
    return FriendlyErrorKind.serviceUnavailable;
  }

  if (error is AuthException) {
    final status = _statusCode(error);
    if (_containsAny(text, const [
      'invalid login',
      'invalid credentials',
      'invalid email or password',
      'wrong password',
    ])) {
      return FriendlyErrorKind.invalidCredentials;
    }
    if (_containsAny(text, const [
      'already registered',
      'already exists',
      'user already',
      'email exists',
    ])) {
      return FriendlyErrorKind.emailAlreadyRegistered;
    }
    if (text.contains('password') &&
        _containsAny(text, const [
          'least',
          'weak',
          'too short',
          '6 characters',
          '8 characters',
        ])) {
      return FriendlyErrorKind.weakPassword;
    }
    if (text.contains('email not confirmed') ||
        text.contains('email not verified')) {
      return FriendlyErrorKind.emailNotConfirmed;
    }
    if (status == 429 || text.contains('rate limit')) {
      return FriendlyErrorKind.tooManyAttempts;
    }
    if (status == 403 ||
        _containsAny(text, const ['not authorized', 'permission'])) {
      return FriendlyErrorKind.permissionDenied;
    }
    if (status == 400 || status == 401) {
      return FriendlyErrorKind.invalidCredentials;
    }
  }

  if (error is PostgrestException) {
    final code = (error.code ?? '').toUpperCase();
    if (code == '42501' ||
        _containsAny(text, const [
          'row-level security',
          'permission denied',
          'not authorized',
        ])) {
      return FriendlyErrorKind.permissionDenied;
    }
    if (code == '23505' || text.contains('duplicate key')) {
      return FriendlyErrorKind.duplicateRecord;
    }
    if (code == '23503' || text.contains('foreign key')) {
      return FriendlyErrorKind.recordInUse;
    }
    if (code == 'PGRST301' ||
        _containsAny(text, const ['jwt expired', 'invalid jwt', 'jwt'])) {
      return FriendlyErrorKind.sessionExpired;
    }
  }

  if (error is StorageException) {
    final status = _statusCode(error);
    if (status == 403) return FriendlyErrorKind.permissionDenied;
    if (status == 429) return FriendlyErrorKind.tooManyAttempts;
  }

  if (error is FormatException) return FriendlyErrorKind.unknown;
  return FriendlyErrorKind.unknown;
}

bool _isOffline(Object error, String text) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return true;
  }
  return _containsAny(text, const [
    'failed host lookup',
    'no address associated with hostname',
    'network is unreachable',
    'network unreachable',
    'temporary failure in name resolution',
    'nodename nor servname',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'xmlhttprequest error',
    'errno = 7',
    'errno = 101',
    'clientexception with socketexception',
    'socketexception',
  ]);
}

bool _isServerUnavailable(Object error, String text) {
  final status = _statusCode(error);
  if (status != null && status >= 500) return true;
  return _containsAny(text, const [
    'statuscode: 500',
    'statuscode: 502',
    'statuscode: 503',
    'statuscode: 504',
    ' 500 ',
    ' 502 ',
    ' 503 ',
    ' 504 ',
    'bad gateway',
    'service unavailable',
    'gateway timeout',
    'internal server error',
    'upstream',
  ]);
}

int? _statusCode(Object error) {
  if (error is AuthException) return int.tryParse(error.statusCode ?? '');
  if (error is StorageException) {
    return int.tryParse(error.statusCode ?? '');
  }
  final match = RegExp(
    r'(?:statuscode|status code|status)[^0-9]{0,12}(\d{3})',
    caseSensitive: false,
  ).firstMatch(error.toString());
  return match == null ? null : int.tryParse(match.group(1)!);
}

String _technicalText(Object error) {
  if (error is PostgrestException) {
    return '${error.message} ${error.details ?? ''} ${error.hint ?? ''} '
            '${error.code ?? ''}'
        .toLowerCase();
  }
  if (error is AuthException) {
    return '${error.message} ${error.code ?? ''}'.toLowerCase();
  }
  if (error is StorageException) {
    return '${error.message} ${error.error ?? ''}'.toLowerCase();
  }
  return error.toString().toLowerCase();
}

bool _containsAny(String text, List<String> needles) =>
    needles.any(text.contains);
