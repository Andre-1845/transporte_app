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
  List<Trip> trips = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    try {
      final auth = AuthService();
      final token = await auth.getToken();

      if (token == null) {
        setState(() => loading = false);
        return;
      }

      final api = ApiClient(token);
      final service = TripService(api.dio);

      final result = await service.getActiveTrips();

      if (!mounted) return;

      setState(() {
        trips = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar trips: $e");
      setState(() => loading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trips Ativas"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
          ? const Center(
              child: Text(
                "Nenhuma viagem ativa no momento",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: trips.length,
              itemBuilder: (_, i) {
                return ListTile(
                  title: Text(trips[i].name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPage(tripId: trips[i].id),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
