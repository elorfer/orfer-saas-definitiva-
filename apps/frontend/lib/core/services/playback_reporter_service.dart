import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';
import '../models/song_model.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';
// Asumiendo Dio para HTTP
import 'http_client_service.dart';

/// Servicio que monitorea la reproducción y reporta "plays" y "skips" al backend.
/// 
/// Reglas:
/// 1. Play válido: > 30 segundos de reproducción acumulada.
/// 2. Skip: Salto antes de 30 segundos (Penalización ampliada).
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
      
      // 🔄 DETECCIÓN DE REPLAY / REWIND: Si la posición cae drásticamente (e.g. 30s -> 0s)
      // Significa que el usuario reinició la canción o hizo seek al inicio.
      // Debemos resetear el acumulado para evitar enviar "32s" como progreso inicial de la nueva sesión.
      if (_lastPosition.inSeconds > 10 && position.inSeconds < 2) {
        final drop = _lastPosition - position;
        if (drop.inSeconds > 10) { // Confirmar caída grande
           AppLogger.info('[PlaybackReporter] 🔄 Replay detectado (Reset de métricas). Drop: ${drop.inSeconds}s');
           _accumulatedDuration = Duration.zero; // Reset acumulado
           _playRegistered = false; // Permitir registrar un nuevo 'play'
           _lastReportTime = null;
        }
      }
      
      final delta = position - _lastPosition;
      // Solo acumular si avanza (delta positivo) y no es un salto enorme (>2s)
      if (delta > Duration.zero && delta < const Duration(seconds: 2)) {
          _accumulatedDuration += delta;
      }
      _lastPosition = position;
  }

  // Flag para prevenir condiciones de carrera en reportes
  bool _isReporting = false;

  Future<void> _reportProgress({String? overrideSongId, Duration? overrideDuration}) async {
      final targetSongId = overrideSongId ?? _currentSongId;
      final targetDuration = overrideDuration ?? _accumulatedDuration;

      // Guardias de seguridad
      if (targetSongId == null || targetDuration.inSeconds < 5) return;
      if (_isReporting) return; // 🔒 Evitar llamadas concurrentes
      // ELIMINADO: if (_playRegistered && overrideSongId == null) return; 
      // ✅ FIX: Permitir reportes continuos (Heartbeat) para mantener viva la sesión en el backend

      try {
          final authState = _ref.read(authStateProvider);
          if (!authState.isAuthenticated) return;
          
          if (targetDuration.inSeconds >= 30) {
              _isReporting = true; // 🔒 Bloquear
              
              final isFirstValidation = !_playRegistered;
              if (isFirstValidation) {
                 AppLogger.info('[PlaybackReporter] ⏳ 30s alcanzados. Enviando validación de Stream...');
              } else if (overrideSongId == null) {
                 // Solo loguear heartbeat si no es un override (transición)
                 AppLogger.debug('[PlaybackReporter] 💓 Heartbeat: Actualizando progreso (${targetDuration.inSeconds}s)');
              }
              
              final httpClient = HttpClientService();
              final response = await httpClient.post(
                '/streams/track-progress', 
                data: {
                  'songId': targetSongId,
                  'progressMs': targetDuration.inMilliseconds,
                  'durationMs': targetDuration.inMilliseconds, // TODO: Enviar duración total real si es posible
                  'volume': 1.0, 
                  'isForeground': true 
                }
              );
              
              if (response.statusCode == 200 || response.statusCode == 201) {
                  final responseData = response.data as Map<String, dynamic>?;
                  final streamRegistered = responseData?['streamRegistered'] as bool? ?? false;
                  final message = responseData?['message'] as String? ?? '';
                  
                  if (streamRegistered) {
                    if (overrideSongId == null) {
                      _playRegistered = true; // Solo marcar actual como registrado si no es override
                    }
                    if (isFirstValidation) {
                      AppLogger.success('[PlaybackReporter] ✅ Stream REGISTRADO Y CONTABILIZADO: $targetSongId');
                    }
                  } else {
                    // El backend respondió OK pero NO registró el stream (ya validado o rate-limit)
                    if (isFirstValidation) {
                      AppLogger.warning('[PlaybackReporter] ⚠️ Stream NO contabilizado: $message');
                    }
                    // Aún así marcamos como registered para evitar spam de requests
                    if (overrideSongId == null) {
                      _playRegistered = true;
                    }
                  }
              } else {
                  AppLogger.warning('[PlaybackReporter] ⚠️ Fallo al reportar stream. Status: ${response.statusCode}');
              }
          }
      } catch (e) {
          AppLogger.error('[PlaybackReporter] Error reportando progreso: $e');
      } finally {
          _isReporting = false; // 🔓 Desbloquear
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

  // Timestamp del último comando explícito de "Next"
  DateTime? _lastManualSkipSignal;

  /// Registra que el usuario presionó explícitamente "Siguiente".
  /// Permite distinguir entre skips reales y glitches de reproducción o inserción de anuncios.
  void reportManualSkip() {
    _lastManualSkipSignal = DateTime.now();
    AppLogger.debug('[PlaybackReporter] ⏭️ Señal manual de Skip recibida');
  }

  void _handleSongChange(String newSongId) {
    final previousSongId = _currentSongId;
    final secondsPlayed = _accumulatedDuration.inSeconds;
    final accumulatedSnapshot = _accumulatedDuration; // 📸 Snapshot para el reporte

    // ✅ FIX CRÍTICO: Reset del estado ANTES de cualquier return
    // Esto previene corrupción de estado si hay returns tempranos
    final shouldResetState = previousSongId != null && previousSongId.isNotEmpty;
    
    if (shouldResetState) {
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
          // Lógica INTELIGENTE de Skips
          // Un "Skip Rápido" (< 5s) es muy penalizante.
          // Pero si ocurre por error del sistema (0s), no debemos penalizar.
          // Requerimos que haya habido una señal manual reciente O que la duración sea moderada (>3s)
          
          final isManualSkip = _lastManualSkipSignal != null && 
                               DateTime.now().difference(_lastManualSkipSignal!) < const Duration(seconds: 2);
          
          if (secondsPlayed < 30) {
            // 🛡️ NO REPORTAR SKIP si ya se registró como Play (seguridad contra race conditions)
            if (_playRegistered) {
               AppLogger.warning('[PlaybackReporter] 🛡️ Skip ignorado: Ya se había registrado como Play (Race condition prevenida)');
               // ✅ NO hacer return aquí, continuar con el reset de estado
            } else if (secondsPlayed < 3 && !isManualSkip) {
              // 🛡️ GLITCH GUARD: Si duró menos de 3s y NO fue manual, asumir glitch/auto-skip
              AppLogger.warning('[PlaybackReporter] 🛡️ Ignorando posible glitch/auto-skip: $previousSongId (${secondsPlayed}s) - Sin señal manual');
            } else {
              // Es un skip manual real O duró entre 3-30s (usuario decidió saltar)
              // AHORA: Todo salto antes de los 30s es penalizado. Sin "Zona Neutra".
              _reportSkip(previousSongId, secondsPlayed);
            }
          } else {
            // Si duró 30s o más, es un STREAM VÁLIDO.
            // Si no se registró el play por heartbeat, forzar reporte con snapshot ahora.
            if (!_playRegistered) {
              // 🚀 Usar snapshot explícito para evitar condiciones de carrera
              _reportProgress(overrideSongId: previousSongId, overrideDuration: accumulatedSnapshot);
            }
          }
      }
    }

    // ✅ SIEMPRE resetear el estado para la nueva canción (movido aquí para garantizar ejecución)
    _currentSongId = newSongId;
    _accumulatedDuration = Duration.zero;
    _lastPosition = Duration.zero;
    _playRegistered = false;
    _isReporting = false; // Reset flag por seguridad
    _lastReportTime = null;
    // No reseteamos _lastManualSkipSignal aquí, su expiración se maneja por tiempo (diff)
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
