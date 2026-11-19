import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_tone.dart';
import '../../presentation/widgets/empty_state.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/vehicles_screen.dart';
import '../../presentation/screens/vehicle_detail_screen.dart';
import '../../presentation/screens/vehicle_form_screen.dart';
import '../../presentation/screens/vehicle_history_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/search_screen.dart';
import '../../presentation/screens/fuel_charges_screen.dart';
import '../../presentation/screens/expense_dashboard_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/vehicles',
          pageBuilder: (context, state) {
            final provinceId = state.uri.queryParameters['provinceId'];
            return NoTransitionPage(
              child: VehiclesScreen(
                provinceId: provinceId != null
                    ? int.tryParse(provinceId)
                    : null,
              ),
            );
          },
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ExpenseDashboardScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/vehicle/new',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const VehicleFormScreen(),
    ),
    GoRoute(
      path: '/vehicle/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VehicleDetailScreen(
          vehicleId: id,
          highlightDocs: state.uri.queryParameters['highlight'] == 'docs',
        );
      },
    ),
    GoRoute(
      path: '/vehicle/:id/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VehicleFormScreen(vehicleId: id);
      },
    ),
    GoRoute(
      path: '/vehicle/:id/history',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VehicleHistoryScreen(vehicleId: id);
      },
    ),
    GoRoute(
      path: '/vehicle/:id/fuel',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return FuelChargesScreen(vehicleId: id);
      },
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
  ],
);

class _RouteErrorScreen extends StatelessWidget {
  final Exception? error;

  const _RouteErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: EmptyState(
          icon: Icons.error_rounded,
          title: 'No encontramos esa pantalla',
          actionLabel: 'Volver al inicio',
          onAction: () => context.go('/'),
          tone: Tone.danger,
        ),
      ),
    );
  }
}

/// Destino de la barra inferior: la acción de alta vive en el FAB de la
/// pestaña (no aparece en Gastos ni Ajustes).
class _Destination {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool showsAddVehicle;

  const _Destination(
    this.path,
    this.label,
    this.icon,
    this.selectedIcon, {
    this.showsAddVehicle = false,
  });
}

const _destinations = [
  _Destination(
    '/',
    'Inicio',
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
    showsAddVehicle: true,
  ),
  _Destination(
    '/vehicles',
    'Vehículos',
    Icons.directions_car_outlined,
    Icons.directions_car_rounded,
    showsAddVehicle: true,
  ),
  _Destination(
    '/expenses',
    'Gastos',
    Icons.payments_outlined,
    Icons.payments_rounded,
  ),
  _Destination(
    '/settings',
    'Ajustes',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
];

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _destinations.indexWhere(
      (destination) =>
          destination.path != '/' && location.startsWith(destination.path),
    );
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: _destinations[selected].showsAddVehicle
          ? FloatingActionButton.extended(
              tooltip: 'Agregar vehículo',
              onPressed: () => context.push('/vehicle/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Vehículo'),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) =>
              context.go(_destinations[index].path),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
