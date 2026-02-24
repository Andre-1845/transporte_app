import 'package:dio/dio.dart';

class ApiClient {
  late final Dio dio;

  ApiClient(String token) {
    dio = Dio(
      BaseOptions(
        baseUrl: "http://192.168.0.6:8000/api/v1",
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      ),
    );
  }
}
