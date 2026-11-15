import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brade_and_cake_house/auth/auth_controller.dart';

import 'support/fake_backend.dart';

void main() {
  test('signs out after 30 minutes without any interaction', () {
    SharedPreferences.setMockInitialValues({});
    fakeAsync((async) {
      final controller = AuthController(offlineSupabaseClient());
      async.flushMicrotasks();
      controller.status = AuthStatus.ready;
      controller.noteActivity();

      async.elapse(const Duration(minutes: 29));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.ready);

      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.signedOut);

      controller.dispose();
    });
  });

  test('interaction resets the inactivity window', () {
    SharedPreferences.setMockInitialValues({});
    fakeAsync((async) {
      final controller = AuthController(offlineSupabaseClient());
      async.flushMicrotasks();
      controller.status = AuthStatus.ready;

      controller.noteActivity();
      async.elapse(const Duration(minutes: 20));
      controller.noteActivity();
      async.elapse(const Duration(minutes: 20));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.ready);

      async.elapse(const Duration(minutes: 11));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.signedOut);

      controller.dispose();
    });
  });

  test('returning to the app after a long idle signs out immediately', () {
    SharedPreferences.setMockInitialValues({});
    fakeAsync((async) {
      final controller = AuthController(offlineSupabaseClient());
      async.flushMicrotasks();
      controller.status = AuthStatus.ready;
      controller.debugSetLastActivity(
        DateTime.now().subtract(const Duration(minutes: 31)),
      );

      controller.checkInactivity();
      async.flushMicrotasks();

      expect(controller.status, AuthStatus.signedOut);
      controller.dispose();
    });
  });

  test('a short absence keeps the session and restarts the timer', () {
    SharedPreferences.setMockInitialValues({});
    fakeAsync((async) {
      final controller = AuthController(offlineSupabaseClient());
      async.flushMicrotasks();
      controller.status = AuthStatus.ready;
      controller.noteActivity();

      controller.debugSetLastActivity(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      controller.checkInactivity();
      async.flushMicrotasks();

      expect(controller.status, AuthStatus.ready);
      async.elapse(const Duration(minutes: 29));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.ready);
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(controller.status, AuthStatus.signedOut);

      controller.dispose();
    });
  });
}
