import 'package:flutter/foundation.dart';

/// A tiny application-wide revision counter.
///
/// Every successful write bumps it. Read models such as the dashboard listen
/// and reload, so a save in any module is reflected when the user returns to
/// the dashboard instead of showing stale zeros.
class DataRevision {
  DataRevision._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void bump() {
    notifier.value++;
  }
}
