import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/friendly_error.dart';
import '../core/locale/locale_preferences.dart';
import '../core/logging/app_logger.dart';
import '../data/formatting.dart';
import '../data/repository.dart';
import '../data/save_flow.dart';

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
  static const inactivityTimeout = Duration(minutes: 30);

  AuthController(
    this.client, {
    this.profileWriteTimeout = const Duration(seconds: 20),
  }) {
    _subscription = client.auth.onAuthStateChange.listen((state) {
      if (_initialized) unawaited(_loadSession(state.session));
    });
    unawaited(_initialize());
  }

  final SupabaseClient client;
  final Duration profileWriteTimeout;
  late final StreamSubscription<AuthState> _subscription;
  AuthStatus status = AuthStatus.loading;
  String? errorMessage;
  String? signInNotice;
  Object? lastError;
  String? userId;
  String? userEmail;
  String? fullName;
  String? phone;
  String? avatarUrl;
  String? profileLanguage;
  String? roleCode;
  List<BranchAccess> branches = const [];
  String? selectedBranchId;
  Locale? locale;
  bool localeResetNotice = false;
  ThemeMode themeMode = ThemeMode.system;
  bool _initialized = false;
  int _loadId = 0;
  bool _disposed = false;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;

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
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(localeRecoveryPreferenceKey) ?? false) {
        locale = const Locale('en');
        localeResetNotice = true;
        await preferences.setString('locale', 'en');
        await preferences.remove(localeRecoveryPreferenceKey);
      } else {
        final savedLocale = preferences.getString('locale');
        if (savedLocale != null) {
          locale = localeFromLanguageCode(savedLocale);
          if (locale == null) {
            AppLogger.error(
              'Unsupported saved language code',
              FormatException('Unsupported language code: $savedLocale'),
            );
            locale = const Locale('en');
            localeResetNotice = true;
            await preferences.setString('locale', 'en');
          }
        }
      }
      final savedTheme = preferences.getString('theme_mode');
      if (savedTheme != null) {
        themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == savedTheme,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Could not restore saved app preferences', error, stack);
      locale = const Locale('en');
      localeResetNotice = true;
      if (preferences != null) {
        try {
          await preferences.setString('locale', 'en');
          await preferences.remove(localeRecoveryPreferenceKey);
        } catch (recoveryError, recoveryStack) {
          AppLogger.error(
            'Could not save the English language recovery',
            recoveryError,
            recoveryStack,
          );
        }
      }
    }
    _initialized = true;
    await _loadSession(client.auth.currentSession);
  }

  Future<void> retry() => _loadSession(client.auth.currentSession);

  /// Test hook: drive one session load with an explicit session so tests can
  /// exercise deactivated-account handling without a live auth server.
  @visibleForTesting
  Future<void> debugLoadSession(Session? session) => _loadSession(session);

  Future<void> _loadSession(Session? session) async {
    final loadId = ++_loadId;
    errorMessage = null;
    lastError = null;
    if (session == null) {
      _stopInactivityTimer();
      userId = null;
      userEmail = null;
      fullName = null;
      phone = null;
      avatarUrl = null;
      profileLanguage = null;
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
      if (profile['is_active'] == false) {
        // A deactivated account must not reach the dashboard even if its
        // auth token is still valid. Clear the session and show the normal
        // sign-in screen with an explanation.
        try {
          await client.auth.signOut();
        } catch (_) {
          // The session is unusable either way; never block the sign-out UI.
        }
        _stopInactivityTimer();
        userId = null;
        userEmail = null;
        fullName = null;
        phone = null;
        avatarUrl = null;
        profileLanguage = null;
        roleCode = null;
        branches = const [];
        selectedBranchId = null;
        status = AuthStatus.signedOut;
        errorMessage = 'Account deactivated. Contact an administrator.';
        signInNotice = 'Account deactivated. Contact an administrator.';
        _notify();
        return;
      }
      signInNotice = null;
      fullName = profile['full_name'] as String?;
      phone = profile['phone'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
      profileLanguage = profile['language'] as String?;
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
        branchRows =
            (await client
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
            branchName: row['name'] as String? ?? 'Jimma branch',
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
          noteActivity();
        } else {
          _stopInactivityTimer();
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
      noteActivity();
    } on PostgrestException catch (exception, stack) {
      _stopInactivityTimer();
      if (loadId != _loadId) return;
      AppLogger.error('Could not load account access', exception, stack);
      lastError = exception;
      errorMessage = friendlyMessage(exception);
      status = AuthStatus.error;
    } catch (exception, stack) {
      if (loadId != _loadId) return;
      _stopInactivityTimer();
      AppLogger.error('Could not load account access', exception, stack);
      lastError = exception;
      errorMessage = friendlyMessage(exception);
      status = AuthStatus.error;
    }
    _notify();
  }

  /// Call on any pointer interaction. Resets the 30-minute inactivity timer.
  void noteActivity() {
    if (status != AuthStatus.ready) return;
    _lastActivity = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, _expireAfterInactivity);
  }

  void _expireAfterInactivity() {
    if (SaveFlow.hasActiveWrites) {
      _inactivityTimer = Timer(
        const Duration(seconds: 1),
        _expireAfterInactivity,
      );
      return;
    }
    _inactivityTimer = null;
    unawaited(signOut());
  }

  /// Call when the app returns to the foreground. If the phone was idle for
  /// longer than the timeout, sign out immediately instead of waiting.
  void checkInactivity() {
    final last = _lastActivity;
    if (last == null) return;
    if (SaveFlow.hasActiveWrites) {
      noteActivity();
      return;
    }
    if (DateTime.now().difference(last) >= inactivityTimeout) {
      _stopInactivityTimer();
      unawaited(signOut());
      return;
    }
    noteActivity();
  }

  /// Test hook: sets the timestamp compared by [checkInactivity].
  @visibleForTesting
  void debugSetLastActivity(DateTime value) => _lastActivity = value;

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivity = null;
  }

  Future<void> selectBranch(String branchId) async {
    if (!branches.any((branch) => branch.branchId == branchId)) return;
    selectedBranchId = branchId;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('selected_branch', branchId);
  }

  Future<void> createFirstBranch() async {
    await SaveFlow.write(
      module: 'Account',
      target: 'branches',
      action: () => client.from('branches').insert({
        'code': 'MAIN',
        'name': 'Jimma branch',
        'is_active': true,
      }),
    );
    await retry();
  }

  Future<void> refresh() => retry();

  Future<void> setLocale(String? languageCode) async {
    final nextLocale = languageCode == null
        ? null
        : localeFromLanguageCode(languageCode);
    if (languageCode != null && nextLocale == null) {
      AppLogger.error(
        'Unsupported language change request',
        FormatException('Unsupported language code: $languageCode'),
      );
      locale = const Locale('en');
      localeResetNotice = true;
      _notify();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('locale', 'en');
      return;
    }

    locale = nextLocale;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await preferences.remove('locale');
    } else {
      await preferences.setString('locale', languageCode);
    }
    if (userId == null) return;
    try {
      await SaveFlow.write(
        module: 'Account',
        target: 'profiles',
        action: () => client
            .from('profiles')
            .update({'language': languageCode ?? 'en'})
            .eq('id', userId!),
      );
      profileLanguage = languageCode ?? 'en';
    } catch (error, stack) {
      AppLogger.error('Could not save the profile language', error, stack);
      locale = const Locale('en');
      profileLanguage = 'en';
      await preferences.setString('locale', 'en');
      _notify();
      rethrow;
    }
  }

  bool takeLocaleResetNotice() {
    final notice = localeResetNotice;
    localeResetNotice = false;
    return notice;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    _notify();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_mode', mode.name);
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (userId == null) return;
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName.trim();
    if (phone != null) payload['phone'] = phone.trim();
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (payload.isEmpty) return;
    await SaveFlow.write(
      module: 'Account',
      target: 'profiles',
      action: () => client
          .from('profiles')
          .update(payload)
          .eq('id', userId!)
          .select('id')
          .single()
          .timeout(profileWriteTimeout),
    );
    if (payload.containsKey('full_name')) this.fullName = fullName!.trim();
    if (payload.containsKey('phone')) this.phone = phone!.trim();
    if (payload.containsKey('avatar_url')) this.avatarUrl = avatarUrl;
    _notify();
  }

  Future<void> updateProfileName(String name) => updateProfile(fullName: name);

  Future<void> changePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() async {
    _stopInactivityTimer();
    await client.auth.signOut();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopInactivityTimer();
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

  static AuthController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    return scope?.notifier;
  }

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
