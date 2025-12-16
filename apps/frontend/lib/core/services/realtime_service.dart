import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import 'http_client_service.dart';

/// Servicio para conexión WebSocket en tiempo real
/// Maneja notificaciones de cambios de estado premium y otras actualizaciones
class RealtimeService {
  static RealtimeService? _instance;
  IO.Socket? _socket;
  bool _isConnecting = false;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  StreamController<Map<String, dynamic>>? _premiumStatusController;
  final HttpClientService _httpClient = HttpClientService();

  // Stream para escuchar cambios de estado premium
  Stream<Map<String, dynamic>> get premiumStatusStream {
    _premiumStatusController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _premiumStatusController!.stream;
  }

  RealtimeService._();

  static RealtimeService get instance {
    _instance ??= RealtimeService._();
    return _instance!;
  }

  /// Obtener la URL del servidor WebSocket desde la URL base de la API
  String _getWebSocketUrl() {
    // Extraer la URL base sin /api/v1
    final apiUrl = AppConfig.baseUrl;
    final uri = Uri.parse(apiUrl);
    
    // Construir URL del WebSocket (Socket.io usa el mismo host/puerto)
    // El namespace /realtime se agregará en la conexión
    final wsUrl = '${uri.scheme}://${uri.host}:${uri.port}';
    
    if (kDebugMode) {
      debugPrint('🔌 WebSocket URL base: $wsUrl');
    }
    
    return wsUrl;
  }

  /// Conectar al servidor WebSocket
  Future<void> connect() async {
    if (_isConnecting || _isConnected) {
      if (kDebugMode) {
        debugPrint('🔌 WebSocket ya está conectando/conectado');
      }
      return;
    }

    try {
      _isConnecting = true;

      // Obtener token JWT del almacenamiento seguro
      final token = await _httpClient.getAuthToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No hay token disponible para WebSocket');
        }
        _isConnecting = false;
        return;
      }

      final wsUrl = _getWebSocketUrl();
      final fullUrl = '$wsUrl/realtime';

      if (kDebugMode) {
        debugPrint('🔌 Conectando a WebSocket: $fullUrl');
      }

      // Crear conexión Socket.io
      // Nota: El namespace '/realtime' se especifica en la URL
      _socket = IO.io(
        fullUrl, // URL completa con namespace
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .setQuery({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setTimeout(20000)
            .build(),
      );

      // Eventos de conexión
      _socket!.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        _cancelReconnectTimer();
        
        if (kDebugMode) {
          debugPrint('✅ WebSocket conectado exitosamente');
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _isConnecting = false;
        
        if (kDebugMode) {
          debugPrint('❌ WebSocket desconectado');
        }
        
        // Intentar reconectar después de un delay
        _scheduleReconnect();
      });

      _socket!.onConnectError((error) {
        _isConnecting = false;
        
        if (kDebugMode) {
          debugPrint('❌ Error de conexión WebSocket: $error');
        }
        
        // Intentar reconectar después de un delay
        _scheduleReconnect();
      });

      // Escuchar evento de cambio de estado premium
      _socket!.on('premiumStatusChanged', (data) {
        if (kDebugMode) {
          debugPrint('🎉 Evento premiumStatusChanged recibido en socket: $data');
          debugPrint('   - Tipo de dato: ${data.runtimeType}');
        }
        
        try {
          Map<String, dynamic> eventData;
          
          if (data is Map<String, dynamic>) {
            eventData = data;
          } else if (data is Map) {
            // Convertir Map dinámico a Map<String, dynamic>
            eventData = Map<String, dynamic>.from(data);
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ Formato de dato no reconocido: ${data.runtimeType}');
            }
            return;
          }
          
          if (kDebugMode) {
            debugPrint('✅ Agregando evento al stream: $eventData');
          }
          
          _premiumStatusController?.add(eventData);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Error procesando evento premium: $e');
          }
        }
      });

      // Conectar
      _socket!.connect();
    } catch (e) {
      _isConnecting = false;
      if (kDebugMode) {
        debugPrint('❌ Error al conectar WebSocket: $e');
      }
      _scheduleReconnect();
    }
  }

  /// Desconectar del servidor WebSocket
  void disconnect() {
    _cancelReconnectTimer();
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    _isConnected = false;
    _isConnecting = false;
    
    if (kDebugMode) {
      debugPrint('🔌 WebSocket desconectado manualmente');
    }
  }

  /// Programar reconexión automática
  void _scheduleReconnect() {
    if (_reconnectTimer != null || _isConnecting) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_isConnecting) {
        if (kDebugMode) {
          debugPrint('🔄 Intentando reconectar WebSocket...');
        }
        connect();
      }
    });
  }

  /// Cancelar timer de reconexión
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Verificar si está conectado
  bool get isConnected => _isConnected;

  /// Reconectar manualmente (útil después de actualizar token)
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }

  /// Limpiar recursos
  void dispose() {
    disconnect();
    _premiumStatusController?.close();
    _premiumStatusController = null;
    _cancelReconnectTimer();
  }
}

