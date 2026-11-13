import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/formatting.dart';
import '../data/repository.dart';

enum AuthStatus { loading, signedOut, needsMembership, ready, error }

class BranchAccess {
  BranchAccess({
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.roleSlugs,
    required this.permissions,
  });

  final String branchId;
  final String branchName;
  final String branchCode;
  final Set<String> roleSlugs;
  final Set<String> permissions;

  bool get isAdmin =>
      roleSlugs.contains('owner') || roleSlugs.contains('admin');
}

class AuthController extends ChangeNotifier {
  AuthController(this.client) {
    _subscription = client.auth.onAuthStateChange.listen((state) {
      if (_initialized) unawaited(_loadSession(state.session));
    });
    unawaited(_initialize());
  }

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  AuthStatus status = AuthStatus.loading;
  String? errorMessage;
  String? userId;
  String? userEmail;
  String? fullName;
  List<BranchAccess> branches = const [];
  String? selectedBranchId;
  Locale? locale;
  ThemeMode themeMode = ThemeMode.system;
  bool _initialized = false;
  int _loadId = 0;
  bool _disposed = false;

  BranchAccess? get selectedBranch {
    for (final branch in branches) {
      if (branch.branchId == selectedBranchId) return branch;
    }
    return branches.isEmpty ? null : branches.first;
  }

  bool can(String permission, {String? branchId}) {
    BranchAccess? branch;
    if (branchId == null) {
      branch = selectedBranch;
    } else {
      for (final item in branches) {
        if (item.branchId == branchId) branch = item;
      }
    }
    if (branch == null) return false;
    return branch.isAdmin || branch.permissions.contains(permission);
  }

  bool canAny(List<String> permissions) =>
      permissions.any((permission) => can(permission));

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLocale = preferences.getString('locale');
    if (savedLocale != null) {
      locale = Locale(savedLocale);
    }
    final savedTheme = preferences.getString('theme_mode');
    if (savedTheme != null) {
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
    _initialized = true;
    await _loadSession(client.auth.currentSession);
  }

  Future<void> retry() => _loadSession(client.auth.currentSession);

  Future<void> _loadSession(Session? session) async {
    final loadId = ++_loadId;
    errorMessage = null;
    if (session == null) {
      userId = null;
      userEmail = null;
      fullName = null;
      branches = const [];
      selectedBranchId = null;
      status = AuthStatus.signedOut;
      _notify();
      return;
    }

    userId = session.user.id;
    userEmail = session.user.email;
    status = AuthStatus.loading;
    _notify();
    try {
      final profile = await client
          .from('profiles')
          .select('full_name')
          .eq('id', session.user.id)
          .maybeSingle();
      fullName = profile?['full_name'] as String?;

      final rows = await client
          .from('branch_memberships')
          .select(
            'branch_id, is_active, branches(id, name, code, is_active), '
            'roles(slug, role_permissions(permissions(permission_key)))',
          )
          .eq('user_id', session.user.id)
          .eq('is_active', true);

      if (loadId != _loadId) return;
      final loaded = <BranchAccess>[];
      for (final raw in rows) {
        final row = asMap(raw);
        final branch = asMap(row['branches']);
        if (branch.isEmpty || !asBool(branch['is_active'], fallback: true)) {
          continue;
        }
        final role = asMap(row['roles']);
        final roleSlugs = <String>{};
        final permissions = <String>{};
        final slug = role['slug'] as String?;
        if (slug != null) roleSlugs.add(slug);
        for (final rolePermission in asMapList(role['role_permissions'])) {
          final permission = asMap(rolePermission['permissions']);
          final key = permission['permission_key'] as String?;
          if (key != null) permissions.add(key);
        }
        loaded.add(BranchAccess(
          branchId: row['branch_id'] as String,
          branchName: branch['name'] as String? ?? 'Branch',
          branchCode: branch['code'] as String? ?? '',
          roleSlugs: roleSlugs,
          permissions: permissions,
        ));
      }

      branches = loaded;
      if (branches.isEmpty) {
        selectedBranchId = null;
        status = AuthStatus.needsMembership;
        _notify();
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      final savedBranch = preferences.getString('selected_branch');
      if (branches.any((branch) => branch.branchId == savedBranch)) {
        selectedBranchId = savedBranch;
      } else {
        selectedBranchId = branches.first.branchId;
      }
      status = AuthStatus.ready;
    } on PostgrestException catch (exception) {
      if (loadId != _loadId) return;
      errorMessage = exception.message;
      status = AuthStatus.error;
    } catch (exception) {
      if (loadId != _loadId) return;
      errorMessage = readableError(exception);
      status = AuthStatus.error;
    }
    _notify();
  }

  Future<void> selectBranch(String branchId) async {
    if (!branches.any((branch) => branch.branchId == branchId)) return;
    selectedBranchId = branchId;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('selected_branch', branchId);
  }

  Future<void> bootstrapOwner() async {
    await client.rpc('bootstrap_first_owner');
    await retry();
  }

  Future<void> refresh() => retry();

  Future<void> setLocale(String? languageCode) async {
    locale = languageCode == null ? null : Locale(languageCode);
    _notify();
    final preferences = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await preferences.remove('locale');
    } else {
      await preferences.setString('locale', languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_mode', mode.name);
  }

  Future<void> updateProfileName(String name) async {
    if (userId == null) return;
    await client
        .from('profiles')
        .update({'full_name': name.trim()}).eq('id', userId!);
    fullName = name.trim();
    _notify();
  }

  Future<void> signOut() => client.auth.signOut();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Makes the authenticated session available to every screen without a
/// third-party state container.
class SessionScope extends InheritedNotifier<AuthController> {
  const SessionScope({
    required AuthController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
