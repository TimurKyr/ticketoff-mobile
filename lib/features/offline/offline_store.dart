import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_models.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class OfflineStore {
  late final Future<Database> _database = _open();

  static Future<Database> _open() async => openDatabase(
    path.join(await getDatabasesPath(), 'ticketoff_checkin.db'),
    version: 1,
    onCreate: (db, _) async {
      final batch = db.batch();
      batch.execute(
        'CREATE TABLE installation (id INTEGER PRIMARY KEY, device_id TEXT NOT NULL)',
      );
      batch.execute('''
        CREATE TABLE packs (
          account TEXT NOT NULL, event_id TEXT NOT NULL,
          title TEXT NOT NULL, status TEXT NOT NULL, start_at TEXT NOT NULL,
          end_at TEXT, venue_name TEXT, venue_address TEXT,
          generated_at TEXT NOT NULL, checked_in INTEGER NOT NULL,
          total INTEGER NOT NULL, available INTEGER NOT NULL,
          PRIMARY KEY (account, event_id)
        )
      ''');
      batch.execute('''
        CREATE TABLE tickets (
          account TEXT NOT NULL, event_id TEXT NOT NULL, ticket_id TEXT NOT NULL,
          status TEXT NOT NULL, attendee_name TEXT NOT NULL, ticket_type TEXT NOT NULL,
          PRIMARY KEY (account, event_id, ticket_id)
        )
      ''');
      batch.execute('''
        CREATE TABLE pending (
          account TEXT NOT NULL, event_id TEXT NOT NULL, ticket_id TEXT NOT NULL,
          qr TEXT NOT NULL, scanned_at TEXT NOT NULL, attendee_name TEXT NOT NULL,
          PRIMARY KEY (account, event_id, ticket_id)
        )
      ''');
      batch.execute('''
        CREATE TABLE conflicts (
          id INTEGER PRIMARY KEY, account TEXT NOT NULL, event_id TEXT NOT NULL,
          attendee_name TEXT NOT NULL, result TEXT NOT NULL, checked_in_at TEXT,
          checked_in_by TEXT, checked_in_device_id TEXT
        )
      ''');
      batch.execute(
        'CREATE INDEX conflicts_event ON conflicts (account, event_id)',
      );
      await batch.commit(noResult: true);
    },
  );

  Future<String> deviceId() async => (await _database).transaction((txn) async {
    final rows = await txn.query('installation', where: 'id = 1');
    if (rows.isNotEmpty) return rows.single['device_id']! as String;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await txn.insert('installation', {'id': 1, 'device_id': id});
    return id;
  });

  Future<void> savePack(String account, OfflinePack pack) async {
    final event = pack.event;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.insert('packs', {
        'account': account,
        'event_id': event.id,
        'title': event.title,
        'status': event.status,
        'start_at': event.startAt.toIso8601String(),
        'end_at': event.endAt?.toIso8601String(),
        'venue_name': event.venueName,
        'venue_address': event.venueAddress,
        'generated_at': pack.generatedAt.toUtc().toIso8601String(),
        'checked_in': pack.count.checkedIn,
        'total': pack.count.total,
        'available': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.delete(
        'tickets',
        where: _eventFilter,
        whereArgs: [account, event.id],
      );
      for (final ticket in pack.tickets) {
        batch.insert('tickets', {
          ...ticket,
          'account': account,
          'event_id': event.id,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, OfflineEvent>> events(String account) async {
    final rows = await (await _database).rawQuery(
      '''
      SELECT packs.*,
        (SELECT COUNT(*) FROM pending p
          WHERE p.account = packs.account AND p.event_id = packs.event_id) AS queued,
        (SELECT COUNT(*) FROM pending p JOIN tickets t
          USING (account, event_id, ticket_id)
          WHERE p.account = packs.account AND p.event_id = packs.event_id
            AND t.status = 'valid') AS provisional
      FROM packs WHERE account = ? ORDER BY start_at
    ''',
      [account],
    );
    return {
      for (final row in rows)
        row['event_id']! as String: OfflineEvent(
          event: AssignedEvent.fromJson({...row, 'id': row['event_id']}),
          generatedAt: DateTime.parse(row['generated_at']! as String),
          count: CheckinCount(
            (row['checked_in']! as int) + (row['provisional']! as int),
            row['total']! as int,
          ),
          pending: row['queued']! as int,
          available: row['available'] == 1,
        ),
    };
  }

  Future<bool> hasPending(
    String account,
    String eventId,
    String ticketId,
  ) async => (await (await _database).query(
    'pending',
    columns: ['ticket_id'],
    where: _ticketFilter,
    whereArgs: [account, eventId, ticketId],
  )).isNotEmpty;

  Future<({ScanOutcome outcome, String? name, String? type})> mark(
    String account,
    String eventId,
    String ticketId,
    String qr,
  ) async => (await _database).transaction((txn) async {
    final rows = await txn.query(
      'tickets',
      where: _ticketFilter,
      whereArgs: [account, eventId, ticketId],
    );
    final ticket = rows.firstOrNull;
    final outcome = switch (ticket?['status']) {
      'valid' => ScanOutcome.checkedIn,
      'checked_in' => ScanOutcome.alreadyUsed,
      'cancelled' => ScanOutcome.cancelled,
      'refunded' => ScanOutcome.refunded,
      _ => ScanOutcome.invalid,
    };
    if (outcome != ScanOutcome.checkedIn) {
      return (outcome: outcome, name: null, type: null);
    }
    final queued = await txn.query(
      'pending',
      columns: ['ticket_id'],
      where: _ticketFilter,
      whereArgs: [account, eventId, ticketId],
    );
    if (queued.isNotEmpty) {
      return (outcome: ScanOutcome.alreadyUsed, name: null, type: null);
    }
    final name = ticket!['attendee_name']! as String;
    await txn.insert('pending', {
      'account': account,
      'event_id': eventId,
      'ticket_id': ticketId,
      'qr': qr,
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
      'attendee_name': name,
    });
    return (
      outcome: ScanOutcome.checkedIn,
      name: name,
      type: ticket['ticket_type']! as String,
    );
  });

  Future<List<PendingCheckIn>> pending(String account, String eventId) async {
    final rows = await (await _database).query(
      'pending',
      where: _eventFilter,
      whereArgs: [account, eventId],
      orderBy: 'scanned_at, ticket_id',
      limit: 1000,
    );
    return [
      for (final row in rows)
        PendingCheckIn(
          row['ticket_id']! as String,
          row['qr']! as String,
          DateTime.parse(row['scanned_at']! as String),
        ),
    ];
  }

  Future<void> applySync(
    String account,
    String eventId,
    String deviceId,
    List<PendingCheckIn> marks,
    SyncResult response,
  ) async {
    await (await _database).transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < marks.length; i++) {
        final mark = marks[i];
        final result = response.items[i];
        final args = [account, eventId, mark.ticketId];
        if (result.isConflict(deviceId)) {
          batch.execute(
            '''
            INSERT INTO conflicts
              (account, event_id, attendee_name, result, checked_in_at, checked_in_by, checked_in_device_id)
            SELECT account, event_id, attendee_name, ?, ?, ?, ?
            FROM pending WHERE $_ticketFilter
          ''',
            [
              result.outcome.apiValue,
              result.checkedInAt?.toUtc().toIso8601String(),
              result.checkedInBy,
              result.checkedInDeviceId,
              ...args,
            ],
          );
        }
        final status = ticketStatusFor(result.outcome);
        if (status != null) {
          batch.update(
            'tickets',
            {'status': status},
            where: _ticketFilter,
            whereArgs: args,
          );
        }
        batch.delete('pending', where: _ticketFilter, whereArgs: args);
      }
      batch.update(
        'packs',
        {
          'checked_in': response.count.checkedIn,
          'total': response.count.total,
          if (response.items.any(
            (item) => item.outcome == ScanOutcome.eventCancelled,
          ))
            'status': 'cancelled',
        },
        where: _eventFilter,
        whereArgs: [account, eventId],
      );
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateFromOnlineScan(
    String account,
    String eventId,
    String? ticketId,
    ScanResult result,
  ) async {
    await (await _database).transaction((txn) async {
      final status = ticketStatusFor(result.outcome);
      if (ticketId != null && status != null) {
        await txn.update(
          'tickets',
          {'status': status},
          where: _ticketFilter,
          whereArgs: [account, eventId, ticketId],
        );
      }
      await txn.update(
        'packs',
        {
          'checked_in': result.count.checkedIn,
          'total': result.count.total,
          if (result.outcome == ScanOutcome.eventCancelled)
            'status': 'cancelled',
        },
        where: _eventFilter,
        whereArgs: [account, eventId],
      );
    });
  }

  Future<void> revokePack(String account, String eventId) async {
    await (await _database).update(
      'packs',
      {'available': 0},
      where: _eventFilter,
      whereArgs: [account, eventId],
    );
  }

  Future<List<SyncConflict>> conflicts(String account, String eventId) async {
    final rows = await (await _database).query(
      'conflicts',
      where: _eventFilter,
      whereArgs: [account, eventId],
      orderBy: 'id DESC',
    );
    return [
      for (final row in rows)
        SyncConflict(
          row['attendee_name']! as String,
          SyncItem(
            outcome: ScanOutcome.fromApi(row['result']),
            checkedInAt: DateTime.tryParse(
              row['checked_in_at'] as String? ?? '',
            ),
            checkedInBy: row['checked_in_by'] as String?,
            checkedInDeviceId: row['checked_in_device_id'] as String?,
          ),
        ),
    ];
  }

  Future<Set<String>> eventsWithConflicts(String account) async {
    final rows = await (await _database).query(
      'conflicts',
      distinct: true,
      columns: ['event_id'],
      where: 'account = ?',
      whereArgs: [account],
    );
    return {for (final row in rows) row['event_id']! as String};
  }

  static const _eventFilter = 'account = ? AND event_id = ?';
  static const _ticketFilter = '$_eventFilter AND ticket_id = ?';
}
