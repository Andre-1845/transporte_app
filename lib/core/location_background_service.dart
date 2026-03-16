import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../features/driver/driver_service.dart';
import 'api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  int? tripId;
  String? token;
  Timer? timer;

  service.on("setTrip").listen((event) {
    tripId = event?["tripId"];
    token = event?["token"];

    debugPrint("Background service iniciado para trip: $tripId");
  });

  service.on("stopService").listen((event) {
    debugPrint("Parando serviço de localização");

    timer?.cancel();
    service.stopSelf();
  });

  timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (tripId == null || token == null) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("Permissão de localização negada");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final api = ApiClient(token!);
      final driverService = DriverService(api.dio);

      await driverService.sendLocation(
        tripId!,
        position.latitude,
        position.longitude,
      );

      debugPrint(
        "Localização enviada: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      debugPrint("Erro ao enviar localização: $e");
    }
  });
}
