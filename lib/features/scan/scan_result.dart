enum ScanOutcome {
  checkedIn('checked_in', 'Вход разрешён'),
  alreadyUsed('already_used', 'Уже использован'),
  invalid('invalid', 'Недействителен'),
  wrongEvent('wrong_event', 'Другое событие'),
  campaignQrRejected('campaign_qr_rejected', 'Это промо-код, не билет'),
  cancelled('cancelled', 'Билет отменён'),
  refunded('refunded', 'Билет возвращён'),
  eventCancelled('event_cancelled', 'Событие отменено');

  const ScanOutcome(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class CheckinCount {
  const CheckinCount(this.checkedIn, this.total);

  final int checkedIn;
  final int total;
}

class ScanResult {
  final ScanOutcome outcome;
  final CheckinCount count;
  final String? attendeeName;
  final String? ticketType;

  const ScanResult({
    required this.outcome,
    required this.count,
    this.attendeeName,
    this.ticketType,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final outcome = ScanOutcome.values
        .where((outcome) => outcome.apiValue == json['result'])
        .firstOrNull;
    final checkedIn = json['checked_in_count'];
    final total = json['total_count'];
    final ticket = json['ticket'];
    if (outcome == null || checkedIn is! int || total is! int) {
      throw const FormatException('Invalid check-in response');
    }
    if (outcome == ScanOutcome.checkedIn &&
        (ticket is! Map<String, dynamic> ||
            ticket['attendee_name'] is! String ||
            ticket['ticket_type'] is! String)) {
      throw const FormatException('Missing scanned ticket details');
    }
    return ScanResult(
      outcome: outcome,
      count: CheckinCount(checkedIn, total),
      attendeeName: _ticketField(ticket, 'attendee_name'),
      ticketType: _ticketField(ticket, 'ticket_type'),
    );
  }

  static String? _ticketField(Object? ticket, String key) {
    final value = ticket is Map<String, dynamic> ? ticket[key] : null;
    return value is String ? value : null;
  }
}
