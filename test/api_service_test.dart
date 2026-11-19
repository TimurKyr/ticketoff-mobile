import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/api/dio_client.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

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

  test('assigned events include venue details in the same response', () async {
    final storage = _MemoryTokenStorage()..token = 'session-token';
    final client = DioClient(secureStorage: storage);
    addTearDown(client.close);
    client.dio.httpClientAdapter = _TestAdapter((request, body) async {
      expect(request.path, '/checkin/my-events');
      expect(request.headers['Authorization'], 'Bearer session-token');
      return _jsonResponse([
        {
          'id': 'event-1',
          'title': 'Concert',
          'status': 'published',
          'start_at': '2026-11-09T14:00:00Z',
          'venue_name': 'Central Hall',
          'venue_address': 'Main Street 1',
        },
      ]);
    });
    final events = await CheckinService(client.dio).fetchMyEvents();
    expect(events.single.venueLabel, 'Central Hall, Main Street 1');
  });

  test('scan sends the event and QR and parses every result', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    addTearDown(dio.close);
    for (final outcome in ScanOutcome.values) {
      dio.httpClientAdapter = _TestAdapter((request, body) async {
        expect(request.method, 'POST');
        expect(request.path, '/checkin/scan');
        expect(jsonDecode(utf8.decode(body)), {
          'event_id': 'event-1',
          'qr_token': 'valid-qr',
        });
        return _jsonResponse({
          'result': outcome.apiValue,
          'checked_in_count': 2,
          'total_count': 5,
          'ticket': outcome == ScanOutcome.checkedIn
              ? {'attendee_name': 'Dana', 'ticket_type': 'VIP'}
              : null,
        });
      });
      final result = await CheckinService(dio).scan('event-1', 'valid-qr');
      expect(result.outcome, outcome);
      expect(result.count.checkedIn, 2);
      expect(result.count.total, 5);
      if (outcome == ScanOutcome.checkedIn) {
        expect(result.attendeeName, 'Dana');
        expect(result.ticketType, 'VIP');
      }
    }
  });

  test(
    'scan gives a readable message when the event is inaccessible',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _TestAdapter(
          (_, _) async => _jsonResponse({}, statusCode: 404),
        );
      addTearDown(dio.close);
      await expectLater(
        CheckinService(dio).scan('missing-event', 'qr'),
        throwsA(
          isA<ScanFailure>().having(
            (error) => error.message,
            'message',
            'Событие не найдено или нет доступа',
          ),
        ),
      );
    },
  );

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
