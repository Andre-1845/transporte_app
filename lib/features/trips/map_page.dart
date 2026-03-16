import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import '../auth/login_page.dart';
import 'trip_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../../core/websocket_service.dart';

class MapPage extends StatefulWidget {
  final int tripId;

  MapPage({super.key, required this.tripId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Set<Marker> markers = {};
  Timer? timer;
  TripService? service;

  GoogleMapController? mapController;

  BitmapDescriptor? busIcon;
  LatLng? previousPosition;

  bool _isLoading = true;
  String? _errorMessage;

  bool simulationMode = false;

  static const LatLng defaultLocation = LatLng(-22.4705, -44.4500);
  late LatLng currentLocation;

  final WebSocketService _webSocket = WebSocketService();
  bool _useWebSocket = true;
  bool _webSocketInitialized = false;

  @override
  void initState() {
    super.initState();
    currentLocation = defaultLocation;
    loadBusIcon();
    initialize();
  }

  Future<void> handleLogout() async {
    timer?.cancel();

    if (_webSocketInitialized) {
      _webSocket.stopListeningToTrip(widget.tripId);
      _webSocket.disconnect();
    }

    final auth = AuthService();
    await auth.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> loadBusIcon() async {
    try {
      final ByteData data = await rootBundle.load(
        "assets/icons/busicon_green.png",
      );

      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 48,
      );

      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (bytes != null) {
        busIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint("Erro ao carregar ícone do ônibus: $e");
      busIcon = BitmapDescriptor.defaultMarker;
    }

    if (mounted) setState(() {});
  }

  Future<void> initialize() async {
    try {
      final auth = AuthService();
      final token = await auth.getToken();

      if (token == null) {
        setState(() {
          _errorMessage = "Usuário não autenticado";
          _isLoading = false;
        });
        return;
      }

      final api = ApiClient(token);
      service = TripService(api.dio);

      if (_useWebSocket) {
        try {
          await _webSocket.initialize();
          _webSocketInitialized = true;
          _listenToWebSocket();
        } catch (_) {
          _useWebSocket = false;
          startPolling();
        }
      }

      await _fetchInitialLocation();

      if (!_useWebSocket || !_webSocketInitialized) {
        startPolling();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao inicializar: $e";
        _isLoading = false;
      });
    }
  }

  void _listenToWebSocket() {
    _webSocket.listenToTripLocation(widget.tripId, (event) {
      if (!mounted) return;

      if (event == null) {
        setState(() {
          _useWebSocket = false;
        });
        startPolling();
        return;
      }

      try {
        final locationData = event['location'];

        if (locationData != null) {
          final lat = double.parse(locationData['lat'].toString());
          final lng = double.parse(locationData['lng'].toString());

          updateBusPosition(LatLng(lat, lng));
        }
      } catch (e) {
        debugPrint('Erro ao processar WebSocket: $e');
      }
    });
  }

  Future<void> _fetchInitialLocation() async {
    try {
      final data = await service!.getLatestLocation(widget.tripId);

      if (data["lat"] != null && data["lng"] != null) {
        final lat = double.parse(data["lat"].toString());
        final lng = double.parse(data["lng"].toString());

        currentLocation = LatLng(lat, lng);
        updateBusPosition(currentLocation);
      }
    } catch (e) {
      debugPrint("Erro ao buscar localização inicial: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void startPolling() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (service == null || !mounted) return;

      try {
        final data = await service!.getLatestLocation(widget.tripId);

        if (data["lat"] != null && data["lng"] != null) {
          final lat = double.parse(data["lat"].toString());
          final lng = double.parse(data["lng"].toString());

          updateBusPosition(LatLng(lat, lng));
        }
      } catch (_) {}
    });
  }

  void updateBusPosition(LatLng newPosition) {
    if (!mounted) return;

    setState(() {
      markers = {
        Marker(
          markerId: const MarkerId("bus"),
          position: newPosition,
          icon: busIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: "Ônibus Escolar"),
        ),
      };
    });

    previousPosition = newPosition;

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPosition, zoom: 16),
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();

    if (_webSocketInitialized) {
      _webSocket.stopListeningToTrip(widget.tripId);
      _webSocket.disconnect();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Mapa"),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Mapa"),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
          ],
        ),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Acompanhamento"),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (markers.isNotEmpty && mapController != null) {
                final marker = markers.first;

                mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: marker.position, zoom: 16),
                  ),
                );
              }
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: handleLogout),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentLocation,
          zoom: 14,
        ),
        markers: markers,
        onMapCreated: (controller) {
          mapController = controller;
        },
        myLocationEnabled: true,
        compassEnabled: true,
      ),
    );
  }
}
