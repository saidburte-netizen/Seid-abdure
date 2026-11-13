import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_controller.dart';
import 'brand/brand.dart';
import 'l10n/app_localizations.dart';
import 'screens/cash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/people_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/production_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/payables_screen.dart';
import 'screens/rentals_screen.dart';
import 'screens/reports_screen.dart';
import 'theme/app_theme.dart';

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
    '/pos': 'sales.write',
    '/sales': 'sales.read',
    '/production': 'production.read',
    '/inventory': 'inventory.read',
    '/cash': 'cash.read',
    '/people': 'people.read',
    '/payroll': 'payroll.read',
    '/rentals': 'rentals.read',
    '/payables': 'payables.read',
    '/reports': 'reports.read',
    '/settings': 'settings.manage',
  };

  static const _modulePermissions = {
    'production': 'production.read',
    'sales': 'sales.read',
    'pos': 'sales.write',
    'inventory': 'inventory.read',
    'cash': 'cash.read',
    'people': 'people.read',
    'payroll': 'payroll.read',
    'rentals': 'rentals.read',
    'payables': 'payables.read',
    'reports': 'reports.read',
    'notifications': 'notifications.read',
    'settings': 'settings.manage',
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
            return location == '/onboarding' ? null : '/onboarding';
          case AuthStatus.error:
            return location == '/auth-error' ? null : '/auth-error';
          case AuthStatus.ready:
            if (location == '/sign-in' ||
                location == '/loading' ||
                location == '/onboarding' ||
                location == '/auth-error') {
              return '/';
            }
            if (location == '/access-denied') return null;
            final moduleName = state.pathParameters['name'];
            if (moduleName != null) {
              if (moduleName == 'notifications') return null;
              final permission = _modulePermissions[moduleName];
              if (permission == null || !_auth.can(permission)) {
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
          path: '/payables',
          builder: (context, state) => const PayablesScreen(),
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
          path: '/onboarding',
          builder: (context, state) =>
              MembershipRequiredScreen(controller: _auth!),
        ),
        GoRoute(
          path: '/access-denied',
          builder: (context, state) => const AccessDeniedScreen(),
        ),
        GoRoute(
          path: '/auth-error',
          builder: (context, state) => AuthErrorScreen(
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
    'payables' => const PayablesScreen(),
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
                AppLocalizations.of(context).configurationRequired,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Build with --dart-define=SUPABASE_URL=... '
                '--dart-define=SUPABASE_ANON_KEY=...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (exception) {
      if (mounted) setState(() => _errorMessage = exception.message);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? strings.requiredField
                                : null,
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: scheme.error),
                            ),
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

class MembershipRequiredScreen extends StatefulWidget {
  const MembershipRequiredScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<MembershipRequiredScreen> createState() =>
      _MembershipRequiredScreenState();
}

class _MembershipRequiredScreenState extends State<MembershipRequiredScreen> {
  bool _claiming = false;
  String? _error;

  Future<void> _claim() async {
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      await widget.controller.bootstrapOwner();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(Brand.appName),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context).signOut,
          onPressed: widget.controller.signOut,
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
                AppLocalizations.of(context).membershipRequired,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).claimOwnerHelp,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _claiming ? null : _claim,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  _claiming
                      ? AppLocalizations.of(context).claiming
                      : AppLocalizations.of(context).claimOwner,
                ),
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
    super.key,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
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
              Text(
                '${AppLocalizations.of(context).accessLoadFailed}\n$message',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retry),
              ),
              TextButton(
                onPressed: onSignOut,
                child: Text(AppLocalizations.of(context).signOut),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
