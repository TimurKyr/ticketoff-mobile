import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ticketoff_mobile/core/api/checkin_service.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/l10n/language_selector.dart';
import 'package:ticketoff_mobile/features/auth/logout_action.dart';
import 'package:ticketoff_mobile/features/offline/offline_checkin.dart';
import 'package:ticketoff_mobile/features/offline/offline_status.dart';
import 'package:ticketoff_mobile/features/scan/scan_result.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.eventId,
    required this.repository,
    required this.onLogout,
    this.offline,
  });

  final String eventId;
  final ScanRepository repository;
  final Future<void> Function() onLogout;
  final OfflineCheckin? offline;

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
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    try {
      final count = await widget.repository.fetchCount(widget.eventId);
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
      final result = await widget.repository.scan(widget.eventId, token);
      if (!mounted) return;
      _receivedScanCount = true;
      _count = result.count;
      _outcome = result.outcome;
      _message = switch ((result.outcome, result.offline)) {
        (ScanOutcome.checkedIn, true) => 'Отмечен (офлайн)',
        (ScanOutcome.alreadyUsed, true) => 'Уже отмечен',
        _ => result.outcome.label,
      };
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
        title: Text(context.t(AppText.scanningTickets)),
        actions: [
          const LanguageSelector(),
          LogoutAction(onLogout: widget.onLogout),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.offline case final offline?)
              ListenableBuilder(
                listenable: offline,
                builder: (context, _) =>
                    _countLabel(offline.countFor(widget.eventId) ?? _count),
              )
            else
              _countLabel(_count),
            if (widget.offline case final offline?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OfflineStatus(offline: offline, eventId: widget.eventId),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (TickerMode.valuesOf(context).enabled)
                    switch (Theme.of(context).platform) {
                      TargetPlatform.windows ||
                      TargetPlatform.linux when !kIsWeb => Center(
                        child: Text(
                          context.t(AppText.cameraUnavailable),
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
                                  context.localizedMessage(message),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                                if (_ticketDetails case final details?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
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
                                Text(
                                  context.t(AppText.backToScanner),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
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

  Widget _countLabel(CheckinCount? count) {
    final checkedIn = count?.checkedIn.toString() ?? '—';
    final total = count?.total.toString() ?? '—';
    final label = switch (context.language) {
      AppLanguage.russian => 'Отмечено $checkedIn из $total',
      AppLanguage.kazakh => 'Кіргендер: $checkedIn / $total',
      AppLanguage.english => 'Checked in: $checkedIn of $total',
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
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
                MobileScannerErrorCode.permissionDenied => context.t(
                  AppText.cameraDenied,
                ),
                MobileScannerErrorCode.unsupported => context.t(
                  AppText.cameraUnavailable,
                ),
                _ => context.t(AppText.cameraFailure),
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
                    ? context.t(AppText.torchOff)
                    : context.t(AppText.torchOn),
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
