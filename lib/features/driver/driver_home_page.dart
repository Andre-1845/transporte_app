import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import '../auth/login_page.dart';
import 'driver_service.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  Map<String, dynamic>? trip;
  bool loading = true;
  bool sendingLocation = false;

  StreamSubscription<Position>? positionStream;

  DriverService? service;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    final auth = AuthService();
    final token = await auth.getToken();

    if (token == null) return;

    final api = ApiClient(token);
    service = DriverService(api.dio);

    final result = await service!.getTodayTrip();

    if (!mounted) return;

    setState(() {
      trip = result;
      loading = false;
    });
  }

  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // verifica se GPS está ligado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS desligado");
      return false;
    }

    // verifica permissão atual
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        debugPrint("Permissão negada");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permissão negada permanentemente");
      return false;
    }

    return true;
  }

  void startLocationSending(int tripId) async {
    if (sendingLocation) return;

    bool permissionGranted = await checkLocationPermission();

    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permissão de localização necessária")),
      );
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            await service!.sendLocation(
              tripId,
              position.latitude,
              position.longitude,
            );
          },
        );

    sendingLocation = true;

    setState(() {});
  }

  void stopLocationSending() {
    positionStream?.cancel();
    sendingLocation = false;
    setState(() {});
  }

  Future<void> handleLogout() async {
    stopLocationSending();

    final auth = AuthService();
    await auth.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (trip == null) {
      return const Scaffold(body: Center(child: Text("Nenhuma viagem hoje")));
    }

    final tripId = trip!['id'];
    final status = trip!['status'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Motorista"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Trip ID: $tripId", style: const TextStyle(fontSize: 18)),

            const SizedBox(height: 10),

            Text("Status: $status", style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 30),

            if (!sendingLocation)
              ElevatedButton(
                onPressed: () async {
                  await service!.startTrip(tripId);
                  startLocationSending(tripId);
                },
                child: const Text("INICIAR VIAGEM"),
              ),

            if (sendingLocation)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  stopLocationSending();
                  await service!.finishTrip(tripId);
                },
                child: const Text("FINALIZAR VIAGEM"),
              ),
          ],
        ),
      ),
    );
  }
}
