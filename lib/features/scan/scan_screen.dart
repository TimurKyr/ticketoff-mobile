import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.eventId,
    required this.repository,
    required this.onLogout,
  });

  final String? eventId;
  final ScanRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _clock = Stopwatch()..start();
  final _recentTokens = <String, Duration>{};
  Timer? _returnTimer;
  CheckinCount? _count;
  ScanOutcome? _outcome;
  String? _message;
  String? _ticketDetails;
  bool _pending = false;
  bool _receivedScanCount = false;

  @override
  void initState() {
    super.initState();
    final eventId = widget.eventId;
    if (eventId != null) unawaited(_loadCount(eventId));
  }

  Future<void> _loadCount(String eventId) async {
    try {
      final count = await widget.repository.fetchCount(eventId);
      if (mounted && !_receivedScanCount) setState(() => _count = count);
    } on Exception {
      // A successful scan provides the authoritative count if stats fail.
    }
  }

  Future<void> _scan(String token) async {
    if (!mounted ||
        _pending ||
        _message != null ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    final now = _clock.elapsed;
    _recentTokens.removeWhere(
      (_, sentAt) => now - sentAt >= const Duration(seconds: 2),
    );
    if (_recentTokens.containsKey(token)) return;
    _recentTokens[token] = now;
    setState(() => _pending = true);

    try {
      final result = await widget.repository.scan(widget.eventId!, token);
      if (!mounted) return;
      _receivedScanCount = true;
      _count = result.count;
      _outcome = result.outcome;
      _message = result.outcome.label;
      if (result.outcome == ScanOutcome.checkedIn) {
        _ticketDetails = '${result.attendeeName}\n${result.ticketType}';
      }
    } on ScanFailure catch (error) {
      if (!mounted) return;
      _message = error.message;
    }
    setState(() => _pending = false);
    _returnTimer = Timer(const Duration(seconds: 3), _dismissResult);
  }

  void _dismissResult() {
    _returnTimer?.cancel();
    setState(() {
      _outcome = null;
      _message = null;
      _ticketDetails = null;
    });
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasEvent = widget.eventId != null;
    final count = _count;
    final (color, icon) = switch (_outcome) {
      ScanOutcome.checkedIn => (const Color(0xFF146C36), Icons.check_circle),
      ScanOutcome.alreadyUsed => (
        const Color(0xFFA84400),
        Icons.warning_rounded,
      ),
      _ => (const Color(0xFFB42318), Icons.cancel),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(hasEvent ? 'Сканирование билетов' : 'Сканер'),
        actions: [LogoutAction(onLogout: widget.onLogout)],
      ),
      body: SafeArea(
        child: !hasEvent
            ? const Center(
                child: Text(
                  'Выберите назначенное событие, чтобы начать сканирование',
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      count == null
                          ? 'Отмечено — из —'
                          : 'Отмечено ${count.checkedIn} из ${count.total}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (TickerMode.valuesOf(context).enabled)
                          switch (Theme.of(context).platform) {
                            TargetPlatform.windows ||
                            TargetPlatform.linux when !kIsWeb => const Center(
                              child: Text(
                                'Сканирование камерой недоступно на этом устройстве.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            _ => _CameraPreview(onToken: _scan),
                          },
                        if (_pending)
                          const ColoredBox(
                            color: Colors.black54,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_message case final message?)
                          Material(
                            color: color,
                            child: InkWell(
                              onTap: _dismissResult,
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, color: Colors.white, size: 72),
                                      const SizedBox(height: 16),
                                      Text(
                                        message,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                      if (_ticketDetails case final details?)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            details,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Нажмите, чтобы вернуться к сканеру',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CameraPreview extends StatefulWidget {
  const _CameraPreview({required this.onToken});

  final Future<void> Function(String token) onToken;

  @override
  State<_CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<_CameraPreview>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs can interrupt the initial camera startup.
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.start());
    } else if (state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final token = capture.barcodes
                .map((barcode) => barcode.rawValue)
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .firstOrNull;
            if (token != null) unawaited(widget.onToken(token));
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(switch (error.errorCode) {
                MobileScannerErrorCode.permissionDenied =>
                  'Нет доступа к камере. Разрешите доступ в настройках '
                      'приложения и снова откройте сканер.',
                MobileScannerErrorCode.unsupported =>
                  'Сканирование камерой недоступно на этом устройстве.',
                _ => 'Не удалось запустить камеру. Снова откройте сканер.',
              }, textAlign: TextAlign.center),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              final torch = state.torchState;
              if (!state.isRunning || torch == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              return IconButton.filled(
                tooltip: torch == TorchState.on
                    ? 'Выключить фонарик'
                    : 'Включить фонарик',
                onPressed: _controller.toggleTorch,
                icon: Icon(
                  torch == TorchState.on ? Icons.flash_on : Icons.flash_off,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
