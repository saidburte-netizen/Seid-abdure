import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

/// The top-level routes that keep the persistent bottom navigation visible.
///
/// Detail pages, forms and dialogs deliberately do not appear here: they are
/// reached from a hub screen and must keep the whole viewport for their work.
const Set<String> appHubRoutes = {
  '/',
  '/pos',
  '/sales',
  '/production',
  '/inventory',
  '/products',
  '/stock',
  '/cash',
  '/people',
  '/payroll',
  '/rentals',
  '/credit',
  '/approvals',
  '/reports',
  '/notifications',
};

/// A Nexa-style bottom bar that keeps the four daily tasks one tap away.
///
/// The fifth destination opens the searchable module list, so every screen in
/// the app remains reachable without returning to the dashboard first.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.currentPath,
    required this.onMore,
    super.key,
  });

  final String currentPath;
  final VoidCallback onMore;

  static const _destinations = <(String, IconData, IconData)>[
    ('/', Icons.home_outlined, Icons.home),
    ('/pos', Icons.point_of_sale_outlined, Icons.point_of_sale),
    ('/stock', Icons.warehouse_outlined, Icons.warehouse),
    ('/reports', Icons.bar_chart_outlined, Icons.bar_chart),
  ];

  int get _selectedIndex {
    final index = _destinations.indexWhere((item) => item.$1 == currentPath);
    return index < 0 ? _destinations.length : index;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final labels = [
      strings.home,
      strings.newSale,
      strings.stockModule,
      strings.reportsModule,
      strings.more,
    ];
    return NavigationBar(
      key: const Key('app-bottom-nav'),
      selectedIndex: _selectedIndex,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) {
        if (index >= _destinations.length) {
          onMore();
          return;
        }
        final route = _destinations[index].$1;
        if (route == currentPath) return;
        context.go(route);
      },
      destinations: [
        for (var index = 0; index < labels.length; index++)
          NavigationDestination(
            key: Key('nav-${_destinationName(index)}'),
            icon: Icon(
              index < _destinations.length
                  ? _destinations[index].$2
                  : Icons.apps_outlined,
            ),
            selectedIcon: Icon(
              index < _destinations.length
                  ? _destinations[index].$3
                  : Icons.apps,
            ),
            label: labels[index],
          ),
      ],
    );
  }

  static String _destinationName(int index) => switch (index) {
    0 => 'home',
    1 => 'sell',
    2 => 'stock',
    3 => 'reports',
    _ => 'more',
  };
}
