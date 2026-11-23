import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_api.dart';
import 'package:ticketoff_mobile/features/offline/offline_models.dart';
import 'package:ticketoff_mobile/features/offline/offline_store.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class OfflineCheckin extends ChangeNotifier
    implements ScanRepository, AssignedEventsRepository {
  OfflineCheckin({
    required this._account,
    required Dio dio,
    required this._store,
    required this._scans,
    required this._assignedEvents,
  }) {
    _api = OfflineApi(dio, _cancelToken);
    unawaited(_initialize());
  }

  final String _account;
  final OfflineStore _store;
  final ScanRepository _scans;
  final AssignedEventsRepository _assignedEvents;
  final _cancelToken = CancelToken();
  final _operations = Lock();
  late final OfflineApi _api;
  Timer? _timer;
  bool _closed = false;
  bool _polling = false;
  bool _syncing = false;
  bool _foreground = true;
  bool _offline = false;
  Map<String, OfflineEvent> _packs = {};
  Map<String, AssignedEvent> _onlineEvents = {};
  Set<String> _conflicts = {};
  final _downloading = <String>{};
  final _syncErrors = <String, String>{};
  final _liveCounts = <String, CheckinCount>{};

  static String accountKey(String baseUrl, String token) {
    // The existing server-issued session supplies a stable account identifier.
    // Decoding it here only partitions cached data, never authenticates a user.
    var identity = token;
    final parts = token.split('.');
    if (parts.length == 3) {
      try {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (claims case {'sub': final String subject}) {
          identity = subject;
        }
      } on FormatException {
        // Opaque or legacy tokens still get a separate cache.
      }
    }
    return sha256.convert(utf8.encode('$baseUrl\n$identity')).toString();
  }

  bool get isOffline => _offline;
  bool get isSyncing => _syncing;
  OfflineEvent? packFor(String eventId) => _packs[eventId];
  AssignedEvent? eventFor(String eventId) =>
      _onlineEvents[eventId] ?? _packs[eventId]?.event;
  bool isDownloading(String eventId) => _downloading.contains(eventId);
  bool hasConflicts(String eventId) => _conflicts.contains(eventId);
  String? syncError(String eventId) => _syncErrors[eventId];

  CheckinCount? countFor(String eventId) {
    final pack = _packs[eventId];
    return _offline || (pack?.pending ?? 0) > 0
        ? pack?.count
        : _liveCounts[eventId] ?? pack?.count;
  }

  Future<void> _initialize() async {
    try {
      await _operations.synchronized(_readCache);
    } on Exception {
      // A database failure should not disable ordinary online check-in.
    }
    if (!_closed) setForeground(_foreground);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _timer?.cancel();
    if (!foreground || _closed) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _poll();
  }

  Future<void> download(AssignedEvent event) async {
    if (_closed || !_downloading.add(event.id)) return;
    _notify();
    try {
      await _operations.synchronized(() async {
        _requireSession();
        try {
          final pack = await _api.download(event);
          _requireSession();
          await _store.savePack(_account, pack);
          _liveCounts[event.id] = pack.count;
          _syncErrors.remove(event.id);
          await _readCache();
          _setOffline(false);
        } on OfflineRequestFailure catch (failure) {
          await _handleRequestFailure(event.id, failure);
          rethrow;
        } on Exception {
          throw const OfflineRequestFailure(
            'Не удалось сохранить офлайн-пакет',
          );
        }
      });
    } finally {
      _downloading.remove(event.id);
      _notify();
    }
    _poll();
  }

  @override
  Future<List<AssignedEvent>> fetchMyEvents() async {
    if (!_offline) {
      try {
        final events = await _assignedEvents.fetchMyEvents();
        _onlineEvents = {for (final event in events) event.id: event};
        _notify();
        return events;
      } on EventLoadFailure catch (failure) {
        if (!failure.connectionLost) rethrow;
        _setOffline(true);
      }
    }
    await _operations.synchronized(() async {
      try {
        await _readCache();
      } on Exception {
        throw const EventLoadFailure('Не удалось открыть офлайн-пакеты');
      }
    });
    return [
      for (final pack in _packs.values)
        if (pack.available) pack.event,
    ];
  }

  @override
  Future<CheckinCount> fetchCount(String eventId) async {
    final pack = _packs[eventId];
    if (_offline && pack != null) return pack.count;
    final count = await _scans.fetchCount(eventId);
    if (!_closed && !_liveCounts.containsKey(eventId)) {
      _liveCounts[eventId] = count;
    }
    return count;
  }

  @override
  Future<ScanResult> scan(String eventId, String token) =>
      _operations.synchronized(() async {
        if (_closed) throw const ScanFailure('Войдите снова');
        final qr = token.trim();
        final ticketId = ticketIdFromQr(qr);
        final pack = _packs[eventId];

        if (!_offline) {
          if (ticketId != null && (pack?.pending ?? 0) > 0) {
            try {
              if (await _store.hasPending(_account, eventId, ticketId)) {
                return _offlineResult(eventId, ScanOutcome.alreadyUsed);
              }
            } on Exception {
              throw const ScanFailure('Не удалось проверить офлайн-очередь');
            }
          }
          if (_closed) throw const ScanFailure('Войдите снова');
          try {
            final result = await _scans.scan(eventId, token);
            _liveCounts[eventId] = result.count;
            if (!_closed && pack != null) {
              try {
                await _store.updateFromOnlineScan(
                  _account,
                  eventId,
                  ticketId,
                  result,
                );
                await _readCache();
              } on Exception {
                // The server has already answered. Require a fresh pack if the
                // local copy could not be brought up to date.
                await _revoke(eventId);
              }
            }
            return result;
          } on ScanFailure catch (failure) {
            if (!_closed &&
                (failure.statusCode == 403 || failure.statusCode == 404)) {
              await _revoke(eventId);
            }
            if (!failure.connectionLost || _closed) rethrow;
            _setOffline(true);
          }
        }
        return _scanOffline(eventId, qr, ticketId);
      });

  Future<ScanResult> _scanOffline(
    String eventId,
    String qr,
    String? ticketId,
  ) async {
    if (isCampaignQr(qr)) {
      return _offlineResult(eventId, ScanOutcome.campaignQrRejected);
    }
    final pack = _packs[eventId];
    if (pack == null || !pack.available) {
      throw const ScanFailure(
        'Офлайн-пакет недоступен. Скачайте его при подключении к сети.',
      );
    }
    if (pack.event.status == 'cancelled') {
      return _offlineResult(eventId, ScanOutcome.eventCancelled);
    }
    if (ticketId == null ||
        (pack.event.status != 'published' &&
            pack.event.status != 'completed')) {
      return _offlineResult(eventId, ScanOutcome.invalid);
    }
    try {
      final result = await _store.mark(_account, eventId, ticketId, qr);
      if (result.outcome == ScanOutcome.checkedIn) await _readCache();
      return _offlineResult(
        eventId,
        result.outcome,
        name: result.name,
        type: result.type,
      );
    } on Exception {
      throw const ScanFailure('Не удалось сохранить офлайн-отметку');
    }
  }

  ScanResult _offlineResult(
    String eventId,
    ScanOutcome outcome, {
    String? name,
    String? type,
  }) => ScanResult(
    outcome: outcome,
    count: countFor(eventId) ?? const CheckinCount(0, 0),
    attendeeName: name,
    ticketType: type,
    offline: true,
  );

  Future<List<SyncConflict>> conflicts(String eventId) =>
      _store.conflicts(_account, eventId);

  Future<void> syncNow() => _poll(force: true);

  Future<void> _poll({bool force = false}) async {
    if (_closed ||
        _polling ||
        _operations.locked ||
        (!force && _packs.isEmpty && !_offline)) {
      return;
    }
    _polling = true;
    try {
      await _operations.synchronized(() async {
        if (_closed) return;
        try {
          await _api.probe();
          if (_closed) return;
          _setOffline(false);
        } on OfflineRequestFailure catch (failure) {
          if (failure.connectionLost) {
            _setOffline(true);
            return;
          }
          // A server response indicates connectivity even if /health fails.
          if (failure.statusCode == null || failure.statusCode == 401) return;
          _setOffline(false);
        }
        for (final pack in _packs.values.toList(growable: false)) {
          if (_closed || _offline) break;
          if (pack.pending > 0 && pack.available) {
            await _syncEvent(pack.event.id);
          }
        }
      });
    } finally {
      _polling = false;
      if (_syncing) {
        _syncing = false;
        _notify();
      }
    }
  }

  Future<void> _syncEvent(String eventId) async {
    if (!_syncing) {
      _syncing = true;
      _notify();
    }
    try {
      final device = await _store.deviceId();
      final pending = await _store.pending(_account, eventId);
      if (_closed) return;
      if (pending.isEmpty) {
        _syncErrors.remove(eventId);
        await _readCache();
        return;
      }
      final response = await _api.sync(eventId, device, pending);
      // Commit the acknowledgement even if the session just ended, using the
      // original account of this request.
      await _store.applySync(_account, eventId, device, pending, response);
      _liveCounts[eventId] = response.count;
      _syncErrors.remove(eventId);
      await _readCache();
    } on OfflineRequestFailure catch (failure) {
      await _handleRequestFailure(eventId, failure);
      if (!failure.connectionLost) _syncErrors[eventId] = failure.message;
    } on Exception {
      _syncErrors[eventId] = 'Не удалось обновить локальную очередь';
    }
  }

  Future<void> _handleRequestFailure(
    String eventId,
    OfflineRequestFailure failure,
  ) async {
    if (failure.connectionLost) _setOffline(true);
    if (failure.statusCode == 403 || failure.statusCode == 404) {
      await _revoke(eventId);
    }
  }

  Future<void> _revoke(String eventId) async {
    final pack = _packs[eventId];
    if (pack == null) return;
    _packs[eventId] = OfflineEvent(
      event: pack.event,
      generatedAt: pack.generatedAt,
      count: pack.count,
      pending: pack.pending,
      available: false,
    );
    try {
      await _store.revokePack(_account, eventId);
    } on Exception {
      // Keep the pack disabled for the rest of this session.
    }
    _notify();
  }

  Future<void> _readCache() async {
    if (_closed) return;
    _packs = await _store.events(_account);
    _conflicts = await _store.eventsWithConflicts(_account);
    _notify();
  }

  void _setOffline(bool value) {
    if (_offline == value || _closed) return;
    _offline = value;
    _notify();
  }

  void _requireSession() {
    if (_closed) throw const OfflineRequestFailure('Войдите снова');
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _cancelToken.cancel();
    super.dispose();
  }
}
