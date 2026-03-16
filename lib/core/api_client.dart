import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio dio;

  ApiClient([String? token]) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      ),
    );

    // LOG COMPLETO (somente debug)
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint("API REQUEST → ${options.method} ${options.uri}");
          handler.next(options);
        },

        onResponse: (response, handler) {
          debugPrint("API RESPONSE → ${response.statusCode}");
          handler.next(response);
        },

        onError: (DioException e, handler) async {
          debugPrint("API ERROR → ${e.message}");

          if (e.response != null) {
            debugPrint("STATUS: ${e.response?.statusCode}");
            debugPrint("DATA: ${e.response?.data}");
          }

          // TOKEN EXPIRADO
          if (e.response?.statusCode == 401) {
            debugPrint("Token expirado ou inválido");
          }

          // RETRY AUTOMÁTICO (1 tentativa apenas)
          final shouldRetry =
              (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError);

          final alreadyRetried = e.requestOptions.extra["retry"] == true;

          if (shouldRetry && !alreadyRetried) {
            debugPrint("Tentando novamente...");

            try {
              e.requestOptions.extra["retry"] = true;

              final response = await dio.request(
                e.requestOptions.path,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                ),
              );

              return handler.resolve(response);
            } catch (retryError) {
              debugPrint("Retry falhou");
            }
          }

          handler.next(e);
        },
      ),
    );
  }

  // atualizar token
  void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }

  // remover token
  void clearToken() {
    dio.options.headers.remove("Authorization");
  }
}
