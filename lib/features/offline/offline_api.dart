import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_models.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class OfflineRequestFailure implements Exception {
  const OfflineRequestFailure(
    this.message, {
    this.connectionLost = false,
    this.statusCode,
  });

  final String message;
  final bool connectionLost;
  final int? statusCode;
}

class OfflineApi {
  const OfflineApi(this._dio, this._cancelToken);

  final Dio _dio;
  final CancelToken _cancelToken;

  Future<void> probe() => _request(() async {
    await _dio.get<Object?>('/health', cancelToken: _cancelToken);
  });

  Future<OfflinePack> download(AssignedEvent event) => _request(() async {
    final response = await _dio.get<Object?>(
      '/checkin/events/${Uri.encodeComponent(event.id)}/offline-pack',
      cancelToken: _cancelToken,
    );
    final body = _object(response.data);
    final tickets = body['tickets'];
    if (body['event_id'] != event.id || tickets is! List) {
      throw const FormatException('Invalid offline pack');
    }
    final downloadedEvent = AssignedEvent(
      id: event.id,
      title: _string(body, 'event_title'),
      status: _string(body, 'event_status'),
      startAt: event.startAt,
      endAt: event.endAt,
      venueName: event.venueName,
      venueAddress: event.venueAddress,
    );
    return OfflinePack(
      downloadedEvent,
      DateTime.parse(_string(body, 'generated_at')).toUtc(),
      _counts(body),
      [
        for (final raw in tickets)
          {
            for (final field in [
              'ticket_id',
              'status',
              'attendee_name',
              'ticket_type',
            ])
              field: _string(_object(raw), field),
          },
      ],
    );
  });

  Future<SyncResult> sync(
    String eventId,
    String deviceId,
    List<PendingCheckIn> marks,
  ) => _request(() async {
    final response = await _dio.post<Object?>(
      '/checkin/sync',
      data: {
        'event_id': eventId,
        'items': [
          for (final mark in marks)
            {
              'ticket_id': mark.qr,
              'scanned_at': mark.scannedAt.toUtc().toIso8601String(),
              'device_id': deviceId,
            },
        ],
      },
      cancelToken: _cancelToken,
    );
    final body = _object(response.data);
    final items = body['items'];
    if (items is! List || items.length != marks.length) {
      throw const FormatException('Incomplete offline sync response');
    }
    return SyncResult([
      for (var index = 0; index < marks.length; index++)
        _syncItem(_object(items[index]), marks[index], deviceId),
    ], _counts(body));
  });

  SyncItem _syncItem(Json item, PendingCheckIn mark, String deviceId) {
    if (item['ticket_id'] != mark.qr || item['device_id'] != deviceId) {
      throw const FormatException('Mismatched offline sync response');
    }
    final time = _optionalString(item, 'checked_in_at');
    return SyncItem(
      outcome: ScanOutcome.fromApi(item['result']),
      checkedInAt: time == null ? null : DateTime.parse(time),
      checkedInBy: _optionalString(item, 'checked_in_by'),
      checkedInDeviceId: _optionalString(item, 'checked_in_device_id'),
    );
  }

  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw OfflineRequestFailure(
        switch (status) {
          401 => 'Войдите снова, чтобы продолжить синхронизацию',
          403 || 404 => 'Событие не найдено или нет доступа',
          null => 'Не удалось связаться с сервером',
          _ => 'Сервер вернул ошибку ($status)',
        },
        connectionLost: isConnectionFailure(error),
        statusCode: status,
      );
    } on FormatException {
      throw const OfflineRequestFailure('Сервер вернул некорректные данные');
    }
  }
}

Json _object(Object? value) {
  if (value is Json) return value;
  throw const FormatException('Expected a JSON object');
}

String _string(Json data, String key) =>
    _optionalString(data, key) ?? (throw FormatException('Missing $key'));

String? _optionalString(Json data, String key) {
  final value = data[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Invalid $key');
}

CheckinCount _counts(Json data) {
  final checked = data['checked_in_count'];
  final total = data['total_count'];
  if (checked is! int || total is! int || checked < 0 || total < checked) {
    throw const FormatException('Invalid check-in counts');
  }
  return CheckinCount(checked, total);
}
