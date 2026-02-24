import 'package:dio/dio.dart';

class DriverService {
  final Dio dio;

  DriverService(this.dio);

  Future<Map<String, dynamic>?> getTodayTrip() async {
    final response = await dio.get('/driver/today-trip');
    return response.data['data'];
  }

  Future<void> startTrip(int tripId) async {
    await dio.post('/trips/$tripId/start');
  }

  Future<void> finishTrip(int tripId) async {
    await dio.post('/trips/$tripId/finish');
  }

  Future<void> sendLocation(int tripId, double lat, double lng) async {
    await dio.post(
      '/trips/$tripId/location',
      data: {'latitude': lat, 'longitude': lng},
    );
  }
}
