import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/l10n/language_selector.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

final _site = Uri.https('ticketoff.store');
const _documents = MethodChannel('ticketoff/guest_documents');
const _maxDownloadBytes = 8 * 1024 * 1024;

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  WebViewController? _webView;
  Uri _lastPage = _site;
  bool _loading = true;
  bool _languageReady = false;
  int _webLanguageRevision = 0;
  bool _failed = false;
  bool _canGoBack = false;
  bool _saving = false;

  bool get _embedded =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_embedded) _load();
  }

  Future<void> _load() async {
    try {
      final webView = WebViewController();
      await webView.setBackgroundColor(AppTheme.background);
      await webView.setJavaScriptMode(JavaScriptMode.unrestricted);
      await webView.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _navigate,
          onUrlChange: (change) => _rememberPage(change.url),
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: _pageFinished,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _showFailure();
          },
          onHttpError: (error) {
            if (error.request?.uri == _lastPage) _showFailure();
          },
        ),
      );
      await webView.addJavaScriptChannel(
        'TicketoffDownload',
        onMessageReceived: _saveDocument,
      );
      await webView.addJavaScriptChannel(
        'TicketoffLanguage',
        onMessageReceived: _applyWebLanguage,
      );
      if (webView.platform case final AndroidWebViewController android) {
        await android.setOnShowFileSelector(_pickFiles);
      }
      if (!mounted) return;
      setState(() => _webView = webView);
      await webView.loadRequest(_lastPage);
    } on Exception {
      _showFailure();
    }
  }

  bool _isSite(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == _site.host &&
      uri.port == _site.port &&
      uri.userInfo.isEmpty;

  NavigationDecision _navigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri != null && _isSite(uri)) return NavigationDecision.navigate;
    if (request.isMainFrame &&
        uri != null &&
        (uri.scheme == 'https' ||
            uri.scheme == 'mailto' ||
            uri.scheme == 'tel')) {
      _openBrowser(uri);
    }
    return NavigationDecision.prevent;
  }

  Future<void> _rememberPage(String? url) async {
    if (!mounted) return;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !_isSite(uri)) return;
    _lastPage = uri;
    final canGoBack = await _webView?.canGoBack() ?? false;
    if (mounted && _canGoBack != canGoBack) {
      setState(() => _canGoBack = canGoBack);
    }
  }

  Future<void> _pageFinished(String url) async {
    if (!mounted || _failed) return;
    await _rememberPage(url);
    if (!mounted || _failed) return;
    final uri = Uri.tryParse(url);
    if (uri != null && _isSite(uri)) {
      try {
        final preferred = _languageReady
            ? null
            : context.language.locale.languageCode;
        final reloading = await _webView?.runJavaScriptReturningResult(
          '$_languageHandler(${jsonEncode(preferred)})',
        );
        if (reloading == true || reloading == 'true') return;
        await _webView?.runJavaScript(_downloadHandler);
      } on Exception {
        // A navigation may replace the page during script installation.
      }
    }
    if (!mounted || _failed) return;
    setState(() {
      _languageReady = true;
      _loading = false;
    });
  }

  Future<void> _applyWebLanguage(JavaScriptMessage message) async {
    if (!mounted || !_languageReady) return;
    final language = AppLanguage.values
        .where((option) => option.locale.languageCode == message.message)
        .firstOrNull;
    if (language == null) return;
    final revision = ++_webLanguageRevision;
    try {
      final url = Uri.tryParse(await _webView?.currentUrl() ?? '');
      if (!mounted ||
          revision != _webLanguageRevision ||
          url == null ||
          !_isSite(url) ||
          language == context.language) {
        return;
      }
      context.getInheritedWidgetOfExactType<LanguageSettings>()?.onChanged(
        language,
      );
    } on PlatformException {
      // The WebView may have closed while we were checking its URL.
    }
  }

  void _showFailure() {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    if (_webView == null) {
      await _load();
    } else {
      try {
        await _webView!.loadRequest(_lastPage);
      } on Exception {
        _showFailure();
      }
    }
  }

  Future<void> _back() async {
    if (_canGoBack && !_failed) {
      await _webView?.goBack();
      return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openBrowser(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // Report the same message for an unavailable handler.
    }
    _message(AppText.linkOpenFailed);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      return await _documents.invokeListMethod<String>('pick', {
            'multiple': params.mode == FileSelectorMode.openMultiple,
            'types': params.acceptTypes,
          }) ??
          const [];
    } on PlatformException {
      _message(AppText.filePickFailed);
      return const [];
    }
  }

  Future<void> _saveDocument(JavaScriptMessage message) async {
    if (_saving || message.message.length > _maxDownloadBytes * 4 ~/ 3 + 1024) {
      return;
    }
    _saving = true;
    try {
      final url = Uri.tryParse(await _webView?.currentUrl() ?? '');
      if (!mounted || url == null || !_isSite(url)) return;
      final data = jsonDecode(message.message);
      if (data is! Map || data['error'] == true) {
        _message(AppText.fileDownloadFailed);
        return;
      }
      final name = data['name'];
      final encoded = data['bytes'];
      if (name is! String ||
          encoded is! String ||
          name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.length > 120 ||
          RegExp(r'[/\\\x00-\x1f]').hasMatch(name)) {
        return;
      }
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > _maxDownloadBytes) return;
      await _documents.invokeMethod<void>('save', {
        'name': name,
        'bytes': bytes,
      });
    } on FormatException {
      _message(AppText.fileDownloadFailed);
    } on PlatformException {
      _message(AppText.fileSaveFailed);
    } finally {
      _saving = false;
    }
  }

  void _message(AppText text) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(text))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final webView = _webView;
    return PopScope(
      canPop: !_canGoBack || _failed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t(AppText.guest)),
          leading: BackButton(onPressed: _back),
          actions: [
            IconButton(
              tooltip: context.t(AppText.openInBrowser),
              onPressed: () => _openBrowser(_lastPage),
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: SafeArea(
          child: webView == null && _embedded && !_failed
              ? const Center(child: CircularProgressIndicator())
              : _failed || webView == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_failed) ...[
                          Text(context.t(AppText.ticketoffLoadFailed)),
                          TextButton(
                            onPressed: _retry,
                            child: Text(context.t(AppText.retry)),
                          ),
                        ],
                        TextButton(
                          onPressed: () => _openBrowser(_lastPage),
                          child: Text(
                            context.t(AppText.openTicketoffInBrowser),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    WebViewWidget(controller: webView),
                    if (!_languageReady)
                      const ColoredBox(color: AppTheme.background),
                    if (_loading)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Ticketoff Web reads this preference when its I18nProvider mounts and
// publishes subsequent selections on the document's lang attribute.
const _languageHandler = r'''
((preferred) => {
  if (location.origin !== 'https://ticketoff.store') return false;
  const root = document.documentElement;
  try {
    const key = 'ticketoff.lang';
    if (preferred && localStorage.getItem(key) !== preferred) {
      localStorage.setItem(key, preferred);
      if (root.lang !== preferred) {
        setTimeout(() => location.reload(), 0);
        return true;
      }
    }
  } catch (_) {
    // The site's own language selector works even when storage is unavailable.
  }
  if (!window.ticketoffMobileLanguage) {
    window.ticketoffMobileLanguage = new MutationObserver(() => {
      TicketoffLanguage.postMessage(root.lang);
    });
    window.ticketoffMobileLanguage.observe(root, {
      attributes: true,
      attributeFilter: ['lang'],
    });
  }
  return false;
})
''';

// The web app creates temporary blob URLs for authenticated PDFs and support
// attachments. Read them inside the same origin before the app revokes them.
const _downloadHandler = r'''
(() => {
  if (location.origin !== 'https://ticketoff.store' || window.ticketoffMobile) return;
  window.ticketoffMobile = true;
  document.addEventListener('click', async (event) => {
    const link = event.target instanceof Element && event.target.closest('a[href]');
    if (!link) return;
    const url = new URL(link.href, location.href);
    if (link.target === '_blank') link.target = '_self';
    if (!link.hasAttribute('download')) return;
    const allowed = url.origin === location.origin ||
      (url.origin === 'https://api.ticketoff.store' && url.pathname.endsWith('.ics'));
    if (!allowed) return;
    event.preventDefault();
    try {
      const response = await fetch(url);
      if (!response.ok) throw Error();
      const blob = await response.blob();
      if (!blob.size || blob.size > 8 * 1024 * 1024) throw Error();
      const reader = new FileReader();
      reader.onload = () => TicketoffDownload.postMessage(JSON.stringify({
        name: link.download || url.pathname.split('/').pop(),
        bytes: reader.result.split(',')[1],
      }));
      reader.onerror = () => TicketoffDownload.postMessage('{"error":true}');
      reader.readAsDataURL(blob);
    } catch (_) {
      TicketoffDownload.postMessage('{"error":true}');
    }
  }, true);
})();
''';
