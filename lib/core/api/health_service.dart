import 'package:dio/dio.dart';

abstract interface class HealthStatusSource {
  Future<bool> check();
}

class HealthService implements HealthStatusSource {
  const HealthService(this._dio);

  final Dio _dio;

  @override
  Future<bool> check() async {
    try {
      final response = await _dio.get<Object?>('/health');
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException {
      return false;
    }
  }
}
