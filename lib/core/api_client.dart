import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio dio;

  ApiClient([String? token]) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      ),
    );
  }
}
