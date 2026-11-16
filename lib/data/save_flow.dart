import '../core/events/data_revision.dart';
import '../core/logging/error_log.dart';

/// The single application write boundary.
///
/// Every database mutation must pass through [write]. This keeps three
/// guarantees in one place:
///
/// * a failed write is recorded in the administrator diagnostics log;
/// * a successful write bumps [DataRevision], so dashboards, KPI strips and
///   reports reload without the user reopening the screen;
/// * callers cannot forget the bump on a new code path.
///
/// [read] is only for read-only RPCs. It logs failures but never bumps the
/// revision counter.
class SaveFlow {
  SaveFlow._();

  static Future<T> write<T>({
    required String module,
    required String target,
    required Future<T> Function() action,
  }) async {
    try {
      final result = await action();
      DataRevision.bump();
      return result;
    } catch (error) {
      ErrorLog.instance.record(module: module, target: target, error: error);
      rethrow;
    }
  }

  static Future<T> read<T>({
    required String module,
    required String target,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (error) {
      ErrorLog.instance.record(module: module, target: target, error: error);
      rethrow;
    }
  }
}
