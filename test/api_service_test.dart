import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/api/dio_client.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;
}

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this.handle);

  final Future<ResponseBody> Function(RequestOptions, List<int>) handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final requestBytes = requestStream == null
        ? <int>[]
        : await requestStream
              .fold<BytesBuilder>(BytesBuilder(), (builder, chunk) {
                builder.add(chunk);
                return builder;
              })
              .then((builder) => builder.takeBytes());
    return handle(options, requestBytes);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test(
    'login sends form-urlencoded credentials and stores the access token',
    () async {
      final storage = _MemoryTokenStorage();
      RequestOptions? loginRequest;
      List<int>? loginBody;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _TestAdapter((request, body) async {
          loginRequest = request;
          loginBody = body;
          return _jsonResponse({'access_token': 'session-token'});
        });

      final auth = AuthService(dio, storage);
      await auth.login('controller@example.com', 'correct-password');

      expect(loginRequest?.path, '/auth/login');
      expect(loginRequest?.contentType, Headers.formUrlEncodedContentType);
      expect(Uri.splitQueryString(utf8.decode(loginBody!)), {
        'username': 'controller@example.com',
        'password': 'correct-password',
      });
      expect(storage.token, 'session-token');
      expect(await auth.hasSession(), isTrue);

      await auth.logout();
      expect(storage.token, isNull);
      expect(await auth.hasSession(), isFalse);
      dio.close();
    },
  );

  test('login converts backend 401 into a readable credential error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _TestAdapter(
        (request, body) async => _jsonResponse({
          'detail': 'Incorrect email or password',
        }, statusCode: 401),
      );

    await expectLater(
      AuthService(dio, _MemoryTokenStorage()).login('a@example.com', 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'message',
          'Неверный email или пароль',
        ),
      ),
    );
    dio.close();
  });

  test(
    'events are loaded only from my-events and venue data is joined',
    () async {
      final storage = _MemoryTokenStorage()..token = 'session-token';
      final requests = <RequestOptions>[];
      final dioClient = DioClient(secureStorage: storage);
      dioClient.dio.options.baseUrl = 'https://api.test';
      dioClient.dio.httpClientAdapter = _TestAdapter((request, body) async {
        requests.add(request);
        return switch (request.path) {
          '/checkin/my-events' => _jsonResponse([
            {
              'id': 'assigned-event',
              'title': 'Назначенное событие',
              'status': 'published',
              'start_at': '2026-11-09T14:00:00Z',
              'end_at': null,
              'is_owner': false,
            },
          ]),
          '/venues' => _jsonResponse([
            {
              'id': 'venue-1',
              'name': 'Главный зал',
              'address': 'Улица 1',
              'city': 'Город',
              'timezone': 'UTC',
            },
          ]),
          '/events/assigned-event' => _jsonResponse({'venue_id': 'venue-1'}),
          _ => _jsonResponse({'detail': 'Not found'}, statusCode: 404),
        };
      });

      final events = await CheckinService(dioClient.dio).fetchMyEvents();

      expect(events, hasLength(1));
      expect(events.single.id, 'assigned-event');
      expect(events.single.venueLabel, 'Главный зал, Улица 1, Город');
      expect(
        requests.map((request) => request.path),
        containsAll([
          '/checkin/my-events',
          '/venues',
          '/events/assigned-event',
        ]),
      );
      expect(
        requests.map((request) => request.headers['Authorization']),
        everyElement('Bearer session-token'),
      );
      dioClient.close();
    },
  );

  test('private event details do not hide the assigned event list', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _TestAdapter((request, body) async {
        return switch (request.path) {
          '/checkin/my-events' => _jsonResponse([
            {
              'id': 'private-event',
              'title': 'Приватное событие',
              'status': 'published',
              'start_at': '2026-11-09T14:00:00Z',
              'end_at': null,
              'is_owner': false,
            },
          ]),
          '/venues' => _jsonResponse([]),
          '/events/private-event' => _jsonResponse({
            'detail': 'Event not found',
          }, statusCode: 404),
          _ => _jsonResponse({'detail': 'Not found'}, statusCode: 404),
        };
      });

    final events = await CheckinService(dio).fetchMyEvents();

    expect(events, hasLength(1));
    expect(events.single.title, 'Приватное событие');
    expect(events.single.venueMessage, 'Площадка недоступна');
    dio.close();
  });

  test(
    'expired token is cleared and triggers the unauthorized handler',
    () async {
      final storage = _MemoryTokenStorage()..token = 'expired-token';
      var unauthorized = false;
      final dioClient = DioClient(
        secureStorage: storage,
        onUnauthorized: () async {
          unauthorized = true;
        },
      );
      dioClient.dio.options.baseUrl = 'https://api.test';
      dioClient.dio.httpClientAdapter = _TestAdapter(
        (request, body) async =>
            _jsonResponse({'detail': 'Not authenticated'}, statusCode: 401),
      );

      await expectLater(
        dioClient.dio.get<Object?>('/checkin/my-events'),
        throwsA(isA<DioException>()),
      );

      expect(storage.token, isNull);
      expect(unauthorized, isTrue);
      dioClient.close();
    },
  );
}
