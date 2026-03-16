import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import '../auth/login_page.dart';
import 'trip_service.dart';
import 'trip_model.dart';
import 'map_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<Trip> activeTrips = [];
  List<Trip> scheduledTrips = [];
  bool loading = true;

  Future<void> handleLogout() async {
    final auth = AuthService();
    await auth.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> loadTrips() async {
    try {
      final auth = AuthService();
      final token = await auth.getToken();

      final api = ApiClient(token);
      final service = TripService(api.dio);

      final result = await service.getTodayTrips();

      if (!mounted) return;

      setState(() {
        activeTrips = result["active"] ?? [];
        scheduledTrips = result["scheduled"] ?? [];
        loading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar trips: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Widget buildTripTile(Trip trip, bool active) {
    return ListTile(
      title: Text(trip.name),
      subtitle: Text(trip.startTime ?? ""),
      trailing: active
          ? const Icon(Icons.directions_bus, color: Colors.green)
          : const Icon(Icons.schedule),
      onTap: active
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MapPage(tripId: trip.id)),
              );
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Transporte Escolar")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transporte Escolar"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
        ],
      ),

      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Viagens em andamento",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          if (activeTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text("Nenhuma viagem em andamento"),
            ),

          ...activeTrips.map((t) => buildTripTile(t, true)),

          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Viagens agendadas",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          if (scheduledTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text("Nenhuma viagem agendada"),
            ),

          ...scheduledTrips.map((t) => buildTripTile(t, false)),
        ],
      ),
    );
  }
}
