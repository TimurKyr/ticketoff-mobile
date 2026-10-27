import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/dio_client.dart';
import 'package:ticketoff_mobile/core/api/health_service.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/attendees/attendees_screen.dart';
import 'package:ticketoff_mobile/features/auth/login_screen.dart';
import 'package:ticketoff_mobile/features/events/events_screen.dart';
import 'package:ticketoff_mobile/features/scan/scan_screen.dart';

class TicketoffApp extends StatefulWidget {
  const TicketoffApp({super.key, this.healthStatusSource});

  final HealthStatusSource? healthStatusSource;

  @override
  State<TicketoffApp> createState() => _TicketoffAppState();
}

class _TicketoffAppState extends State<TicketoffApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/events',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => EventsScreen(
          healthStatusSource: widget.healthStatusSource ?? _healthService,
        ),
      ),
      GoRoute(
        path: '/scan/:eventId',
        builder: (context, state) =>
            ScanScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/attendees',
        builder: (context, state) => const AttendeesScreen(),
      ),
    ],
  );

  late final DioClient _dioClient = DioClient(
    onUnauthorized: () async => _router.go('/login'),
  );
  late final HealthService _healthService = HealthService(_dioClient.dio);

  @override
  void dispose() {
    _router.dispose();
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
