import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_api.dart';
import 'package:ticketoff_mobile/features/offline/offline_models.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

const _ticketId = '387b540a-485b-4d23-b3b6-8e3f57205eb3';
const _eventId = 'dbc15570-2f86-4a03-808f-cfb85835f456';
const _signature = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _qr = 'tk1.$_ticketId.$_signature';

void main() {
  test('only a canonical ticket QR yields a ticket ID', () {
    expect(ticketIdFromQr(_qr), _ticketId);
    expect(ticketIdFromQr(_ticketId), isNull);
    expect(ticketIdFromQr('tk1.$_ticketId.fake'), isNull);
    expect(
      ticketIdFromQr('tk1.${_ticketId.toUpperCase()}.$_signature'),
      isNull,
    );
    expect(isCampaignQr('pc1.campaign'), isTrue);
    expect(
      isCampaignQr('https://ticketoff.store/events/test?promo=pc1.code'),
      isTrue,
    );
    expect(ticketIdFromQr('pc1.campaign'), isNull);
  });

  test('offline pack uses the server timestamp, tickets and counts', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.method, 'GET');
            expect(request.path, '/checkin/events/$_eventId/offline-pack');
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'event_id': _eventId,
                  'event_title': 'Jazz Night',
                  'event_status': 'published',
                  'generated_at': '2026-11-26T12:40:00Z',
                  'checked_in_count': 3,
                  'total_count': 120,
                  'tickets': [
                    {
                      'ticket_id': _ticketId,
                      'status': 'valid',
                      'attendee_name': 'Dana',
                      'ticket_type': 'VIP',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    addTearDown(dio.close);
    final pack = await OfflineApi(dio, CancelToken()).download(
      AssignedEvent(
        id: _eventId,
        title: 'Old title',
        status: 'published',
        startAt: DateTime.utc(2026, 11, 26, 14),
        venueName: 'Concert hall',
      ),
    );
    expect(pack.event.title, 'Jazz Night');
    expect(pack.event.venueName, 'Concert hall');
    expect(pack.generatedAt, DateTime.utc(2026, 11, 26, 12, 40));
    expect(pack.count.checkedIn, 3);
    expect(pack.tickets.single['ticket_id'], _ticketId);
  });

  test('sync preserves the QR, UTC scan time, and conflict metadata', () async {
    const secondId = 'a894bda7-9a3d-42e2-9969-a75c03dc6319';
    const secondQr = 'tk1.$secondId.$_signature';
    const device = 'gate-1';
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.method, 'POST');
            expect(request.path, '/checkin/sync');
            expect(request.data, {
              'event_id': _eventId,
              'items': [
                {
                  'ticket_id': _qr,
                  'device_id': device,
                  'scanned_at': '2026-11-26T13:05:00.000Z',
                },
                {
                  'ticket_id': secondQr,
                  'device_id': device,
                  'scanned_at': '2026-11-26T13:06:00.000Z',
                },
              ],
            });
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'checked_in_count': 5,
                  'total_count': 120,
                  'items': [
                    {
                      'ticket_id': _qr,
                      'device_id': device,
                      'result': 'already_used',
                      'checked_in_device_id': device,
                    },
                    {
                      'ticket_id': secondQr,
                      'device_id': device,
                      'result': 'already_used',
                      'checked_in_at': '2026-11-26T13:01:40Z',
                      'checked_in_by': 'owner@example.com',
                      'checked_in_device_id': 'gate-2',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    addTearDown(dio.close);
    final result = await OfflineApi(dio, CancelToken()).sync(_eventId, device, [
      PendingCheckIn(
        _ticketId,
        _qr,
        DateTime.parse('2026-11-26T18:05:00+05:00'),
      ),
      PendingCheckIn(secondId, secondQr, DateTime.utc(2026, 11, 26, 13, 6)),
    ]);
    expect(result.count.checkedIn, 5);
    expect(result.items.first.outcome, ScanOutcome.alreadyUsed);
    expect(result.items.first.isConflict(device), isFalse);
    expect(result.items.last.isConflict(device), isTrue);
    expect(
      result.items.last.checkedInAt,
      DateTime.utc(2026, 11, 26, 13, 1, 40),
    );
    expect(result.items.last.checkedInBy, 'owner@example.com');
  });

  test(
    'sync refuses to acknowledge a response for another queued item',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) => handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'checked_in_count': 1,
                  'total_count': 4,
                  'items': [
                    {
                      'ticket_id': 'other-qr',
                      'device_id': 'gate-1',
                      'result': 'checked_in',
                    },
                  ],
                },
              ),
            ),
          ),
        );
      addTearDown(dio.close);
      await expectLater(
        OfflineApi(dio, CancelToken()).sync(_eventId, 'gate-1', [
          PendingCheckIn(_ticketId, _qr, DateTime.utc(2026, 11, 26, 13)),
        ]),
        throwsA(isA<OfflineRequestFailure>()),
      );
    },
  );
}
