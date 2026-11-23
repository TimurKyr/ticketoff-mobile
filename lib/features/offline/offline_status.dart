import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/features/events/assigned_event.dart';
import 'package:ticketoff_mobile/features/offline/offline_api.dart';
import 'package:ticketoff_mobile/features/offline/offline_checkin.dart';
import 'package:ticketoff_mobile/features/offline/offline_models.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class OfflineStatus extends StatelessWidget {
  const OfflineStatus({
    super.key,
    required this.offline,
    required this.eventId,
    this.downloadEvent,
  });

  final OfflineCheckin offline;
  final String eventId;
  final AssignedEvent? downloadEvent;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: offline,
    builder: (context, _) {
      final pack = offline.packFor(eventId);
      final pending = pack?.pending ?? 0;
      final syncError = offline.syncError(eventId);
      final download = downloadEvent ?? offline.eventFor(eventId);
      final downloading = offline.isDownloading(eventId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (offline.isOffline)
                const Text(
                  'Офлайн',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              if (pack != null)
                Text(
                  pack.available
                      ? 'Пакет от ${_formatDownloadTime(context, pack.generatedAt)}'
                      : 'Пакет недоступен',
                ),
              if (pack != null || offline.isOffline)
                Text('Не отправлено: $pending'),
            ],
          ),
          if (syncError != null)
            Text(
              syncError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (offline.isOffline && pack == null)
            const Text('Офлайн-пакет не скачан'),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (download != null)
                TextButton.icon(
                  onPressed: downloading || offline.isOffline
                      ? null
                      : () => _download(context, download),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    downloading
                        ? 'Скачиваем…'
                        : pack?.available == true
                        ? 'Обновить пакет'
                        : 'Скачать для офлайна',
                  ),
                ),
              if (pending > 0 && pack!.available)
                TextButton(
                  onPressed: offline.isSyncing ? null : offline.syncNow,
                  child: Text(
                    offline.isSyncing ? 'Синхронизируем…' : 'Синхронизировать',
                  ),
                ),
              if (offline.hasConflicts(eventId))
                TextButton.icon(
                  onPressed: () => _showConflicts(context),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Конфликты'),
                ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _download(BuildContext context, AssignedEvent event) async {
    try {
      await offline.download(event);
    } on OfflineRequestFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showConflicts(BuildContext context) {
    final conflicts = offline.conflicts(eventId);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Конфликты синхронизации'),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: FutureBuilder<List<SyncConflict>>(
            future: conflicts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Не удалось загрузить конфликты');
              }
              final items = snapshot.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final conflict = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(conflict.attendee),
                    subtitle: Text(_description(context, conflict.item)),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _description(BuildContext context, SyncItem item) {
    if (item.outcome != ScanOutcome.alreadyUsed) return item.outcome.label;
    final timestamp = item.checkedInAt;
    final time = timestamp == null
        ? ''
        : ' в ${_formatTime(context, timestamp)}';
    final source = item.checkedInDeviceId == null
        ? 'онлайн или вручную'
        : 'на другом устройстве';
    final actor = item.checkedInBy == null ? '' : ' (${item.checkedInBy})';
    return 'Уже прошёл$time $source$actor';
  }

  static String _formatDownloadTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatCompactDate(local);
    return '$date, ${_formatTime(context, value)}';
  }

  static String _formatTime(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(value.toLocal()),
        alwaysUse24HourFormat: true,
      );
}
