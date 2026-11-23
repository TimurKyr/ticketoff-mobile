import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

typedef Json = Map<String, dynamic>;

class OfflineEvent {
  const OfflineEvent({
    required this.event,
    required this.generatedAt,
    required this.count,
    required this.pending,
    required this.available,
  });

  final AssignedEvent event;
  final DateTime generatedAt;
  final CheckinCount count;
  final int pending;
  final bool available;
}

class PendingCheckIn {
  const PendingCheckIn(this.ticketId, this.qr, this.scannedAt);

  final String ticketId;
  final String qr;
  final DateTime scannedAt;
}

class SyncItem {
  const SyncItem({
    required this.outcome,
    this.checkedInAt,
    this.checkedInBy,
    this.checkedInDeviceId,
  });

  final ScanOutcome outcome;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final String? checkedInDeviceId;

  bool isConflict(String deviceId) =>
      outcome != ScanOutcome.checkedIn &&
      !(outcome == ScanOutcome.alreadyUsed && checkedInDeviceId == deviceId);
}

class SyncResult {
  const SyncResult(this.items, this.count);

  final List<SyncItem> items;
  final CheckinCount count;
}

class SyncConflict {
  const SyncConflict(this.attendee, this.item);

  final String attendee;
  final SyncItem item;
}

class OfflinePack {
  const OfflinePack(this.event, this.generatedAt, this.count, this.tickets);

  final AssignedEvent event;
  final DateTime generatedAt;
  final CheckinCount count;
  final List<Json> tickets;
}

// The pack contains no signing secret. The server validates the original QR
// when it receives the queued check-in.
final _ticketQr = RegExp(
  r'^tk1\.([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.[A-Za-z0-9_-]{43}$',
);

String? ticketIdFromQr(String qr) => _ticketQr.firstMatch(qr)?.group(1);

bool isCampaignQr(String qr) =>
    qr.startsWith('pc1.') || qr.contains('promo=pc1.');

String? ticketStatusFor(ScanOutcome outcome) => switch (outcome) {
  ScanOutcome.checkedIn || ScanOutcome.alreadyUsed => 'checked_in',
  ScanOutcome.cancelled => 'cancelled',
  ScanOutcome.refunded => 'refunded',
  _ => null,
};
