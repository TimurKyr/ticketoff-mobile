import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/features/attendees/attendee.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

abstract interface class AssignedEventsRepository {
  Future<List<AssignedEvent>> fetchMyEvents();
}

abstract interface class ScanRepository {
  Future<ScanResult> scan(String eventId, String token);
  Future<CheckinCount> fetchCount(String eventId);
}

abstract interface class AttendeesRepository {
  Future<AttendeePage> fetchAttendees(
    String eventId, {
    required String query,
    required int offset,
  });
  Future<EventStats> fetchStats(String eventId);
  Future<ScanResult> checkInTicket(String ticketId);
  Future<TicketStatus> undoCheckIn(String ticketId);
}

class AttendeesFailure implements Exception {
  const AttendeesFailure(this.message);

  final String message;
}

class EventLoadFailure implements Exception {
  const EventLoadFailure(this.message, {this.connectionLost = false});

  final String message;
  final bool connectionLost;

  @override
  String toString() => message;
}

class ScanFailure implements Exception {
  const ScanFailure(
    this.message, {
    this.connectionLost = false,
    this.statusCode,
  });

  final String message;
  final bool connectionLost;
  final int? statusCode;
}

bool isConnectionFailure(DioException error) =>
    error.response == null &&
    switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };

class CheckinService
    implements AssignedEventsRepository, ScanRepository, AttendeesRepository {
  const CheckinService(this._dio);

  final Dio _dio;

  @override
  Future<List<AssignedEvent>> fetchMyEvents() async {
    try {
      final response = await _dio.get<Object?>('/checkin/my-events');
      final events = response.data;
      if (events is! List) throw const FormatException();
      return [for (final event in events) AssignedEvent.fromJson(_json(event))];
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) rethrow;
      final data = error.response?.data;
      final detail = data is Map ? data['detail'] : null;
      throw EventLoadFailure(
        detail is String && detail.isNotEmpty
            ? detail
            : error.response == null
            ? 'Не удалось подключиться к серверу'
            : 'Не удалось загрузить мероприятия (${error.response?.statusCode})',
        connectionLost: isConnectionFailure(error),
      );
    } on FormatException {
      throw const EventLoadFailure(
        'Сервер вернул некорректный список мероприятий',
      );
    }
  }

  @override
  Future<ScanResult> scan(String eventId, String token) async {
    try {
      final response = await _dio.post<Object?>(
        '/checkin/scan',
        data: {'event_id': eventId, 'qr_token': token},
      );
      return ScanResult.fromJson(_json(response.data));
    } on DioException catch (error) {
      throw ScanFailure(
        switch (error.response?.statusCode) {
          404 => 'Событие не найдено или нет доступа',
          422 => 'Недействителен',
          null => 'Не удалось связаться с сервером. Попробуйте ещё раз.',
          _ => 'Не удалось проверить билет. Попробуйте ещё раз.',
        },
        connectionLost: isConnectionFailure(error),
        statusCode: error.response?.statusCode,
      );
    } on FormatException {
      throw const ScanFailure('Сервер вернул неизвестный результат проверки');
    }
  }

  @override
  Future<CheckinCount> fetchCount(String eventId) async {
    final stats = await fetchStats(eventId);
    return CheckinCount(stats.checkedIn, stats.registered);
  }

  @override
  Future<AttendeePage> fetchAttendees(
    String eventId, {
    required String query,
    required int offset,
  }) => _attendeesRequest(() async {
    final response = await _dio.get<Object?>(
      '/checkin/events/$eventId/attendees',
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'limit': 30,
        'offset': offset,
      },
    );
    final data = _json(response.data);
    final items = data['items'];
    final total = data['total'];
    final limit = data['limit'];
    if (items is! List ||
        total is! int ||
        total < 0 ||
        limit is! int ||
        limit < 1 ||
        limit > 100 ||
        items.length > limit ||
        data['offset'] != offset) {
      throw const FormatException('Invalid attendee page');
    }
    final nextOffset = offset + items.length;
    return AttendeePage(
      items: [for (final item in items) Attendee.fromJson(_json(item))],
      nextOffset: items.isNotEmpty && nextOffset < total ? nextOffset : null,
    );
  }, unavailable: 'Не удалось загрузить гостей');

  @override
  Future<EventStats> fetchStats(String eventId) => _attendeesRequest(() async {
    final response = await _dio.get<Object?>('/checkin/events/$eventId/stats');
    final data = _json(response.data);
    final registered = data['registered'];
    final checkedIn = data['checked_in'];
    final percent = data['percent'];
    if (registered is! int || checkedIn is! int || percent is! num) {
      throw const FormatException('Invalid check-in stats');
    }
    return EventStats(
      registered: registered,
      checkedIn: checkedIn,
      percent: percent,
    );
  }, unavailable: 'Не удалось загрузить статистику');

  @override
  Future<ScanResult> checkInTicket(String ticketId) => _attendeesRequest(
    () async {
      final response = await _dio.post<Object?>(
        '/checkin/tickets/$ticketId/check-in',
      );
      return ScanResult.fromJson(_json(response.data));
    },
    unavailable: 'Не удалось отметить вход',
    notFound: 'Билет не найден или нет доступа',
  );

  @override
  Future<TicketStatus> undoCheckIn(String ticketId) => _attendeesRequest(
    () async {
      final response = await _dio.post<Object?>(
        '/checkin/tickets/$ticketId/undo',
      );
      final data = _json(response.data);
      if (data['id'] != ticketId) {
        throw const FormatException('Invalid check-in reversal');
      }
      return TicketStatus.fromJson(data['status']);
    },
    unavailable: 'Не удалось отменить отметку',
    notFound: 'Билет не найден или нет доступа',
  );

  Future<T> _attendeesRequest<T>(
    Future<T> Function() request, {
    required String unavailable,
    String notFound = 'Событие не найдено или нет доступа',
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AttendeesFailure(switch (error.response?.statusCode) {
        404 => notFound,
        null => 'Не удалось связаться с сервером',
        _ => unavailable,
      });
    } on FormatException {
      throw const AttendeesFailure('Сервер вернул некорректные данные');
    }
  }

  Map<String, dynamic> _json(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('Invalid check-in response');
  }
}
