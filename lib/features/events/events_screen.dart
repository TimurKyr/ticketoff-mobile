import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/health_service.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.healthStatusSource});

  final HealthStatusSource healthStatusSource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          HealthStatusCard(healthStatusSource: healthStatusSource),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/scan/demo-event'),
            child: const Text('Open scanner'),
          ),
          TextButton(
            onPressed: () => context.go('/attendees'),
            child: const Text('Attendees'),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}

class HealthStatusCard extends StatefulWidget {
  const HealthStatusCard({super.key, required this.healthStatusSource});

  final HealthStatusSource healthStatusSource;

  @override
  State<HealthStatusCard> createState() => _HealthStatusCardState();
}

class _HealthStatusCardState extends State<HealthStatusCard> {
  late Future<bool> _healthCheck;

  @override
  void initState() {
    super.initState();
    _healthCheck = widget.healthStatusSource.check();
  }

  void _retry() {
    setState(() {
      _healthCheck = widget.healthStatusSource.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: _healthCheck,
              builder: (context, snapshot) {
                final status = switch (snapshot.connectionState) {
                  ConnectionState.waiting => 'Checking...',
                  _ when snapshot.data == true => 'ok',
                  _ => 'unavailable',
                };
                return Row(
                  children: [
                    Expanded(child: Text(status, key: const Key('health-status'))),
                    IconButton(
                      onPressed: _retry,
                      tooltip: 'Retry health check',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
