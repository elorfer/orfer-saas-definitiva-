import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart'; // Asumiendo Dio para HTTP
import 'http_client_service.dart';

/// Servicio que monitorea la reproducción y reporta "plays" y "skips" al backend.
/// 
/// Reglas:
/// 1. Play válido: > 30 segundos de reproducción acumulada.
/// 2. Skip: Salto antes de 5 segundos.
/// 3. Reporta al endpoint /streams/track-progress y /streams/skip.
class PlaybackReporterService {
  final Ref _ref;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _sequenceStateSubscription;
  
  // Estado de tracking actual
  String? _currentSongId;
  Duration _accumulatedDuration = Duration.zero;
  Duration _lastPosition = Duration.zero;
  bool _playRegistered = false;
  DateTime? _lastReportTime;
  
  // Timer para reporte periódico (heartbeat)
  Timer? _heartbeatTimer;
  
  // Flag para ignorar skips (usado en transiciones de anuncios)
  DateTime? _ignoreSkipsUntil;

  PlaybackReporterService(this._ref);
  
  /// Indica al reporter que ignore eventos de "cambio de canción" durante un breve periodo.
  /// Útil para transiciones automáticas pos-anuncio donde pueden ocurrir saltos rápidos (ej. errores de carga).
  void ignoreNextSkip() {
      // Dar una ventana de gracia de 3 segundos
      _ignoreSkipsUntil = DateTime.now().add(const Duration(seconds: 3));
      AppLogger.info('[PlaybackReporter] 🛡️ Activando escudo de penalización por 3 segundos');
  }

  void initialize() {
    final audioService = _ref.read(audioServiceProvider);
    
    // Escuchar cambios de posición para acumular tiempo
    _positionSubscription = audioService.positionStream.listen((position) {
      _handlePositionUpdate(position);
    });

    // Escuchar cambios de canción para detectar Skips y resetear estado
    _sequenceStateSubscription = audioService.sequenceStateStream.listen((state) {
        if (state?.currentSource?.tag is Song) {
             final song = state!.currentSource!.tag as Song;
             if (song.id != _currentSongId) {
                 _handleSongChange(song.id);
             }
        }
    });
    
    // Iniciar heartbeat
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportProgress());
    
    AppLogger.info('[PlaybackReporter] 🕵️ Servicio de reportes iniciado');
  }

  void _handlePositionUpdate(Duration position) {
      if (_currentSongId == null) return;
      
      final delta = position - _lastPosition;
      if (delta > Duration.zero && delta < const Duration(seconds: 2)) {
          _accumulatedDuration += delta;
      }
      _lastPosition = position;
  }

  Future<void> _reportProgress() async {
      if (_currentSongId == null || _accumulatedDuration.inSeconds < 5) return;
      
      try {
          final authState = _ref.read(authStateProvider);
          if (!authState.isAuthenticated) return;
          
          if (_accumulatedDuration.inSeconds >= 30 && !_playRegistered) {
              AppLogger.info('[PlaybackReporter] ⏳ 30s alcanzados. Enviando validación de Stream...');
              
              final httpClient = HttpClientService();
              final response = await httpClient.post(
                '/streams/track-progress', 
                data: {
                  'songId': _currentSongId,
                  'progressMs': _accumulatedDuration.inMilliseconds,
                  'durationMs': _accumulatedDuration.inMilliseconds,
                  'volume': 1.0, 
                  'isForeground': true 
                }
              );
              
              if (response.statusCode == 200 || response.statusCode == 201) {
                  _playRegistered = true; 
                  AppLogger.info('[PlaybackReporter] ✅ Stream reportado exitosamente');
              } else {
                  AppLogger.warning('[PlaybackReporter] ⚠️ Fallo al reportar stream. Status: ${response.statusCode}');
              }
          }
      } catch (e) {
          AppLogger.error('[PlaybackReporter] Error reportando progreso: $e');
      }
  }

  Future<void> _reportSkip(String songId, int secondsPlayed) async {
       try {
         AppLogger.info('[PlaybackReporter] ⏭️ Skip detectado (<5s). Reportando penalización...');
         final httpClient = HttpClientService();
         await httpClient.post(
            '/streams/skip', 
            data: { 
              'songId': songId, 
              'secondsPlayed': secondsPlayed 
            }
         );
       } catch (e) {
         AppLogger.error('[PlaybackReporter] Error reportando skip: $e');
       }
  }

  void _handleSongChange(String newSongId) {
    final previousSongId = _currentSongId;
    final secondsPlayed = _accumulatedDuration.inSeconds;

    if (previousSongId != null && previousSongId.isNotEmpty) {
      // 🛡️ PROTECCIÓN: Verificar si estamos en periodo de gracia
      bool isProtected = false;
      if (_ignoreSkipsUntil != null) {
          if (DateTime.now().isBefore(_ignoreSkipsUntil!)) {
             isProtected = true;
             AppLogger.info('[PlaybackReporter] 🛡️ Skip protegido/ignorado por escudo temporal ($previousSongId)');
          } else {
             _ignoreSkipsUntil = null; // Expiró
          }
      }

      if (!isProtected) {
          // Lógica normal
          // Si la canción anterior tuvo menos de 5s reproducidos, considerar skip
          if (secondsPlayed < 5) {
            _reportSkip(previousSongId, secondsPlayed);
          } else {
            // Si no se registró el play pero se alcanzaron 30s, forzar reporte
            if (_accumulatedDuration.inSeconds >= 30 && !_playRegistered) {
              _reportProgress();
              _playRegistered = true;
            }
          }
      }
    }

    // Reset del estado para la nueva canción
    _currentSongId = newSongId;
    _accumulatedDuration = Duration.zero;
    _lastPosition = Duration.zero;
    _playRegistered = false;
    _lastReportTime = null;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _sequenceStateSubscription?.cancel();
    _heartbeatTimer?.cancel();
    AppLogger.info('[PlaybackReporter] Servicio detenido y recursos liberados');
  }
}

// Provider global
final playbackReporterProvider = Provider<PlaybackReporterService>((ref) {
  final reporter = PlaybackReporterService(ref);
  reporter.initialize(); // 🚀 Auto-start
  ref.onDispose(() => reporter.dispose());
  return reporter;
});
