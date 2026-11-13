import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { loading, signedOut, needsMembership, ready, error }

class AuthController extends ChangeNotifier {
  AuthController(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen((state) {
      unawaited(_loadAccess(state.session));
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;
  AuthStatus status = AuthStatus.loading;
  String? errorMessage;
  final Set<String> _permissionKeys = {};
  final Set<String> _roleSlugs = {};
  int _loadId = 0;

  bool canAccess(String permissionKey) =>
      _roleSlugs.contains('owner') ||
      _roleSlugs.contains('admin') ||
      _permissionKeys.contains(permissionKey);

  Future<void> retry() => _loadAccess(_client.auth.currentSession);

  Future<void> _loadAccess(Session? session) async {
    final loadId = ++_loadId;
    _permissionKeys.clear();
    _roleSlugs.clear();
    errorMessage = null;
    if (session == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    status = AuthStatus.loading;
    notifyListeners();
    try {
      final memberships = await _client
          .from('branch_memberships')
          .select(
            'roles(slug, role_permissions(permissions(permission_key)))',
          )
          .eq('user_id', session.user.id)
          .eq('is_active', true);

      if (loadId != _loadId) return;
      for (final membership in memberships) {
        final role = membership['roles'] as Map<String, dynamic>?;
        if (role == null) continue;
        final slug = role['slug'] as String?;
        if (slug != null) _roleSlugs.add(slug);
        final rolePermissions =
            role['role_permissions'] as List<dynamic>? ?? const [];
        for (final rolePermission in rolePermissions) {
          final permission =
              (rolePermission as Map<String, dynamic>)['permissions']
                  as Map<String, dynamic>?;
          final key = permission?['permission_key'] as String?;
          if (key != null) _permissionKeys.add(key);
        }
      }
      status = _roleSlugs.isEmpty
          ? AuthStatus.needsMembership
          : AuthStatus.ready;
    } on PostgrestException catch (exception) {
      if (loadId != _loadId) return;
      errorMessage = exception.message;
      status = AuthStatus.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
