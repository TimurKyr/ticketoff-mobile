import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/attendees/attendee.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class AttendeesScreen extends StatefulWidget {
  const AttendeesScreen({
    super.key,
    required this.eventId,
    required this.repository,
    required this.onLogout,
  });

  final String eventId;
  final AttendeesRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  final _scroll = ScrollController();
  final _items = <Attendee>[];
  Timer? _searchDelay;
  String _query = '';
  int _searchVersion = 0;
  int? _nextOffset = 0;
  bool _loading = false;
  bool _visible = false;
  String? _listError;
  String? _pendingTicketId;
  Future<EventStats>? _stats;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNearEnd);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _refresh();
    _visible = visible;
  }

  void _refresh() {
    _refreshStats();
    _resetSearch(_query);
  }

  void _refreshStats() {
    final stats = widget.repository.fetchStats(widget.eventId);
    setState(() {
      _stats = stats;
    });
  }

  void _resetSearch(String query, {bool debounce = false}) {
    _searchDelay?.cancel();
    _searchDelay = null;
    setState(() {
      _query = query;
      _searchVersion++;
      _nextOffset = 0;
      _items.clear();
      _listError = null;
      _loading = false;
    });
    if (debounce) {
      _searchDelay = Timer(const Duration(milliseconds: 300), () {
        _searchDelay = null;
        unawaited(_loadPage());
      });
    } else {
      unawaited(_loadPage());
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _loadNearEnd() {
    if (_visible &&
        _listError == null &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 240) {
      unawaited(_loadPage());
    }
  }

  Future<void> _loadPage() async {
    final offset = _nextOffset;
    if (_loading || _searchDelay != null || offset == null) return;
    final version = _searchVersion;
    setState(() {
      _loading = true;
      _listError = null;
    });

    try {
      final page = await widget.repository.fetchAttendees(
        widget.eventId,
        query: _query,
        offset: offset,
      );
      if (!mounted || version != _searchVersion) return;
      final loadedIds = _items.map((item) => item.ticketId).toSet();
      setState(() {
        _items.addAll(page.items.where((item) => loadedIds.add(item.ticketId)));
        _nextOffset = page.nextOffset;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && version == _searchVersion) _loadNearEnd();
      });
    } on AttendeesFailure catch (error) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _listError = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _changeCheckIn(Attendee attendee) async {
    if (_pendingTicketId != null) return;
    final undo = attendee.status == TicketStatus.checkedIn;
    final action = undo ? 'Отменить отметку' : 'Отметить вход';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action?'),
        content: Text(
          undo
              ? '${attendee.name} сможет снова пройти по этому билету.'
              : '${attendee.name} · ${attendee.ticketType}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _pendingTicketId != null) return;
    setState(() => _pendingTicketId = attendee.ticketId);

    try {
      final status = undo
          ? await widget.repository.undoCheckIn(attendee.ticketId)
          : await _checkIn(attendee.ticketId);
      if (!mounted) return;
      if (status != null) _updateTicketStatus(attendee.ticketId, status);
      _refreshStats();
    } on AttendeesFailure catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: 'Повторить',
            onPressed: () {
              // The server may have applied the change before the connection
              // dropped. Read the current status before another mutation.
              if (mounted) _refresh();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingTicketId = null);
    }
  }

  Future<TicketStatus?> _checkIn(String ticketId) async {
    final result = await widget.repository.checkInTicket(ticketId);
    if (!mounted) return null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.outcome.label)));
    return switch (result.outcome) {
      ScanOutcome.checkedIn ||
      ScanOutcome.alreadyUsed => TicketStatus.checkedIn,
      ScanOutcome.cancelled => TicketStatus.cancelled,
      ScanOutcome.refunded => TicketStatus.refunded,
      _ => null,
    };
  }

  void _updateTicketStatus(String ticketId, TicketStatus status) {
    final index = _items.indexWhere((item) => item.ticketId == ticketId);
    if (index != -1) {
      setState(() => _items[index] = _items[index].withStatus(status));
    } else if (_loading) {
      // A page requested before the change may still contain the old status.
      _resetSearch(_query);
    }
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Гости'),
        actions: [
          IconButton(
            tooltip: 'Открыть сканер события',
            onPressed: () =>
                context.go('/events/${Uri.encodeComponent(eventId)}/scan'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          LogoutAction(onLogout: widget.onLogout),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            FutureBuilder<EventStats>(
              future: _stats,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return _RetryNotice(
                    message: (snapshot.error! as AttendeesFailure).message,
                    onRetry: _refreshStats,
                  );
                }
                final stats = snapshot.data;
                return stats == null
                    ? const SizedBox.shrink()
                    : _StatsPanel(stats: stats);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const Key('attendees-search'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Имя или email',
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: (value) =>
                    _resetSearch(value.trim(), debounce: true),
                onSubmitted: (value) => _resetSearch(value.trim()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('attendees-list'),
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) return _listFooter();
                  final attendee = _items[index];
                  return _AttendeeCard(
                    attendee: attendee,
                    pending: _pendingTicketId == attendee.ticketId,
                    onAction: _pendingTicketId == null
                        ? () => _changeCheckIn(attendee)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listFooter() {
    if (_listError case final message?) {
      return _RetryNotice(message: message, onRetry: _loadPage);
    }
    if (_loading || _searchDelay != null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _query.isEmpty ? 'На событии пока нет гостей' : 'Гости не найдены',
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    final percent = stats.percent
        .toStringAsFixed(stats.percent % 1 == 0 ? 0 : 1)
        .replaceAll('.', ',');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text('Зарегистрировано\n${stats.registered}')),
            Expanded(child: Text('Отмечено\n${stats.checkedIn}')),
            Text('$percent%', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  const _AttendeeCard({
    required this.attendee,
    required this.pending,
    required this.onAction,
  });

  final Attendee attendee;
  final bool pending;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final status = attendee.status;
    final canUndo = status == TicketStatus.checkedIn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(attendee.name, style: Theme.of(context).textTheme.titleMedium),
            if (attendee.email case final email? when email.isNotEmpty)
              Text(email),
            Text('${attendee.ticketType} · ${attendee.status.label}'),
            if (status == TicketStatus.valid || canUndo)
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(canUndo ? Icons.undo : Icons.how_to_reg_outlined),
                label: Text(
                  pending
                      ? 'Сохраняем…'
                      : canUndo
                      ? 'Отменить отметку'
                      : 'Отметить вход',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RetryNotice extends StatelessWidget {
  const _RetryNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
