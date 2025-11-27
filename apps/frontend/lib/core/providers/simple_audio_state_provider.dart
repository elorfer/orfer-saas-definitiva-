import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/professional_audio_service.dart';
import '../utils/logger.dart';

/// Estado simple para el mini reproductor que lee directamente del ProfessionalAudioService
class SimpleAudioState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isBuffering;

  const SimpleAudioState({
    this.currentSong,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isBuffering = false,
  });

  SimpleAudioState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isBuffering,
  }) {
    return SimpleAudioState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isBuffering: isBuffering ?? this.isBuffering,
    );
  }

  /// Calcular progreso de 0.0 a 1.0
  double get progress {
    // 🔍 DEBUG: Verificar valores antes del cálculo
    if (totalDuration.inMilliseconds <= 0) {
      // Si no hay duración total, el progreso es 0
      return 0.0;
    }
    
    // Calcular progreso y asegurar que esté en el rango correcto
    final calculatedProgress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    
    // 🔍 DEBUG: Log para identificar valores problemáticos
    if (calculatedProgress > 0.95) {
      AppLogger.warning('[SimpleAudioState] Progress alto detectado: ${(calculatedProgress * 100).toStringAsFixed(1)}%');
      AppLogger.warning('   Position: ${currentPosition.inSeconds}s (${currentPosition.inMilliseconds}ms)');
      AppLogger.warning('   Duration: ${totalDuration.inSeconds}s (${totalDuration.inMilliseconds}ms)');
    }
    
    return calculatedProgress;
  }
}

/// Provider que lee directamente del ProfessionalAudioService existente
final simpleAudioStateProvider = StreamProvider<SimpleAudioState>((ref) async* {
  final audioService = ProfessionalAudioService();
  
  // Asegurar que está inicializado
  if (!audioService.isInitialized) {
    try {
      await audioService.initialize(enableBackground: true);
    } catch (e) {
      AppLogger.error('[SimpleAudioStateProvider] Error inicializando: $e');
      yield const SimpleAudioState();
      return;
    }
  }
  
  final controller = audioService.controller;
  if (controller == null) {
    yield const SimpleAudioState();
    return;
  }
  
  final player = controller.player;
  
  // 🔧 Estado para evitar valores incorrectos al inicio
  SimpleAudioState? lastValidState;
  int stableReadings = 0;
  
  // Combinar todos los streams en uno solo
  await for (final _ in Stream.periodic(const Duration(milliseconds: 100))) {
    try {
      final currentSong = controller.currentSong;
      final position = player.position;
      final duration = player.duration ?? Duration.zero;
      final playerState = player.playerState;
      
      // 🔍 DEBUG: Verificar valores problemáticos
      if (duration.inMilliseconds > 0 && position.inMilliseconds > 0) {
        final progress = (position.inMilliseconds / duration.inMilliseconds);
        if (progress > 0.95) {
          AppLogger.warning('[SimpleAudioStateProvider] Progreso alto detectado:');
          AppLogger.warning('   Song: ${currentSong?.title ?? 'null'}');
          AppLogger.warning('   Position: ${position.inSeconds}s');
          AppLogger.warning('   Duration: ${duration.inSeconds}s');
          AppLogger.warning('   Progress: ${(progress * 100).toStringAsFixed(1)}%');
          AppLogger.warning('   PlayerState: ${playerState.processingState}');
        }
      }
      
      // Validar que los valores sean coherentes
      Duration validPosition = position;
      Duration validDuration = duration;
      
      // Si la posición es mayor que la duración, ajustar
      if (duration.inMilliseconds > 0 && position.inMilliseconds > duration.inMilliseconds) {
        AppLogger.warning('[SimpleAudioStateProvider] Position > Duration, ajustando...');
        validPosition = duration;
      }
      
      // Si la duración es muy pequeña pero hay posición, puede ser un error
      if (duration.inMilliseconds < 1000 && position.inMilliseconds > 1000) {
        AppLogger.warning('[SimpleAudioStateProvider] Duration sospechosa, usando position como referencia');
        validDuration = position;
      }
      
      final state = SimpleAudioState(
        currentSong: currentSong,
        isPlaying: playerState.playing,
        currentPosition: validPosition,
        totalDuration: validDuration,
        isBuffering: playerState.processingState == ProcessingState.loading ||
                    playerState.processingState == ProcessingState.buffering,
      );
      
      // 🔧 FILTRO DE ESTABILIDAD: Evitar valores erróneos al inicio
      final progress = state.progress;
      
      // Si es la primera lectura o el progreso es muy alto sin razón, validar
      if (lastValidState == null) {
        // Primera lectura: aceptar solo si parece razonable
        if (progress < 0.9 || (validPosition.inSeconds > 10 && validDuration.inSeconds > 10)) {
          lastValidState = state;
          stableReadings = 1;
          yield state;
        } else {
          // Primera lectura sospechosa, usar estado vacío
          yield const SimpleAudioState();
        }
      } else {
        // Lecturas subsecuentes: verificar consistencia
        final progressDiff = (progress - lastValidState.progress).abs();
        
        // Si el cambio de progreso es muy grande (>50%) en 100ms, es sospechoso
        if (progressDiff > 0.5 && stableReadings < 10) {
          AppLogger.warning('[SimpleAudioStateProvider] Cambio de progreso sospechoso: ${(progressDiff * 100).toStringAsFixed(1)}%');
          // Mantener el estado anterior
          yield lastValidState;
        } else {
          // Estado parece válido
          lastValidState = state;
          stableReadings++;
          yield state;
        }
      }
      
    } catch (e) {
      AppLogger.error('[SimpleAudioStateProvider] Error en stream: $e');
      // Si hay error, mantener el estado anterior o devolver estado vacío
      yield const SimpleAudioState();
    }
  }
});

/// Provider de conveniencia para obtener solo la canción actual
final currentSongSimpleProvider = Provider<Song?>((ref) {
  final audioState = ref.watch(simpleAudioStateProvider);
  return audioState.when(
    data: (state) => state.currentSong,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider de conveniencia para obtener el progreso
final audioProgressSimpleProvider = Provider<double>((ref) {
  final audioState = ref.watch(simpleAudioStateProvider);
  return audioState.when(
    data: (state) => state.progress,
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider de conveniencia para obtener si está reproduciendo
final isPlayingSimpleProvider = Provider<bool>((ref) {
  final audioState = ref.watch(simpleAudioStateProvider);
  return audioState.when(
    data: (state) => state.isPlaying,
    loading: () => false,
    error: (_, __) => false,
  );
});
