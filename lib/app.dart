import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
      routes: [
        GoRoute(
          path: 'module/:name',
          builder: (context, state) => ModuleScreen(
            name: state.pathParameters['name']!,
          ),
        ),
      ],
    ),
  ],
);

class BakeryApp extends StatelessWidget {
  const BakeryApp({super.key});

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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
      appBar: AppBar(title: Text(strings.appTitle)),
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
                        Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
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
