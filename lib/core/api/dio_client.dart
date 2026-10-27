import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/core/config.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';

class DioClient {
  DioClient({
    SecureStorage? secureStorage,
    Future<void> Function()? onUnauthorized,
  }) : _secureStorage = secureStorage ?? SecureStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    )..interceptors.add(_AuthInterceptor(_secureStorage, onUnauthorized));
  }

  final SecureStorage _secureStorage;
  late final Dio dio;

  void close() => dio.close();
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._secureStorage, this._onUnauthorized);

  final SecureStorage _secureStorage;
  final Future<void> Function()? _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _secureStorage.clearToken();
      await _onUnauthorized?.call();
    }
    handler.next(err);
  }
}
