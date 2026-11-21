import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

abstract interface class AssignedEventsRepository {
  Future<List<AssignedEvent>> fetchMyEvents();
}

abstract interface class ScanRepository {
  Future<ScanResult> scan(String eventId, String token);
  Future<CheckinCount> fetchCount(String eventId);
}

class EventLoadFailure implements Exception {
  const EventLoadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScanFailure implements Exception {
  const ScanFailure(this.message);

  final String message;
}

class CheckinService implements AssignedEventsRepository, ScanRepository {
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
      throw ScanFailure(switch (error.response?.statusCode) {
        404 => 'Событие не найдено или нет доступа',
        422 => 'Недействителен',
        null => 'Не удалось связаться с сервером. Попробуйте ещё раз.',
        _ => 'Не удалось проверить билет. Попробуйте ещё раз.',
      });
    } on FormatException {
      throw const ScanFailure('Сервер вернул неизвестный результат проверки');
    }
  }

  @override
  Future<CheckinCount> fetchCount(String eventId) async {
    final response = await _dio.get<Object?>('/checkin/events/$eventId/stats');
    final data = _json(response.data);
    final checkedIn = data['checked_in'];
    final total = data['registered'];
    if (checkedIn is! int || total is! int) throw const FormatException();
    return CheckinCount(checkedIn, total);
  }

  Map<String, dynamic> _json(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('Invalid check-in response');
  }
}
