import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:ticketoff_mobile/features/guest/guest_screen.dart';
import 'package:ticketoff_mobile/features/offline/offline_checkin.dart';
import 'package:ticketoff_mobile/features/offline/offline_store.dart';
import 'package:ticketoff_mobile/features/scan/scan_screen.dart';

class TicketoffApp extends StatefulWidget {
  const TicketoffApp({
    super.key,
    this.authGateway,
    this.eventsRepository,
    this.scanRepository,
    this.attendeesRepository,
  });

  final AuthGateway? authGateway;
  final AssignedEventsRepository? eventsRepository;
  final ScanRepository? scanRepository;
  final AttendeesRepository? attendeesRepository;

  @override
  State<TicketoffApp> createState() => _TicketoffAppState();
}

class _TicketoffAppState extends State<TicketoffApp>
    with WidgetsBindingObserver {
  final ValueNotifier<bool?> _isAuthenticated = ValueNotifier(null);
  String? _sessionRestoreError;
  OfflineCheckin? _offline;
  late final _offlineStore = OfflineStore();

  late final SecureStorage _secureStorage = SecureStorage();
  late final DioClient _dioClient = DioClient(
    secureStorage: _secureStorage,
    onUnauthorized: _handleUnauthorized,
  );
  late final AuthGateway _authGateway =
      widget.authGateway ?? AuthService(_dioClient.dio, _secureStorage);
  late final AssignedEventsRepository _eventsRepository =
      widget.eventsRepository ?? _checkinService;
  late final CheckinService _checkinService = CheckinService(_dioClient.dio);
  late final ScanRepository _scanRepository =
      widget.scanRepository ?? _checkinService;
  late final AttendeesRepository _attendeesRepository =
      widget.attendeesRepository ?? _checkinService;

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: _isAuthenticated,
    redirect: (context, state) {
      if (state.matchedLocation == '/guest') return null;
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
      GoRoute(path: '/guest', builder: (context, state) => const GuestScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          authGateway: _authGateway,
          onAuthenticated: _finishAuthentication,
        ),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => EventsScreen(
          eventsRepository: _offline ?? _eventsRepository,
          offline: _offline,
          onLogout: _logout,
          activeEventId: state.pathParameters['eventId'],
        ),
        routes: [
          GoRoute(
            path: ':eventId/scan',
            builder: (context, state) => ScanScreen(
              key: ValueKey(state.pathParameters['eventId']),
              eventId: state.pathParameters['eventId']!,
              repository: _offline ?? _scanRepository,
              offline: _offline,
              onLogout: _logout,
            ),
          ),
          GoRoute(
            path: ':eventId/attendees',
            builder: (context, state) => AttendeesScreen(
              key: ValueKey(state.pathParameters['eventId']),
              eventId: state.pathParameters['eventId']!,
              repository: _attendeesRepository,
              onLogout: _logout,
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    _sessionRestoreError = null;
    try {
      final hasSession = await _authGateway.hasSession();
      if (!mounted) return;
      if (hasSession) {
        await _finishAuthentication();
      } else {
        _isAuthenticated.value = false;
      }
    } on SessionFailure catch (error) {
      if (!mounted) return;
      _sessionRestoreError = error.message;
      _isAuthenticated.value = false;
    }
  }

  Future<void> _finishAuthentication() async {
    if (widget.authGateway == null &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        final token = await _secureStorage.readToken();
        if (!mounted) return;
        if (token != null && token.isNotEmpty) {
          _offline ??= OfflineCheckin(
            account: OfflineCheckin.accountKey(
              _dioClient.dio.options.baseUrl,
              token,
            ),
            dio: _dioClient.dio,
            store: _offlineStore,
            scans: _scanRepository,
            assignedEvents: _eventsRepository,
          );
        }
      } on PlatformException {
        throw const SessionFailure(
          'Не удалось восстановить сохранённую сессию',
        );
      }
    }
    if (mounted) _isAuthenticated.value = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _offline?.setForeground(state == AppLifecycleState.resumed);
  }

  void _retrySessionRestore() {
    _isAuthenticated.value = null;
    _restoreSession();
  }

  Future<void> _logout() async {
    await _authGateway.logout();
    _endOfflineSession();
    _isAuthenticated.value = false;
    _router.go('/');
  }

  Future<void> _handleUnauthorized() async {
    _endOfflineSession();
    _isAuthenticated.value = false;
    _router.go('/login');
  }

  void _endOfflineSession() {
    _offline?.dispose();
    _offline = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _endOfflineSession();
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
