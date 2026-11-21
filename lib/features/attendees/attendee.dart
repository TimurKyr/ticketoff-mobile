enum TicketStatus {
  valid('Действителен'),
  checkedIn('Отмечен'),
  cancelled('Отменён'),
  refunded('Возвращён'),
  unknown('Неизвестный статус');

  const TicketStatus(this.label);

  final String label;

  static TicketStatus fromJson(Object? value) => switch (value) {
    'valid' => valid,
    'checked_in' => checkedIn,
    'cancelled' => cancelled,
    'refunded' => refunded,
    String() => unknown,
    _ => throw const FormatException('Invalid ticket status'),
  };
}

class Attendee {
  const Attendee({
    required this.ticketId,
    required this.name,
    this.email,
    required this.ticketType,
    required this.status,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    final id = json['ticket_id'];
    final name = json['attendee_name'];
    final email = json['attendee_email'];
    final type = json['ticket_type'];
    if (id is! String ||
        name is! String ||
        (email != null && email is! String) ||
        type is! String) {
      throw const FormatException('Invalid attendee');
    }
    return Attendee(
      ticketId: id,
      name: name,
      email: email as String?,
      ticketType: type,
      status: TicketStatus.fromJson(json['status']),
    );
  }

  final String ticketId;
  final String name;
  final String? email;
  final String ticketType;
  final TicketStatus status;

  Attendee withStatus(TicketStatus status) => Attendee(
    ticketId: ticketId,
    name: name,
    email: email,
    ticketType: ticketType,
    status: status,
  );
}

class AttendeePage {
  const AttendeePage({required this.items, required this.nextOffset});

  final List<Attendee> items;
  final int? nextOffset;
}

class EventStats {
  const EventStats({
    required this.registered,
    required this.checkedIn,
    required this.percent,
  });

  final int registered;
  final int checkedIn;
  final num percent;
}
