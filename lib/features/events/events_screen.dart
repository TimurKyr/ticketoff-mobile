import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/l10n/language_selector.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_checkin.dart';
import 'package:ticketoff_mobile/features/offline/offline_status.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.eventsRepository,
    required this.onLogout,
    this.offline,
    this.activeEventId,
  });

  final AssignedEventsRepository eventsRepository;
  final Future<void> Function() onLogout;
  final OfflineCheckin? offline;
  final String? activeEventId;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<AssignedEvent>> _events;
  String? _lastEventId;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _lastEventId = widget.activeEventId;
    _events = widget.eventsRepository.fetchMyEvents();
    _wasOffline = widget.offline?.isOffline ?? false;
    widget.offline?.addListener(_connectionChanged);
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastEventId = widget.activeEventId ?? _lastEventId;
  }

  @override
  void dispose() {
    widget.offline?.removeListener(_connectionChanged);
    super.dispose();
  }

  void _connectionChanged() {
    final offline = widget.offline!.isOffline;
    final recovered = _wasOffline && !offline;
    _wasOffline = offline;
    if (recovered) _retry();
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
        title: Text(context.t(AppText.events)),
        actions: [
          const LanguageSelector(),
          LogoutAction(onLogout: widget.onLogout),
        ],
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
                  ? context.localizedMessage(
                      (snapshot.error! as EventLoadFailure).message,
                    )
                  : context.t(AppText.loadAssignedEvents);
              return _MessageState(
                icon: Icons.cloud_off_outlined,
                message: message,
                action: TextButton(
                  onPressed: _retry,
                  child: Text(context.t(AppText.retry)),
                ),
              );
            }

            final events = snapshot.data ?? const <AssignedEvent>[];
            if (events.isEmpty) {
              return _MessageState(
                icon: Icons.event_busy_outlined,
                message: widget.offline?.isOffline == true
                    ? context.t(AppText.noOfflineEvents)
                    : context.t(AppText.noAssignedEvents),
              );
            }

            final lastEvent = events
                .where((event) => event.id == _lastEventId)
                .firstOrNull;
            return Column(
              children: [
                if (lastEvent != null) _PinnedEvent(event: lastEvent),
                Expanded(
                  child: ListView.separated(
                    key: const Key('assigned-events-list'),
                    padding: const EdgeInsets.all(20),
                    itemCount: events.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) => _EventCard(
                      event: events[index],
                      offline: widget.offline,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinnedEvent extends StatelessWidget {
  const _PinnedEvent({required this.event});

  final AssignedEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pinned-event'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Card(
        child: ListTile(
          title: Text(context.t(AppText.recentEvent)),
          subtitle: Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: context.t(AppText.recentEventScanner),
                onPressed: () => _openEvent(context, event, 'scan'),
                icon: const Icon(Icons.qr_code_scanner),
              ),
              IconButton(
                tooltip: context.t(AppText.recentEventAttendees),
                onPressed: () => _openEvent(context, event, 'attendees'),
                icon: const Icon(Icons.people_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openEvent(BuildContext context, AssignedEvent event, String screen) {
  context.go('/events/${Uri.encodeComponent(event.id)}/$screen');
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.offline});

  final AssignedEvent event;
  final OfflineCheckin? offline;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('assigned-event-${event.id}'),
        onTap: () => _openEvent(context, event, 'scan'),
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
                    context.t(AppText.noVenue),
              ),
              if (offline case final controller?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OfflineStatus(
                    offline: controller,
                    eventId: event.id,
                    downloadEvent: event,
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: Key('event-guests-${event.id}'),
                  onPressed: () => _openEvent(context, event, 'attendees'),
                  icon: const Icon(Icons.people_outline),
                  label: Text(context.t(AppText.eventAttendees)),
                ),
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
