import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import 'trip_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../../core/config.dart';
import '../../core/websocket_service.dart';

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

  BitmapDescriptor? busIcon;
  LatLng? previousPosition;

  // Controlar estado de carregamento e erros
  bool _isLoading = true;
  String? _errorMessage;

  // Verificar se a API Key está configurada
  bool get _isApiKeyConfigured {
    try {
      Config.googleMapsApiKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  bool simulationMode = false;

  // Centralizar coordenadas iniciais em constante
  static const LatLng defaultLocation = LatLng(-22.4705, -44.4500);
  late LatLng currentLocation;

  // 🔥 CORREÇÃO 1: WebSocket service
  final WebSocketService _webSocket = WebSocketService();
  bool _useWebSocket = true;
  bool _webSocketInitialized = false; // Controle de inicialização

  @override
  void initState() {
    super.initState();
    currentLocation = defaultLocation;
    loadBusIcon();
    initialize();
  }

  Future<void> loadBusIcon() async {
    try {
      final ByteData data = await rootBundle.load(
        "assets/icons/bus_green_circle.png",
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
    // Verificar configuração da API Key
    if (!_isApiKeyConfigured && !simulationMode) {
      setState(() {
        _errorMessage = "Erro de configuração do mapa. Contate o suporte.";
        _isLoading = false;
      });
      return;
    }

    if (simulationMode) {
      startSimulation();
      if (mounted) setState(() => _isLoading = false);
    } else {
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

        // 🔥 CORREÇÃO 2: Inicializar WebSocket apenas se for usar
        if (_useWebSocket) {
          try {
            await _webSocket.initialize();
            _webSocketInitialized = true;
            _listenToWebSocket();
          } catch (e) {
            debugPrint('Erro ao inicializar WebSocket: $e');
            _useWebSocket = false; // Fallback para polling
            startPolling();
          }
        }

        // Buscar localização inicial
        await _fetchInitialLocation();

        // Usa polling se WebSocket não estiver disponível
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
  }

  // Escutar WebSocket
  void _listenToWebSocket() {
    _webSocket.listenToTripLocation(widget.tripId, (event) {
      if (!mounted) return;

      // Se event for null, WebSocket falhou - ativar polling
      if (event == null) {
        debugPrint('⚠️ WebSocket falhou, ativando polling');
        setState(() {
          _useWebSocket = false;
        });
        startPolling();
        return;
      }
      debugPrint('📍 Atualização via WebSocket: $event');

      try {
        // 🔥 CORREÇÃO 3: Acessar dados corretamente
        final locationData = event['location'];
        if (locationData != null) {
          final lat = locationData['lat'] is double
              ? locationData['lat']
              : double.parse(locationData['lat'].toString());
          final lng = locationData['lng'] is double
              ? locationData['lng']
              : double.parse(locationData['lng'].toString());

          updateBusPosition(LatLng(lat, lng));
        }
      } catch (e) {
        debugPrint('Erro ao processar WebSocket: $e');
      }
    });
  }

  @override
  void dispose() {
    // Desconectar WebSocket
    if (_webSocketInitialized) {
      _webSocket.stopListeningToTrip(widget.tripId);
      _webSocket.disconnect();
    }

    timer?.cancel();
    super.dispose();
  }

  // Buscar localização inicial
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

  void startSimulation() {
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;

      currentLocation = LatLng(
        currentLocation.latitude + 0.0003,
        currentLocation.longitude + 0.0002,
      );

      updateBusPosition(currentLocation);
    });
  }

  void startPolling() {
    timer?.cancel(); // Cancelar timer anterior se existir
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (service == null || !mounted) return;

      try {
        final data = await service!.getLatestLocation(widget.tripId);

        if (data["lat"] != null && data["lng"] != null) {
          final lat = double.parse(data["lat"].toString());
          final lng = double.parse(data["lng"].toString());

          updateBusPosition(LatLng(lat, lng));
        }
      } catch (e) {
        debugPrint("Erro ao buscar localização: $e");
      }
    });
  }

  void updateBusPosition(LatLng newPosition) {
    if (!mounted) return;

    // Se não tiver posição anterior, apenas atualiza o marcador
    if (previousPosition == null) {
      previousPosition = newPosition;

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

      _animateCamera(newPosition);
      return;
    }

    // Calcular distância para decidir se anima ou não
    final distance = _calculateDistance(
      previousPosition!.latitude,
      previousPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    // Se a distância for muito grande, pula a animação
    if (distance > 0.01) {
      // Aprox 1km
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
      _animateCamera(newPosition);
      return;
    }

    // Animação suave para distâncias curtas
    const int steps = 20;
    double latStep =
        (newPosition.latitude - previousPosition!.latitude) / steps;
    double lngStep =
        (newPosition.longitude - previousPosition!.longitude) / steps;
    int currentStep = 0;

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep++;
      double lat = previousPosition!.latitude + latStep * currentStep;
      double lng = previousPosition!.longitude + lngStep * currentStep;

      setState(() {
        markers = {
          Marker(
            markerId: const MarkerId("bus"),
            position: LatLng(lat, lng),
            icon: busIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: const InfoWindow(title: "Ônibus Escolar"),
          ),
        };
      });

      if (currentStep >= steps) {
        timer.cancel();
        previousPosition = newPosition;
      }
    });

    _animateCamera(newPosition);
  }

  // Centralizar animação da câmera
  void _animateCamera(LatLng target) {
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
  }

  // Calcular distância entre coordenadas
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return ((lat1 - lat2).abs() + (lon1 - lon2).abs()) / 2;
  }

  // Botão para centralizar no ônibus
  void _centerOnBus() {
    if (markers.isNotEmpty) {
      final busMarker = markers.first;
      _animateCamera(busMarker.position);
    }
  }

  // 🔥 CORREÇÃO 4: Botão para alternar modo de conexão
  void _toggleConnectionMode() {
    setState(() {
      _useWebSocket = !_useWebSocket;
      _isLoading = true; // Mostra loading enquanto reconecta
    });

    // Cancelar timers atuais
    timer?.cancel();

    if (_webSocketInitialized) {
      _webSocket.stopListeningToTrip(widget.tripId);
      _webSocket.disconnect();
      _webSocketInitialized = false;
    }

    // Reiniciar com novo modo
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    // Tela de carregamento
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Mapa"),
          actions: [
            IconButton(
              icon: Icon(_useWebSocket ? Icons.wifi : Icons.sync),
              onPressed: _toggleConnectionMode,
              tooltip: _useWebSocket ? 'Usando WebSocket' : 'Usando Polling',
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Tela de erro
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Mapa")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  initialize();
                },
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(simulationMode ? "Mapa (SIMULAÇÃO)" : "Acompanhamento"),
        actions: [
          // Botão para alternar entre WebSocket e Polling
          IconButton(
            icon: Icon(_useWebSocket ? Icons.wifi : Icons.sync),
            onPressed: _toggleConnectionMode,
            tooltip: _useWebSocket ? 'Usando WebSocket' : 'Usando Polling',
          ),
          // Botão para centralizar
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnBus,
            tooltip: "Centralizar no ônibus",
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentLocation,
                zoom: 14,
              ),
              markers: markers,
              onMapCreated: (controller) {
                mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
          // Indicador de atualização
          if ((timer?.isActive ?? false) || _webSocketInitialized)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _webSocketInitialized ? "WebSocket" : "Polling",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
