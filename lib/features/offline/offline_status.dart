import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/l10n/stable_localized_text.dart';
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
                StableLocalizedText(
                  AppText.offline.inLanguage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (pack != null)
                StableLocalizedText(
                  pack.available
                      ? (language) => AppText.packDate.inLanguage(
                          language,
                          _formatDownloadTime(pack.generatedAt),
                        )
                      : AppText.packUnavailable.inLanguage,
                ),
              if (pack != null || offline.isOffline)
                StableLocalizedText(
                  (language) => AppText.unsent.inLanguage(language, pending),
                ),
            ],
          ),
          if (syncError != null)
            StableLocalizedText(
              (language) =>
                  context.localizedMessage(syncError, forLanguage: language),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (offline.isOffline && pack == null)
            StableLocalizedText(AppText.packNotDownloaded.inLanguage),
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
                  label: StableLocalizedText(
                    (downloading
                            ? AppText.downloading
                            : pack?.available == true
                            ? AppText.updatePack
                            : AppText.downloadPack)
                        .inLanguage,
                  ),
                ),
              if (pending > 0 && pack!.available)
                TextButton(
                  onPressed: offline.isSyncing ? null : offline.syncNow,
                  child: StableLocalizedText(
                    (offline.isSyncing ? AppText.syncing : AppText.sync)
                        .inLanguage,
                  ),
                ),
              if (offline.hasConflicts(eventId))
                TextButton.icon(
                  onPressed: () => _showConflicts(context),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: StableLocalizedText(AppText.conflicts.inLanguage),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizedMessage(error.message))),
      );
    }
  }

  void _showConflicts(BuildContext context) {
    final conflicts = offline.conflicts(eventId);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t(AppText.syncConflicts)),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: FutureBuilder<List<SyncConflict>>(
            future: conflicts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(context.t(AppText.loadConflictsFailure));
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
            child: Text(context.t(AppText.close)),
          ),
        ],
      ),
    );
  }

  String _description(BuildContext context, SyncItem item) {
    if (item.outcome != ScanOutcome.alreadyUsed) {
      return context.localizedMessage(item.outcome.label);
    }
    final timestamp = item.checkedInAt;
    final time = timestamp == null ? '' : _formatTime(context, timestamp);
    final source = item.checkedInDeviceId == null
        ? context.t(AppText.checkInSourceOnline)
        : context.t(AppText.checkInSourceDevice);
    final actor = item.checkedInBy == null ? '' : ' (${item.checkedInBy})';
    return switch (context.language) {
      AppLanguage.russian =>
        'Уже прошёл${time.isEmpty ? '' : ' в $time'} $source$actor',
      AppLanguage.kazakh =>
        '$source кіргені белгіленген${time.isEmpty ? '' : ' ($time)'}$actor',
      AppLanguage.english =>
        'Already checked in${time.isEmpty ? '' : ' at $time'} $source$actor',
    };
  }

  static String _formatDownloadTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    final date =
        '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year}';
    final time = '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$date, $time';
  }

  static String _formatTime(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(value.toLocal()),
        alwaysUse24HourFormat: true,
      );
}
