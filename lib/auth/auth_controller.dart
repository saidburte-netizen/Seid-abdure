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
    required this.roleCode,
    required this.permissions,
  });

  final String branchId;
  final String branchName;
  final String branchCode;
  final String roleCode;
  final Set<String> permissions;

  bool get isAdmin => roleCode == 'admin';
  bool get isManager => roleCode == 'manager';
  bool get isCustomer => roleCode == 'customer';

  String get roleLabel => switch (roleCode) {
        'admin' => 'Administrator',
        'manager' => 'Manager',
        'cashier' => 'Cashier',
        'baker' => 'Baker',
        'store_keeper' => 'Store keeper',
        'hr_officer' => 'HR officer',
        'accountant' => 'Accountant',
        'staff' => 'Staff',
        'customer' => 'Customer',
        _ => prettyLabel(roleCode),
      };
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
  String? roleCode;
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

  bool get isAdmin => roleCode == 'admin' || selectedBranch?.isAdmin == true;
  bool get isCustomer => roleCode == 'customer';

  bool can(String permission, {String? branchId}) {
    if (isAdmin) return true;
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
    if (savedLocale != null) locale = Locale(savedLocale);
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
      roleCode = null;
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
          .select('*')
          .eq('id', session.user.id)
          .maybeSingle();
      if (loadId != _loadId) return;
      if (profile == null) {
        status = AuthStatus.needsMembership;
        _notify();
        return;
      }
      fullName = profile['full_name'] as String?;
      roleCode = profile['role_code'] as String? ?? 'staff';

      final permissionRows = await client
          .from('role_permissions')
          .select('permission_code')
          .eq('role_code', roleCode!);
      final permissions = {
        for (final raw in (permissionRows as List))
          if (asMap(raw)['permission_code'] is String)
            asMap(raw)['permission_code'] as String,
      };

      final isAdminRole = roleCode == 'admin';
      List<Map<String, dynamic>> branchRows;
      if (isAdminRole) {
        branchRows = (await client
                .from('branches')
                .select('id, name, code')
                .eq('is_active', true)
                .order('name'))
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } else {
        final branchId = profile['branch_id'] as String?;
        if (branchId == null) {
          branches = const [];
          status = AuthStatus.needsMembership;
          errorMessage = 'Your profile is not assigned to a branch.';
          _notify();
          return;
        }
        final row = await client
            .from('branches')
            .select('id, name, code')
            .eq('id', branchId)
            .maybeSingle();
        branchRows = row == null ? const [] : [Map<String, dynamic>.from(row)];
      }

      if (loadId != _loadId) return;
      branches = [
        for (final row in branchRows)
          BranchAccess(
            branchId: row['id'] as String,
            branchName: row['name'] as String? ?? 'Main branch',
            branchCode: row['code'] as String? ?? '',
            roleCode: roleCode!,
            permissions: isAdminRole ? const {} : permissions,
          ),
      ];
      if (branches.isEmpty) {
        selectedBranchId = null;
        status = isAdminRole ? AuthStatus.ready : AuthStatus.needsMembership;
        if (isAdminRole) {
          errorMessage =
              'No active branch exists yet. Create the first branch to continue.';
        }
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

  Future<void> createFirstBranch() async {
    await client.from('branches').insert({
      'code': 'MAIN',
      'name': 'Main branch',
      'is_active': true,
    });
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
