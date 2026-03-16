import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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

  DriverService? driverService;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final auth = AuthService();
      final token = await auth.getToken();

      if (token == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      final api = ApiClient(token);
      driverService = DriverService(api.dio);

      final result = await driverService!.getTodayTrip();

      if (!mounted) return;

      setState(() {
        trip = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar viagem: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> startTracking(int tripId) async {
    if (sendingLocation) return;

    try {
      final auth = AuthService();
      final token = await auth.getToken();

      final bgService = FlutterBackgroundService();

      bool isRunning = await bgService.isRunning();

      if (!isRunning) {
        await bgService.startService();
      }

      bgService.invoke("setTrip", {"tripId": tripId, "token": token});

      if (!mounted) return;

      setState(() {
        sendingLocation = true;
      });
    } catch (e) {
      debugPrint("Erro ao iniciar rastreamento: $e");
    }
  }

  Future<void> stopTracking() async {
    try {
      final bgService = FlutterBackgroundService();

      bgService.invoke("stopService");

      if (!mounted) return;

      setState(() {
        sendingLocation = false;
      });
    } catch (e) {
      debugPrint("Erro ao parar rastreamento: $e");
    }
  }

  Future<void> handleLogout() async {
    await stopTracking();

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
      return Scaffold(
        appBar: AppBar(title: const Text("Motorista")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Motorista"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
        ],
      ),
      body: trip == null
          ? const Center(
              child: Text(
                "Nenhuma viagem programada para hoje",
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Trip ID: ${trip!['id']}",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Status: ${trip!['status']}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  if (!sendingLocation)
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          bool started = await driverService!.startTrip(
                            trip!['id'],
                          );

                          if (!started) {
                            debugPrint("Falha ao iniciar viagem");
                            return;
                          }

                          await startTracking(trip!['id']);

                          if (!mounted) return;

                          setState(() {
                            trip!['status'] = "in_progress";
                          });
                        } catch (e) {
                          debugPrint("Erro ao iniciar viagem: $e");
                        }
                      },
                      child: const Text("INICIAR VIAGEM"),
                    ),

                  if (sendingLocation)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        try {
                          await stopTracking();

                          bool finished = await driverService!.finishTrip(
                            trip!['id'],
                          );

                          if (!finished) {
                            debugPrint("Falha ao finalizar viagem");
                            return;
                          }

                          if (!mounted) return;

                          setState(() {
                            trip!['status'] = "finished";
                          });
                        } catch (e) {
                          debugPrint("Erro ao finalizar viagem: $e");
                        }
                      },
                      child: const Text("FINALIZAR VIAGEM"),
                    ),
                ],
              ),
            ),
    );
  }
}
