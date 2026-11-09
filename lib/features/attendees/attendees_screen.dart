import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';

class AttendeesScreen extends StatelessWidget {
  const AttendeesScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Участники'),
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
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.tint,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    color: AppTheme.brandDeep,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Участники',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Поиск участников скоро появится',
                  style: TextStyle(color: AppTheme.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
