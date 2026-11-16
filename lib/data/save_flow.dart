import '../core/events/data_revision.dart';
import '../core/logging/error_log.dart';
import '../core/logging/save_diagnostics.dart';

/// The single application write boundary.
///
/// Every database mutation must pass through [write]. This keeps three
/// guarantees in one place:
///
/// * a failed write is recorded in the administrator diagnostics log;
/// * a successful write bumps [DataRevision], so dashboards, KPI strips and
///   reports reload without the user reopening the screen;
/// * every attempt records non-blocking stage breadcrumbs and times out;
/// * callers cannot forget the bump on a new code path.
///
/// [read] is only for read-only RPCs. It logs failures but never bumps the
/// revision counter.
class SaveFlow {
  SaveFlow._();

  static const writeTimeout = Duration(seconds: 20);
  static int _activeWrites = 0;

  static bool get hasActiveWrites => _activeWrites > 0;

  static Future<T> write<T>({
    required String module,
    required String target,
    required Future<T> Function() action,
    String? diagnosticId,
    Duration timeout = writeTimeout,
  }) async {
    final attemptId =
        diagnosticId ??
        SaveDiagnostics.instance.begin(module: module, target: target);
    _activeWrites++;
    try {
      SaveDiagnostics.instance.record(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'request sent',
      );
      final result = await action().timeout(timeout);
      SaveDiagnostics.instance.record(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'response received',
      );
      DataRevision.bump();
      SaveDiagnostics.instance.record(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'bumped',
      );
      return result;
    } catch (error) {
      SaveDiagnostics.instance.record(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'failed',
      );
      ErrorLog.instance.record(module: module, target: target, error: error);
      rethrow;
    } finally {
      _activeWrites--;
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
