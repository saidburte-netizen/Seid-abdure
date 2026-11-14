import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_controller.dart';
import 'brand/brand.dart';
import 'core/connectivity/offline_banner.dart';
import 'core/errors/friendly_error.dart';
import 'core/logging/app_logger.dart';
import 'l10n/app_localizations.dart';
import 'screens/approvals_screen.dart';
import 'screens/cash_screen.dart';
import 'screens/credit_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/people_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/production_screen.dart';
import 'screens/rentals_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

class BakeryApp extends StatelessWidget {
  const BakeryApp({this.client, super.key});

  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) => _BakeryRouter(client: client);
}

class _BakeryRouter extends StatefulWidget {
  const _BakeryRouter({required this.client});

  final SupabaseClient? client;

  @override
  State<_BakeryRouter> createState() => _BakeryRouterState();
}

class _BakeryRouterState extends State<_BakeryRouter> {
  late final AuthController? _auth;
  late final GoRouter _router;

  static const _routePermissions = {
    '/pos': 'pos.use',
    '/sales': 'sales.view',
    '/production': 'production.manage',
    '/inventory': 'inventory.view',
    '/cash': 'cash.view',
    '/people': 'hr.view',
    '/payroll': 'payroll.manage',
    '/rentals': 'rentals.manage',
    '/credit': 'credit.manage',
    '/reports': 'reports.view',
    '/approvals': 'expenses.approve',
    '/audit': 'audit.view',
    '/media': 'products.manage',
  };

  static const _modulePermissions = {
    'production': 'production.manage',
    'sales': 'sales.view',
    'pos': 'pos.use',
    'inventory': 'inventory.view',
    'cash': 'cash.view',
    'people': 'hr.view',
    'payroll': 'payroll.manage',
    'rentals': 'rentals.manage',
    'credit': 'credit.manage',
    'approvals': 'expenses.approve',
    'reports': 'reports.view',
    'notifications': null,
    'settings': 'settings.manage',
    'audit': 'audit.view',
    'media': 'products.manage',
  };

