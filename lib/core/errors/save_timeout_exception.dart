import 'dart:async';

/// Thrown when a write does not finish inside the shared save timeout.
///
/// It lives in the core error package so both the save boundary and the
/// friendly-error mapper can refer to it without a data-layer dependency.
/// It extends [TimeoutException] so existing timeout handling still matches.
class SaveTimeoutException extends TimeoutException {
  SaveTimeoutException() : super('The save took too long.');
}
