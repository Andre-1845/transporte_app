import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import 'trip_service.dart';

class MapPage extends StatefulWidget {
  final int tripId;

  const MapPage({super.key, required this.tripId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Set<Marker> markers = {};
  Timer? timer;
  TripService? service;
  late GoogleMapController mapController;

  // 🔥 ATIVE/DESATIVE AQUI
  bool simulationMode = true;

  // Coordenadas iniciais (Resende RJ exemplo)
  double testLat = -22.4705;
  double testLng = -44.4500;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    if (simulationMode) {
      startSimulation();
    } else {
      final auth = AuthService();
      final token = await auth.getToken();

      if (token == null) return;

      final api = ApiClient(token);
      service = TripService(api.dio);

      startPolling();
    }
  }

  // 🚍 SIMULA MOVIMENTO
  void startSimulation() {
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      testLat += 0.0003;
      testLng += 0.0002;

      updateBusPosition(LatLng(testLat, testLng));
    });
  }

  // 🌍 USA BACKEND REAL
  void startPolling() {
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (service == null) return;

      try {
        final data = await service!.getLatestLocation(widget.tripId);

        if (data == null) return;

        final lat = double.parse(data["lat"].toString());
        final lng = double.parse(data["lng"].toString());

        updateBusPosition(LatLng(lat, lng));
      } catch (e) {
        debugPrint("Erro ao buscar localização: $e");
      }
    });
  }

  void updateBusPosition(LatLng position) {
    if (!mounted) return;

    setState(() {
      markers = {Marker(markerId: const MarkerId("bus"), position: position)};
    });

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          simulationMode ? "Mapa da Trip (SIMULAÇÃO)" : "Mapa da Trip",
        ),
      ),
      body: SizedBox.expand(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(testLat, testLng),
            zoom: 14,
          ),
          markers: markers,
          onMapCreated: (controller) {
            mapController = controller;
          },
        ),
      ),
    );
  }
}
