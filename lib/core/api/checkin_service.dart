import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';

abstract interface class AssignedEventsRepository {
  Future<List<AssignedEvent>> fetchMyEvents();
}

class EventLoadFailure implements Exception {
  const EventLoadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class CheckinService implements AssignedEventsRepository {
  const CheckinService(this._dio);

  final Dio _dio;

  @override
  Future<List<AssignedEvent>> fetchMyEvents() async {
    try {
      final response = await _dio.get<Object?>('/checkin/my-events');
      final data = response.data;
      if (data is! List) {
        throw const EventLoadFailure(
          'Сервер вернул некорректный список событий',
        );
      }

      final events = data
          .map((item) => AssignedEvent.fromJson(_asJsonMap(item, 'event')))
          .toList(growable: false);
      if (events.isEmpty) return events;

      final Response<Object?> venuesResponse;
      try {
        venuesResponse = await _dio.get<Object?>('/venues');
      } on DioException catch (error) {
        if (error.response?.statusCode == 401) rethrow;
        return events
            .map(
              (event) => event.withVenueMessage(
                'Не удалось загрузить информацию о площадке',
              ),
            )
            .toList(growable: false);
      }
      final venuesData = venuesResponse.data;
      if (venuesData is! List) {
        return events
            .map(
              (event) => event.withVenueMessage(
                'Сервер вернул некорректные данные площадки',
              ),
            )
            .toList(growable: false);
      }
      final Map<String, Map<String, dynamic>> venues;
      try {
        venues = {
          for (final item in venuesData)
            _requiredString(_asJsonMap(item, 'venue'), 'id'): _asJsonMap(
              item,
              'venue',
            ),
        };
      } on FormatException {
        return events
            .map(
              (event) => event.withVenueMessage(
                'Сервер вернул некорректные данные площадки',
              ),
            )
            .toList(growable: false);
      }

      return await Future.wait(events.map((event) => _addVenue(event, venues)));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) rethrow;
      throw _eventsFailure(error);
    } on FormatException catch (error) {
      throw EventLoadFailure('Не удалось прочитать данные события: $error');
    }
  }

  Future<AssignedEvent> _addVenue(
    AssignedEvent event,
    Map<String, Map<String, dynamic>> venues,
  ) async {
    try {
      final response = await _dio.get<Object?>('/events/${event.id}');
      final eventDetails = _asJsonMap(response.data, 'event details');
      final venueId = eventDetails['venue_id'];
      if (venueId is! String) {
        return event.withVenueMessage('Площадка не указана');
      }
      final venue = venues[venueId];
      return venue == null
          ? event.withVenueMessage('Площадка не указана')
          : event.withVenue(venue);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) rethrow;
      return event.withVenueMessage(
        error.response?.statusCode == 404
            ? 'Площадка недоступна'
            : 'Не удалось загрузить информацию о площадке',
      );
    } on FormatException {
      return event.withVenueMessage(
        'Сервер вернул некорректные данные площадки',
      );
    }
  }

  EventLoadFailure _eventsFailure(DioException error) {
    if (error.response == null) {
      return const EventLoadFailure('Не удалось подключиться к серверу');
    }
    final data = error.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    if (detail is String && detail.isNotEmpty) {
      return EventLoadFailure(detail);
    }
    return EventLoadFailure(
      'Не удалось загрузить события (${error.response?.statusCode})',
    );
  }

  Map<String, dynamic> _asJsonMap(Object? value, String name) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Invalid $name object');
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing or invalid "$key"');
    }
    return value;
  }
}
