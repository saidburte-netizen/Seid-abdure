import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'friendly_error.dart';

/// Shows a branded, friendly error snackbar. Technical exception text is never
/// passed through.
void showFriendlyError(
  BuildContext context,
  Object error, {
  Future<void> Function()? onRetry,
}) {
  if (!context.mounted) return;
  final strings = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.errorContainer,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                friendlyMessage(error, strings: strings),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: strings.retry,
                textColor: scheme.onErrorContainer,
                onPressed: () => unawaited(onRetry()),
              ),
      ),
    );
}

/// A clean inline message box for forms, dialogs and full-page errors.
class FriendlyErrorBox extends StatelessWidget {
  const FriendlyErrorBox({
    required this.error,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  final Object error;
  final Future<void> Function()? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              friendlyMessage(error, strings: strings),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => unawaited(onRetry!()),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(retryLabel ?? strings.retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Release-mode replacement for Flutter's red error screen.
///
/// It intentionally contains no exception text, stack trace, URL or table name.
class FriendlyCrashView extends StatelessWidget {
  const FriendlyCrashView({this.onRetry, this.onResetLanguage, super.key});

  final Future<void> Function()? onRetry;
  final Future<void> Function()? onResetLanguage;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFFF4E8D8),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bakery_dining, size: 56, color: Color(0xFF0B3B17)),
              SizedBox(height: 16),
              Text(
                'Brade and Cake House',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0B3B17),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Something went wrong. Please restart the app and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF3F4A3F), fontSize: 15),
              ),
              if (onRetry != null) ...[
                SizedBox(height: 18),
                _CrashAction(label: 'Try again', onPressed: onRetry!),
              ],
              if (onResetLanguage != null) ...[
                SizedBox(height: 8),
                _CrashAction(
                  label: 'Reset language',
                  onPressed: onResetLanguage!,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _CrashAction extends StatelessWidget {
  const _CrashAction({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: () => unawaited(onPressed()),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B3B17),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
