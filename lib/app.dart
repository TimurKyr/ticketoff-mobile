import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/api/dio_client.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/attendees/attendees_screen.dart';
import 'package:ticketoff_mobile/features/auth/login_screen.dart';
import 'package:ticketoff_mobile/features/auth/role_selection_screen.dart';
import 'package:ticketoff_mobile/features/events/events_screen.dart';
import 'package:ticketoff_mobile/features/scan/scan_screen.dart';

class TicketoffApp extends StatefulWidget {
  const TicketoffApp({super.key, this.authGateway, this.eventsRepository});

  final AuthGateway? authGateway;
  final AssignedEventsRepository? eventsRepository;

  @override
  State<TicketoffApp> createState() => _TicketoffAppState();
}

class _TicketoffAppState extends State<TicketoffApp> {
  final ValueNotifier<bool?> _isAuthenticated = ValueNotifier(null);
  String? _sessionRestoreError;

  late final SecureStorage _secureStorage = SecureStorage();
  late final DioClient _dioClient = DioClient(
    secureStorage: _secureStorage,
    onUnauthorized: _handleUnauthorized,
  );
  late final AuthGateway _authGateway =
      widget.authGateway ?? AuthService(_dioClient.dio, _secureStorage);
  late final AssignedEventsRepository _eventsRepository =
      widget.eventsRepository ?? CheckinService(_dioClient.dio);

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: _isAuthenticated,
    redirect: (context, state) {
      final authenticated = _isAuthenticated.value;
      final isPublicRoute =
          state.matchedLocation == '/' || state.matchedLocation == '/login';
      if (authenticated == null) return isPublicRoute ? null : '/';
      if (!authenticated && !isPublicRoute) return '/';
      if (authenticated && isPublicRoute) return '/events';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ValueListenableBuilder<bool?>(
          valueListenable: _isAuthenticated,
          builder: (context, authenticated, child) {
            if (_sessionRestoreError != null) {
              return _SessionRestoreError(
                message: _sessionRestoreError!,
                onRetry: _retrySessionRestore,
              );
            }
            if (authenticated == null) {
              return const _SessionLoadingScreen();
            }
            return const RoleSelectionScreen();
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          authGateway: _authGateway,
          onAuthenticated: () => _isAuthenticated.value = true,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (context, state) => EventsScreen(
                  eventsRepository: _eventsRepository,
                  onLogout: _logout,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => ScanScreen(onLogout: _logout),
                routes: [
                  GoRoute(
                    path: ':eventId',
                    builder: (context, state) => ScanScreen(
                      eventId: state.pathParameters['eventId']!,
                      onLogout: _logout,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/attendees',
                builder: (context, state) => AttendeesScreen(onLogout: _logout),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    _sessionRestoreError = null;
    try {
      final hasSession = await _authGateway.hasSession();
      if (mounted) _isAuthenticated.value = hasSession;
    } on SessionFailure catch (error) {
      if (!mounted) return;
      _sessionRestoreError = error.message;
      _isAuthenticated.value = false;
    }
  }

  void _retrySessionRestore() {
    _isAuthenticated.value = null;
    _restoreSession();
  }

  Future<void> _logout() async {
    await _authGateway.logout();
    _isAuthenticated.value = false;
    _router.go('/');
  }

  Future<void> _handleUnauthorized() async {
    _isAuthenticated.value = false;
    _router.go('/login');
  }

  @override
  void dispose() {
    _router.dispose();
    _isAuthenticated.dispose();
    _dioClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ticketoff',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

class AdminNavigationShell extends StatelessWidget {
  const AdminNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Мероприятия',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Сканер',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Участники',
          ),
        ],
      ),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SessionRestoreError extends StatelessWidget {
  const _SessionRestoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}
