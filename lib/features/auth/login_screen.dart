import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/api/auth_service.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/l10n/language_selector.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authGateway,
    required this.onAuthenticated,
  });

  final AuthGateway authGateway;
  final Future<void> Function() onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _loginError;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      await widget.authGateway.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) await widget.onAuthenticated();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _loginError = error.message);
    } on SessionFailure catch (error) {
      if (mounted) setState(() => _loginError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _validationError(BuildContext context, String message) =>
      Text(context.localizedMessage(message), maxLines: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t(AppText.back),
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: const [LanguageSelector()],
        title: Text(context.t(AppText.controllerSignIn)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.tint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppTheme.brandDeep,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.t(AppText.welcomeBack),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(AppText.signInForEvents),
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('controller-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.t(AppText.email),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? AppText.enterEmail.russian
                          : null,
                      errorBuilder: _validationError,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('controller-password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: context.t(AppText.password),
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? context.t(AppText.showPassword)
                              : context.t(AppText.hidePassword),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? AppText.enterPassword.russian
                          : null,
                      errorBuilder: _validationError,
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        context.localizedMessage(_loginError!),
                        key: const Key('login-error'),
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.t(AppText.signIn)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
