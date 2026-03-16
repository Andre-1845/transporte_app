import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'trip_model.dart';

class TripService {
  final Dio dio;

  TripService(this.dio);

  /// BUSCAR TRIPS DO DIA
  Future<Map<String, List<Trip>>> getTodayTrips() async {
    try {
      final response = await dio.get("/trips/today");

      debugPrint("TODAY TRIPS RESPONSE: ${response.data}");

      final data = response.data["data"];

      final active = (data["active"] as List? ?? [])
          .map((e) => Trip.fromJson(e))
          .toList();

      final scheduled = (data["scheduled"] as List? ?? [])
          .map((e) => Trip.fromJson(e))
          .toList();

      return {"active": active, "scheduled": scheduled};
    } on DioException catch (e) {
      debugPrint("Erro ao buscar trips");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");

      return {"active": [], "scheduled": []};
    } catch (e) {
      debugPrint("Erro inesperado: $e");

      return {"active": [], "scheduled": []};
    }
  }

  /// BUSCAR ÚLTIMA LOCALIZAÇÃO DO ÔNIBUS
  Future<Map<String, dynamic>> getLatestLocation(int tripId) async {
    try {
      final response = await dio.get("/trips/$tripId/latest-location");

      debugPrint("LATEST LOCATION RESPONSE: ${response.data}");

      return response.data["data"] ?? {};
    } on DioException catch (e) {
      debugPrint("Erro ao buscar localização");
      debugPrint("STATUS: ${e.response?.statusCode}");
      debugPrint("DATA: ${e.response?.data}");

      return {};
    } catch (e) {
      debugPrint("Erro inesperado: $e");
      return {};
    }
  }
}
