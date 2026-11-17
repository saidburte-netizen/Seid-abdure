import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/core/errors/save_timeout_exception.dart';
import 'package:brade_and_cake_house/core/events/data_revision.dart';
import 'package:brade_and_cake_house/core/logging/error_log.dart';
import 'package:brade_and_cake_house/core/logging/save_diagnostics.dart';
import 'package:brade_and_cake_house/core/logging/save_trace.dart';
import 'package:brade_and_cake_house/data/save_flow.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SaveDiagnostics.instance.resetForTesting();
    await SaveTrace.instance.clear();
    await ErrorLog.instance.clear();
  });

  test('a successful write returns the value and bumps the revision', () async {
    final before = DataRevision.notifier.value;
    final value = await SaveFlow.write<int>(
      module: 'Test',
      target: 'test_write',
      action: () async => 42,
    );

    expect(value, 42);
    expect(DataRevision.notifier.value, before + 1);
  });

  test('a failed write is logged, rethrown, and does not bump', () async {
    await ErrorLog.instance.clear();
    final before = DataRevision.notifier.value;

    await expectLater(
      SaveFlow.write<void>(
        module: 'Test',
        target: 'test_failure',
        action: () async => throw StateError('write failed'),
      ),
      throwsStateError,
    );

    expect(DataRevision.notifier.value, before);
    expect(ErrorLog.instance.entries.first.module, 'Test');
    expect(ErrorLog.instance.entries.first.target, 'test_failure');
    expect(ErrorLog.instance.entries.first.message, contains('write failed'));
  });

  test('a stuck write times out with a friendly retry error', () async {
    final before = DataRevision.notifier.value;
    await expectLater(
      SaveFlow.write<void>(
        module: 'Test',
        target: 'test_timeout',
        timeout: const Duration(milliseconds: 20),
        action: () => Future<void>.delayed(const Duration(seconds: 5)),
      ),
      throwsA(isA<SaveTimeoutException>()),
    );
    expect(DataRevision.notifier.value, before);
    expect(
      SaveTrace.instance.entries.map((entry) => entry.step),
      containsAll(['session ok', 'request sent', 'timeout']),
    );
  });

  test(
    'a successful write records every breadcrumb with a timestamp',
    () async {
      await SaveFlow.write<int>(
        module: 'Test',
        target: 'test_breadcrumbs',
        action: () async => 1,
      );
      final trace = SaveTrace.instance.entries
          .where((entry) => entry.target == 'test_breadcrumbs')
          .toList();
      final steps = trace.map((entry) => entry.step).toList();
      expect(
        steps,
        containsAll([
          'started',
          'session ok',
          'request sent',
          'response received',
          'bumped',
        ]),
      );
      expect(trace.every((entry) => entry.time.year >= 2020), isTrue);
    },
  );

  test('a read does not bump the revision', () async {
    final before = DataRevision.notifier.value;
    final value = await SaveFlow.read<String>(
      module: 'Test',
      target: 'test_read',
      action: () async => 'value',
    );

    expect(value, 'value');
    expect(DataRevision.notifier.value, before);
  });

  test('a stalled write times out and records the last reached step', () async {
    final response = Completer<int>();
    final before = DataRevision.notifier.value;

    await expectLater(
      SaveFlow.write<int>(
        module: 'Test',
        target: 'stalled_write',
        timeout: const Duration(milliseconds: 10),
        action: () => response.future,
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(DataRevision.notifier.value, before);
    expect(SaveFlow.hasActiveWrites, isFalse);
    expect(SaveDiagnostics.instance.entries.first.step, 'failed');
    response.complete(1);
  });
}
