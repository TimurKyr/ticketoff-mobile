class AssignedEvent {
  const AssignedEvent({
    required this.id,
    required this.title,
    required this.status,
    required this.startAt,
    this.endAt,
    this.venueName,
    this.venueAddress,
    this.venueCity,
    this.venueMessage,
  });

  factory AssignedEvent.fromJson(Map<String, dynamic> json) {
    final endAt = json['end_at'];
    if (endAt != null && endAt is! String) {
      throw const FormatException('Invalid "end_at" in event response');
    }

    return AssignedEvent(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      status: _requiredString(json, 'status'),
      startAt: DateTime.parse(_requiredString(json, 'start_at')),
      endAt: endAt == null ? null : DateTime.parse(endAt),
    );
  }

  final String id;
  final String title;
  final String status;
  final DateTime startAt;
  final DateTime? endAt;
  final String? venueName;
  final String? venueAddress;
  final String? venueCity;
  final String? venueMessage;

  String? get venueLabel {
    final parts = [
      venueName,
      venueAddress,
      venueCity,
    ].whereType<String>().where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  AssignedEvent withVenue(Map<String, dynamic> venue) {
    return AssignedEvent(
      id: id,
      title: title,
      status: status,
      startAt: startAt,
      endAt: endAt,
      venueName: venue['name'] as String?,
      venueAddress: venue['address'] as String?,
      venueCity: venue['city'] as String?,
    );
  }

  AssignedEvent withVenueMessage(String message) {
    return AssignedEvent(
      id: id,
      title: title,
      status: status,
      startAt: startAt,
      endAt: endAt,
      venueMessage: message,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing or invalid "$key" in event response');
    }
    return value;
  }
}
