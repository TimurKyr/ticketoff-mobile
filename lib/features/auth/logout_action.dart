import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';

class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  Future<void> _logout(BuildContext context) async {
    try {
      await onLogout();
    } on SessionFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('logout'),
      tooltip: 'Выйти',
      onPressed: () => _logout(context),
      icon: const Icon(Icons.logout_rounded),
    );
  }
}
