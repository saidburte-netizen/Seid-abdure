import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_controller.dart';
import 'l10n/app_localizations.dart';
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

  static const _modulePermissions = {
    'production': 'production.read',
    'sales': 'sales.read',
    'inventory': 'inventory.read',
    'cash': 'cash.read',
    'people': 'people.read',
    'rentals': 'rentals.read',
    'reports': 'reports.read',
    'settings': 'settings.manage',
  };

  @override
  void initState() {
    super.initState();
    _auth = widget.client == null ? null : AuthController(widget.client!);
    _router = GoRouter(
      refreshListenable: _auth,
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
            final moduleName = state.pathParameters['name'];
            if (moduleName != null) {
              final permission = _modulePermissions[moduleName];
              if (permission == null || !_auth.canAccess(permission)) {
                return '/access-denied';
              }
            }
            return null;
        }
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _auth == null
              ? const ConfigurationScreen()
              : DashboardScreen(
                  onSignOut: () => widget.client!.auth.signOut(),
                ),
          routes: [
            GoRoute(
              path: 'module/:name',
              builder: (context, state) => ModuleScreen(
                name: state.pathParameters['name']!,
              ),
            ),
          ],
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
          builder: (context, state) => MembershipRequiredScreen(
            onSignOut: () => widget.client!.auth.signOut(),
          ),
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

  @override
  void dispose() {
    _router.dispose();
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      );
}

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.of(context).configurationRequired),
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.signIn)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(labelText: strings.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(labelText: strings.password),
                    obscureText: true,
                    validator: (value) => value == null || value.isEmpty
                        ? strings.requiredField
                        : null,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _signIn,
                    child: Text(strings.signIn),
                  ),
                ],
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
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class MembershipRequiredScreen extends StatelessWidget {
  const MembershipRequiredScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context).signOut,
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.of(context).membershipRequired),
          ),
        ),
      );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.of(context).accessDenied),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppLocalizations.of(context).accessLoadFailed}\n$message',
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
      );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;

  static const _modules = [
    ('production', Icons.bakery_dining),
    ('sales', Icons.point_of_sale),
    ('inventory', Icons.inventory_2),
    ('cash', Icons.account_balance_wallet),
    ('people', Icons.groups),
    ('rentals', Icons.apartment),
    ('reports', Icons.bar_chart),
    ('settings', Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000 ? 4 : width >= 600 ? 3 : 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.signOut,
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: GridView.count(
            padding: const EdgeInsets.all(20),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final (name, icon) in _modules)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.go('/module/$name'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 38,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(_moduleTitle(strings, name)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_moduleTitle(strings, name))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.moduleSetupMessage),
        ),
      ),
    );
  }
}

String _moduleTitle(AppLocalizations strings, String name) => switch (name) {
      'production' => strings.production,
      'sales' => strings.sales,
      'inventory' => strings.inventory,
      'cash' => strings.cashManagement,
      'people' => strings.people,
      'rentals' => strings.rentals,
      'reports' => strings.reports,
      'settings' => strings.settings,
      _ => strings.appTitle,
    };
