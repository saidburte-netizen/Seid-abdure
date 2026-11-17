import '../core/errors/save_timeout_exception.dart';
import '../core/events/data_revision.dart';
import '../core/logging/error_log.dart';
import '../core/logging/save_diagnostics.dart';
import '../core/logging/save_trace.dart';

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

  /// A save may not hold the UI busy forever. The dialog or screen remains
  /// open on timeout so the user can retry without re-entering data.
  static const Duration writeTimeout = Duration(seconds: 25);

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
    final trace = SaveTrace.instance.begin(module: module, target: target);
    _activeWrites++;
    try {
      _breadcrumb(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'session ok',
      );
      trace.mark('session ok');
      _breadcrumb(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'request sent',
      );
      trace.mark('request sent');
      final result = await action().timeout(
        timeout,
        onTimeout: () {
          trace.mark('timeout', detail: '${timeout.inSeconds}s');
          throw SaveTimeoutException();
        },
      );
      _breadcrumb(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'response received',
      );
      trace.mark('response received');
      DataRevision.bump();
      _breadcrumb(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'bumped',
      );
      trace.mark('bumped');
      return result;
    } catch (error) {
      _breadcrumb(
        attemptId: attemptId,
        module: module,
        target: target,
        step: 'failed',
      );
      trace.fail(error);
      ErrorLog.instance.record(module: module, target: target, error: error);
      rethrow;
    } finally {
      _activeWrites--;
    }
  }

  static void _breadcrumb({
    required String attemptId,
    required String module,
    required String target,
    required String step,
  }) {
    SaveDiagnostics.instance.record(
      attemptId: attemptId,
      module: module,
      target: target,
      step: step,
    );
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
