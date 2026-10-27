import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Authentication will be connected to the API here.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/events'),
                child: const Text('Back to events'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
