import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.eventsRepository,
    required this.onLogout,
  });

  final AssignedEventsRepository eventsRepository;
  final Future<void> Function() onLogout;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<AssignedEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = widget.eventsRepository.fetchMyEvents();
  }

  void _retry() {
    setState(() {
      _events = widget.eventsRepository.fetchMyEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мероприятия'),
        actions: [LogoutAction(onLogout: widget.onLogout)],
      ),
      body: SafeArea(
        child: FutureBuilder<List<AssignedEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(key: Key('events-loading')),
              );
            }
            if (snapshot.hasError) {
              final message = snapshot.error is EventLoadFailure
                  ? (snapshot.error! as EventLoadFailure).message
                  : 'Не удалось загрузить назначенные события';
              return _MessageState(
                icon: Icons.cloud_off_outlined,
                message: message,
                action: TextButton(
                  onPressed: _retry,
                  child: const Text('Повторить'),
                ),
              );
            }

            final events = snapshot.data ?? const <AssignedEvent>[];
            if (events.isEmpty) {
              return const _MessageState(
                icon: Icons.event_busy_outlined,
                message: 'Вас пока не назначили ни на одно событие',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _EventCard(event: events[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final AssignedEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('assigned-event-${event.id}'),
        onTap: () => context.go('/scan/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppTheme.muted,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EventDetail(
                icon: Icons.calendar_today_outlined,
                text: _formatDate(event.startAt),
              ),
              const SizedBox(height: 8),
              _EventDetail(
                icon: Icons.location_on_outlined,
                text:
                    event.venueLabel ??
                    event.venueMessage ??
                    'Площадка не указана',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brandDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppTheme.muted)),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.brandDeep),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
