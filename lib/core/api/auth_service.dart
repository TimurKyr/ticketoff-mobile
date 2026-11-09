import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:ticketoff_mobile/core/storage/secure_storage.dart';

abstract interface class AuthGateway {
  Future<bool> hasSession();
  Future<void> login(String email, String password);
  Future<void> logout();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionFailure implements Exception {
  const SessionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService implements AuthGateway {
  const AuthService(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  @override
  Future<bool> hasSession() async {
    try {
      final token = await _storage.readToken();
      return token != null && token.isNotEmpty;
    } on PlatformException {
      throw const SessionFailure('Не удалось восстановить сохранённую сессию');
    }
  }

  @override
  Future<void> login(String email, String password) async {
    final Response<Object?> response;
    try {
      response = await _dio.post<Object?>(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (error) {
      throw _loginFailure(error);
    }

    final body = response.data;
    final token = body is Map<String, dynamic> ? body['access_token'] : null;
    if (token is! String || token.isEmpty) {
      throw const AuthFailure('Сервер вернул некорректный ответ');
    }

    try {
      await _storage.writeToken(token);
    } on PlatformException {
      throw const SessionFailure('Не удалось сохранить сессию на устройстве');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _storage.clearToken();
    } on PlatformException {
      throw const SessionFailure('Не удалось завершить сессию на устройстве');
    }
  }

  AuthFailure _loginFailure(DioException error) {
    if (error.response?.statusCode == 401) {
      return const AuthFailure('Неверный email или пароль');
    }
    if (error.response == null) {
      return const AuthFailure('Не удалось подключиться к серверу');
    }

    final responseData = error.response?.data;
    final detail = responseData is Map<String, dynamic>
        ? responseData['detail']
        : null;
    if (detail is String && detail.isNotEmpty) {
      return AuthFailure(detail);
    }
    return AuthFailure('Ошибка входа (${error.response?.statusCode})');
  }
}
