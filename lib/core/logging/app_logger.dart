import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Private diagnostic logger.
///
/// Users never see these details. In debug builds they are printed locally; in
/// release builds they are sent to the Dart developer log only, where they are
/// available to a developer with access to the device or crash reporting.
class AppLogger {
  const AppLogger._();

  static void error(String message, Object error, [StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'brade_and_cake_house',
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode) {
      debugPrint('$message: $error');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }
  }
}
