import 'package:dio/dio.dart';
import 'trip_model.dart';

class TripService {
  final Dio dio;

  TripService(this.dio);

  Future<List<Trip>> getActiveTrips() async {
    final response = await dio.get("/trips/active");

    final List data = response.data["data"];

    return data.map((e) => Trip.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getLatestLocation(int tripId) async {
    final response = await dio.get("/trips/$tripId/latest-location");

    return response.data["data"];
  }
}
