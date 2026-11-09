import 'package:dio/dio.dart';
import 'package:ticketoff_mobile/core/config.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';

class DioClient {
  DioClient({
    TokenStorage? secureStorage,
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

  final TokenStorage _secureStorage;
  late final Dio dio;

  void close() => dio.close();
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._onUnauthorized);

  final TokenStorage _storage;
  final Future<void> Function()? _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.readToken();
    if (token != null &&
        token.isNotEmpty &&
        !options.path.startsWith('/auth/')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.startsWith('/auth/login')) {
      await _storage.clearToken();
      await _onUnauthorized?.call();
    }
    handler.next(err);
  }
}
