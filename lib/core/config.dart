// lib/core/config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Config {
  // Google Maps API Key
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY não configurada no .env');
    }
    return key;
  }

  // API Base URL
  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('API_BASE_URL não configurada no .env');
    }
    return url;
  }

  // 🔥 NOVO: Configurações do Reverb (WebSocket)
  static String get reverbAppKey {
    final key = dotenv.env['REVERB_APP_KEY'];
    if (key == null || key.isEmpty) {
      // Em desenvolvimento, pode retornar um valor padrão
      // Mas é melhor lançar exceção para garantir que foi configurado
      debugPrint(
        '⚠️ REVERB_APP_KEY não configurada, usando valor padrão para desenvolvimento',
      );
      return 'suachaveaqui123456'; // Valor padrão apenas para desenvolvimento
    }
    return key;
  }

  static String get reverbHost {
    final host = dotenv.env['REVERB_HOST'];
    if (host == null || host.isEmpty) {
      debugPrint('⚠️ REVERB_HOST não configurada, usando localhost');
      return 'localhost'; // Ou '192.168.0.100' se preferir
    }
    return host;
  }

  static int get reverbPort {
    final port = dotenv.env['REVERB_PORT'];
    if (port == null || port.isEmpty) {
      debugPrint('⚠️ REVERB_PORT não configurada, usando porta 8080');
      return 8080;
    }
    return int.tryParse(port) ?? 8080;
  }

  static bool get reverbUseTLS {
    final scheme = dotenv.env['REVERB_SCHEME'] ?? 'http';
    return scheme == 'https';
  }

  // 🔥 NOVO: URL completa do WebSocket (opcional, para debug)
  static String get reverbWebSocketUrl {
    final scheme = reverbUseTLS ? 'wss' : 'ws';
    return '$scheme://$reverbHost:$reverbPort';
  }

  // 🔥 NOVO: Endpoint de autenticação do broadcasting
  static String get broadcastingAuthEndpoint {
    return '$apiBaseUrl/broadcasting/auth';
  }
}
