import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/core/events/data_revision.dart';
import 'package:brade_and_cake_house/core/logging/error_log.dart';
import 'package:brade_and_cake_house/data/save_flow.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
