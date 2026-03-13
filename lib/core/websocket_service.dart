// lib/core/websocket_service.dart

import 'dart:async';
import 'package:laravel_echo/laravel_echo.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Echo? _echo;
  bool _isConnected = false;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  final Map<String, List<Function(dynamic)>> _listeners = {};

  Future<void> initialize() async {
    if (_isConnected) return;

    final auth = AuthService();
    final token = await auth.getToken();

    if (token == null) {
      debugPrint("❌ Token não encontrado para WebSocket");
      return;
    }

    final host = Config.reverbHost;
    final port = Config.reverbPort;
    final scheme = Config.reverbUseTLS ? "wss" : "ws";

    final url =
        "$scheme://$host:$port/app/${Config.reverbAppKey}?protocol=7&client=flutter&version=1.0";

    debugPrint("🔌 Conectando WebSocket em $url");

    try {
      final socket = IOWebSocketChannel.connect(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: socket);

      _isConnected = true;

      debugPrint("✅ WebSocket conectado");
    } catch (e) {
      debugPrint("❌ Falha WebSocket: $e");
      _handleConnectionError();
    }
  }

  void listenToTripLocation(int tripId, Function(dynamic) callback) {
    if (_echo == null) {
      debugPrint("⚠️ WebSocket não inicializado");
      callback(null);
      return;
    }

    final channelName = "trip.$tripId";

    try {
      final channel = _echo!.channel(channelName);

      channel.listen(".location.updated", (event) {
        if (event == null) return;

        debugPrint("📍 Evento recebido $event");

        callback(event);
      });

      final key = "trip_$tripId";

      _listeners.putIfAbsent(key, () => []);

      if (!_listeners[key]!.contains(callback)) {
        _listeners[key]!.add(callback);
      }
    } catch (e) {
      debugPrint("❌ Erro ao escutar canal: $e");
    }
  }

  void stopListeningToTrip(int tripId) {
    if (_echo == null) return;

    final channelName = "trip.$tripId";

    try {
      _echo!.leave(channelName);

      _listeners.remove("trip_$tripId");
    } catch (_) {}
  }

  void disconnect() {
    _reconnectTimer?.cancel();

    _echo = null;
    _isConnected = false;
    _listeners.clear();

    debugPrint("🔌 WebSocket desconectado");
  }

  void _handleConnectionError() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;

    debugPrint("🔄 Reconectando tentativa $_reconnectAttempts");

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts * 2), () {
      initialize();
    });
  }

  bool get isConnected => _isConnected;
}
