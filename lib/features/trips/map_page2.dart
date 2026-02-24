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
  TripService? service; // 👈 agora pode ser nullable
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    initialize(); // 👈 chama função async separada
  }

  Future<void> initialize() async {
    final auth = AuthService();
    final token = await auth.getToken();

    if (token == null) return;

    final api = ApiClient(token);
    service = TripService(api.dio);

    startPolling();
  }

  void startPolling() {
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (service == null) return;

      try {
        final data = await service!.getLatestLocation(widget.tripId);

        final lat = double.parse(data["lat"].toString());
        final lng = double.parse(data["lng"].toString());

        if (!mounted) return;

        setState(() {
          markers = {
            Marker(markerId: const MarkerId("bus"), position: LatLng(lat, lng)),
          };
        });

        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: 16),
          ),
        );
      } catch (e) {
        debugPrint("Erro ao buscar localização: $e");
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapa da Trip")),
      body: SizedBox.expand(
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(-22.9, -43.2),
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
