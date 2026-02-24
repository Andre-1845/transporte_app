import 'dart:async';
import 'package:flutter/material.dart';
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
  Timer? locationTimer;

  double testLat = -22.4705;
  double testLng = -44.4500;

  DriverService? service;

  @override
  void initState() {
    super.initState();
    initialize();
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

  void startLocationSending(int tripId) {
    if (sendingLocation) return;

    sendingLocation = true;

    locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      testLat += 0.0003;
      testLng += 0.0002;

      await service!.sendLocation(tripId, testLat, testLng);
    });

    setState(() {});
  }

  void stopLocationSending() {
    locationTimer?.cancel();
    sendingLocation = false;
    setState(() {});
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    super.dispose();
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = AuthService();
              await auth.logout();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
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
