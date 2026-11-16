import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A small branded banner shown above the whole app while the device is
/// offline. When connectivity returns it calls [onReconnected] so the current
/// screen can retry automatically.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({required this.child, this.onReconnected, super.key});

  final Widget child;
  final Future<void> Function()? onReconnected;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handle,
      onError: (_) {
        // Connectivity is best-effort; requests still surface a friendly error.
      },
    );
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      _handle(await _connectivity.checkConnectivity());
    } catch (_) {
      // Connectivity is best-effort; requests still surface a friendly error.
    }
  }

  void _handle(List<ConnectivityResult> results) {
    if (!mounted) return;
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (offline == _offline) return;
    setState(() => _offline = offline);
    if (!offline && _wasOffline) {
      final callback = widget.onReconnected;
      if (callback != null) unawaited(callback());
    }
    _wasOffline = offline;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_offline)
          Material(
            color: scheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_outlined,
                      size: 20,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.offlineBanner,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _check,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
