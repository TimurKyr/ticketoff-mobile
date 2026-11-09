import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key, this.eventId, required this.onLogout});

  final String? eventId;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер'),
        actions: [LogoutAction(onLogout: onLogout)],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppTheme.tint,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.brandDeep,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  eventId == null
                      ? 'Выберите назначенное событие, чтобы начать сканирование'
                      : 'Сканирование билетов',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (eventId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Мероприятие: $eventId',
                    style: const TextStyle(color: AppTheme.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