  @override
  void initState() {
    super.initState();
    _auth = widget.client == null ? null : AuthController(widget.client!);
    _router = GoRouter(
      refreshListenable: _auth,
      initialLocation: '/',
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (_auth == null) return location == '/' ? null : '/';

        switch (_auth.status) {
          case AuthStatus.loading:
            return location == '/loading' ? null : '/loading';
          case AuthStatus.signedOut:
            return location == '/sign-in' ? null : '/sign-in';
          case AuthStatus.needsMembership:
            return location == '/profile-missing' ? null : '/profile-missing';
          case AuthStatus.error:
            return location == '/auth-error' ? null : '/auth-error';
          case AuthStatus.ready:
            if (location == '/sign-in' ||
                location == '/loading' ||
                location == '/profile-missing' ||
                location == '/auth-error') {
              return '/';
            }
            if (_auth.isAdmin && _auth.selectedBranch == null) {
              return location == '/branch-setup' ? null : '/branch-setup';
            }
            if (location == '/branch-setup') return '/';
            if (location == '/access-denied') return null;
            final moduleName = state.pathParameters['name'];
            if (moduleName != null) {
              final permission = _modulePermissions[moduleName];
              if (permission != null && !_auth.can(permission)) {
                return '/access-denied';
              }
              if (permission == null &&
                  !_modulePermissions.containsKey(moduleName)) {
                return '/access-denied';
              }
            }
            final routePermission = _routePermissions[location];
            if (routePermission != null && !_auth.can(routePermission)) {
              return '/access-denied';
            }
            return null;
        }
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _auth == null
              ? const ConfigurationScreen()
              : const DashboardScreen(),
          routes: [
            GoRoute(
              path: 'module/:name',
              builder: (context, state) =>
                  _moduleScreen(state.pathParameters['name'] ?? ''),
            ),
          ],
        ),
        GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesScreen(),
        ),
        GoRoute(
          path: '/production',
          builder: (context, state) => const ProductionScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(path: '/cash', builder: (context, state) => const CashScreen()),
        GoRoute(
          path: '/people',
          builder: (context, state) => const PeopleScreen(),
        ),
        GoRoute(
          path: '/payroll',
          builder: (context, state) => const PayrollScreen(),
        ),
        GoRoute(
          path: '/rentals',
          builder: (context, state) => const RentalsScreen(),
        ),
        GoRoute(
          path: '/credit',
          builder: (context, state) => const CreditScreen(),
        ),
        GoRoute(
          path: '/approvals',
          builder: (context, state) => const ApprovalsScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => SignInScreen(client: widget.client!),
        ),
        GoRoute(
          path: '/loading',
          builder: (context, state) => const LoadingScreen(),
        ),
        GoRoute(
          path: '/profile-missing',
          builder: (context, state) => ProfileMissingScreen(controller: _auth!),
        ),
        GoRoute(
          path: '/branch-setup',
          builder: (context, state) => BranchSetupScreen(controller: _auth!),
        ),
        GoRoute(
          path: '/access-denied',
          builder: (context, state) => const AccessDeniedScreen(),
        ),
        GoRoute(
          path: '/auth-error',
          builder: (context, state) => AuthErrorScreen(
            error: _auth?.lastError,
            message: _auth?.errorMessage ?? '',
            onRetry: _auth?.retry ?? () async {},
            onSignOut: () => widget.client!.auth.signOut(),
          ),
        ),
      ],
    );
  }

  Widget _moduleScreen(String name) => switch (name) {
    'production' => const ProductionScreen(),
    'sales' => const SalesScreen(),
    'pos' => const PosScreen(),
    'inventory' => const InventoryScreen(),
    'cash' => const CashScreen(),
    'people' => const PeopleScreen(),
    'payroll' => const PayrollScreen(),
    'rentals' => const RentalsScreen(),
    'credit' => const CreditScreen(),
    'approvals' => const ApprovalsScreen(),
    'reports' => const ReportsScreen(),
    'notifications' => const NotificationsScreen(),
    'settings' => const SettingsScreen(),
    _ => const AccessDeniedScreen(),
  };

  @override
  void dispose() {
    _router.dispose();
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_auth == null) {
      return MaterialApp(
        title: Brand.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            OfflineBanner(child: child ?? const SizedBox.shrink()),
        home: const ConfigurationScreen(),
      );
    }
    return SessionScope(
      controller: _auth,
      child: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => MaterialApp.router(
          title: Brand.appName,
          onGenerateTitle: (context) => Brand.appName,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _auth.themeMode,
          locale: _auth.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => OfflineBanner(
            onReconnected: _auth.retry,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    this.size = 120,
    this.showName = true,
    this.light = false,
    super.key,
  });

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        Brand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: Brand.appName,
      ),
      if (showName) ...[
        const SizedBox(height: 10),
        Text(
          Brand.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: light
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Brand.slogan,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: light
                ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ],
  );
}

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 180),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).appNotConfigured,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  Object? _error;
  bool _checkingAccess = true;
  bool? _hasAdmin;
  bool _allowCustomerSignup = false;
  Object? _accessError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccess());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    if (mounted) {
      setState(() {
        _checkingAccess = true;
        _accessError = null;
      });
    }
    try {
      final adminResult = await widget.client.rpc('has_admin');
      final hasAdmin = _readBool(adminResult);
      if (hasAdmin == null) {
        throw const FormatException('has_admin returned no value');
      }
      var allowCustomerSignup = false;
      try {
        final row = await widget.client
            .from('app_settings')
            .select('value')
            .eq('key', 'allow_customer_signup')
            .maybeSingle();
        allowCustomerSignup = _readSettingBool(row?['value']);
      } catch (error, stack) {
        AppLogger.error('Could not read sign-up setting', error, stack);
      }
      if (!mounted) return;
      setState(() {
        _hasAdmin = hasAdmin;
        _allowCustomerSignup = allowCustomerSignup;
        _checkingAccess = false;
      });
    } catch (error, stack) {
      AppLogger.error('Could not check sign-up options', error, stack);
      if (!mounted) return;
      setState(() {
        _accessError = error;
        _checkingAccess = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error, stack) {
      AppLogger.error('Sign-in failed', error, stack);
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openSignUp({required bool firstAdmin}) async {
    final strings = AppLocalizations.of(context);
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignUpDialog(
        firstAdmin: firstAdmin,
        onSubmit: (data) async {
          final response = await widget.client.auth.signUp(
            email: data['email']!,
            password: data['password']!,
            data: {'full_name': data['name']!},
          );
          if (!firstAdmin && response.session != null) {
            await widget.client.auth.signOut();
          }
          if (response.session == null) {
            return strings.accountCreatedConfirmEmail;
          }
          return firstAdmin
              ? strings.accountCreatedSignIn
              : strings.accountCreatedAwaitAdmin;
        },
      ),
    );
    if (message == null || !mounted) return;
    showSnack(context, message);
    unawaited(_loadAccess());
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primary, scheme.surface],
            stops: const [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandMark(size: 148),
                          const SizedBox(height: 8),
                          Text(
                            strings.signInSubtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _email,
                            decoration: InputDecoration(
                              labelText: strings.email,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return strings.requiredField;
                              if (!_emailPattern.hasMatch(email)) {
                                return strings.errorInvalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: strings.password,
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            validator: (value) => value == null || value.isEmpty
                                ? strings.requiredField
                                : null,
                            onFieldSubmitted: (_) => _signIn(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            FriendlyErrorBox(error: _error!, onRetry: _signIn),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _signIn,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                _submitting
                                    ? strings.signingIn
                                    : strings.signIn,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_checkingAccess)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      strings.checkingAccountOptions,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_accessError != null)
                            FriendlyErrorBox(
                              error: _accessError!,
                              onRetry: _loadAccess,
                            )
                          else if (_hasAdmin == false)
                            TextButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _openSignUp(firstAdmin: true),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(strings.createFirstAccount),
                            )
                          else if (_hasAdmin == true && _allowCustomerSignup)
                            TextButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _openSignUp(firstAdmin: false),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(strings.createAccount),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                strings.contactAdminToGetAccount,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpDialog extends StatefulWidget {
  const _SignUpDialog({required this.firstAdmin, required this.onSubmit});

  final bool firstAdmin;
  final Future<String> Function(Map<String, String> data) onSubmit;

  @override
  State<_SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<_SignUpDialog> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await widget.onSubmit({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      if (mounted) Navigator.of(context).pop(message);
    } catch (error, stack) {
      AppLogger.error('Sign-up failed', error, stack);
      if (mounted) {
        setState(() {
          _error = error;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.firstAdmin
            ? strings.signUpFirstTitle
            : strings.signUpCustomerTitle,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: strings.fullName),
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => value == null || value.trim().isEmpty
                      ? strings.requiredField
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: strings.email),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return strings.requiredField;
                    if (!_emailPattern.hasMatch(email)) {
                      return strings.errorInvalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(labelText: strings.password),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => value == null || value.length < 8
                      ? strings.errorPasswordMin8
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirm,
                  decoration: InputDecoration(
                    labelText: strings.confirmPassword,
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => value != _password.text
                      ? strings.errorPasswordsDoNotMatch
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  FriendlyErrorBox(error: _error!),
                ],
                const SizedBox(height: 12),
                Text(
                  widget.firstAdmin
                      ? strings.signUpFirstHelp
                      : strings.signUpCustomerHelp,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(strings.creatingAccount),
                  ],
                )
              : Text(
                  widget.firstAdmin
                      ? strings.createFirstAccount
                      : strings.createAccount,
                ),
        ),
      ],
    );
  }
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == 't' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == 'f' || text == '0' || text == 'no') {
      return false;
    }
    return null;
  }
  if (value is Map) {
    for (final key in const ['has_admin', 'exists', 'result', 'value']) {
      if (value.containsKey(key)) {
        final parsed = _readBool(value[key]);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
  if (value is List && value.isNotEmpty) return _readBool(value.first);
  return null;
}

bool _readSettingBool(Object? value) {
  if (value is Map) {
    for (final key in const [
      'enabled',
      'allow',
      'allow_customer_signup',
      'signup',
      'value',
    ]) {
      if (value.containsKey(key)) {
        final parsed = _readBool(value[key]);
        if (parsed != null) return parsed;
      }
    }
    return false;
  }
  return _readBool(value) ?? false;
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: 160),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class ProfileMissingScreen extends StatelessWidget {
  const ProfileMissingScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(Brand.appName),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context).signOut,
          onPressed: controller.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 150),
              const SizedBox(height: 20),
              Text(
                controller.errorMessage ??
                    AppLocalizations.of(context).membershipRequired,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).contactAdminToGetAccount,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BranchSetupScreen extends StatefulWidget {
  const BranchSetupScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<BranchSetupScreen> createState() => _BranchSetupScreenState();
}

class _BranchSetupScreenState extends State<BranchSetupScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.createFirstBranch();
    } catch (error, stack) {
      AppLogger.error('Could not create the first branch', error, stack);
      if (mounted) {
        setState(() => _error = readableError(context, error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 150),
              const SizedBox(height: 20),
              const Text(
                'No active branch exists. Create the first branch to start '
                'using Brade and Cake House.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.add_business_outlined),
                label: Text(_saving ? 'Creating…' : 'Create main branch'),
              ),
              TextButton(
                onPressed: widget.controller.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Brand.appName)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).accessDenied,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(AppLocalizations.of(context).backToDashboard),
            ),
          ],
        ),
      ),
    ),
  );
}

class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
    this.error,
    super.key,
  });

  final Object? error;
  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 120),
                const SizedBox(height: 20),
                Text(strings.accessLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (error != null)
                  FriendlyErrorBox(error: error!, onRetry: onRetry)
                else
                  Text(
                    message.isEmpty ? strings.errorSomethingWentWrong : message,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: Text(strings.retry)),
                TextButton(onPressed: onSignOut, child: Text(strings.signOut)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
