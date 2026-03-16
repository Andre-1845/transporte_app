import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DriverService {
  final Dio dio;

  DriverService(this.dio);

  Future<Map<String, dynamic>?> getTodayTrip() async {
    try {
      final response = await dio.get('/driver/today-trip');

      debugPrint("DRIVER TODAY TRIP RESPONSE: ${response.data}");

      return response.data['data'];
    } on DioException catch (e) {
      debugPrint("Erro ao buscar viagem do motorista");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");
      return null;
    } catch (e) {
      debugPrint("Erro inesperado: $e");
      return null;
    }
  }

  Future<bool> startTrip(int tripId) async {
    try {
      final response = await dio.post('/trips/$tripId/start');

      debugPrint("START TRIP RESPONSE: ${response.data}");

      return true;
    } on DioException catch (e) {
      debugPrint("Erro ao iniciar viagem");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");
      return false;
    }
  }

  Future<bool> finishTrip(int tripId) async {
    try {
      final response = await dio.post('/trips/$tripId/finish');

      debugPrint("FINISH TRIP RESPONSE: ${response.data}");

      return true;
    } on DioException catch (e) {
      debugPrint("Erro ao finalizar viagem");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");
      return false;
    }
  }

  Future<bool> sendLocation(int tripId, double lat, double lng) async {
    try {
      final response = await dio.post(
        '/trips/$tripId/location',
        data: {'latitude': lat, 'longitude': lng},
      );

      debugPrint("LOCATION SENT: ${response.data}");

      return true;
    } on DioException catch (e) {
      debugPrint("Erro ao enviar localização");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");
      return false;
    }
  }
}
