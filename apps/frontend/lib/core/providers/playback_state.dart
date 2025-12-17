import 'package:flutter/widgets.dart';
import '../models/song_model.dart';
import '../../features/ads/models/audio_ad_model.dart';

/// Modo de repetición del reproductor
enum RepeatMode {
  off,  // Sin repetición
  all,  // Repetir todas las canciones
  one,  // Repetir canción actual
}

/// Modo de reproducción del reproductor
enum PlaybackMode {
  algorithm,   // Modo algoritmo (recomendaciones)
  fixedQueue,  // Modo cola fija (playlist/artista)
  none,        // Sin modo activo
}

/// Estado del reproductor de audio - ÚNICA FUENTE DE VERDAD
@immutable
class PlaybackState {
  final PlaybackMode playbackMode;
  final List<Song> currentQueue; // La lista de canciones activa
  final Song? currentSong;
  final Song? lastConfirmedSong; // Canción confirmada según índice real (evita flashes)
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;
  final bool isReplacingQueue; // Flag de reemplazo de cola (congela UI de portada)
  final double volume;
  final bool isLoading;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final String? contextId; // ID del contexto actual (playlistId o artistId)
  final bool shouldStartAlgorithmAfterQueue; // Bandera para iniciar algoritmo al finalizar cola fija
  // Flags de control optimista
  final bool isProcessingPlayPause;
  final bool isProcessingNext;
  final bool isProcessingPrevious;
  // Estado de anuncios
  final AudioAd? currentAd;
  final bool isPlayingAd;

  const PlaybackState({
    this.playbackMode = PlaybackMode.none,
    this.currentQueue = const [],
    this.currentSong,
    this.lastConfirmedSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
    this.isReplacingQueue = false,
    this.volume = 0.85,
    this.isLoading = false,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.off,
    this.contextId,
    this.shouldStartAlgorithmAfterQueue = false,
    this.isProcessingPlayPause = false,
    this.isProcessingNext = false,
    this.isProcessingPrevious = false,
    this.currentAd,
    this.isPlayingAd = false,
  });

  /// Calcular progreso de 0.0 a 1.0
  double get progress {
    if (totalDuration.inMilliseconds <= 0) {
      return 0.0;
    }
    final calculatedProgress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    return calculatedProgress;
  }

  /// Verificar si hay una canción cargada
  bool get hasSong => currentSong != null;

  /// Verificar si se puede reproducir
  bool get canPlay => hasSong && !isLoading;

  PlaybackState copyWith({
    PlaybackMode? playbackMode,
    List<Song>? currentQueue,
    Song? currentSong,
    Song? lastConfirmedSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
    bool? isReplacingQueue,
    double? volume,
    bool? isLoading,
    bool? isShuffled,
    RepeatMode? repeatMode,
    String? contextId,
    bool? shouldStartAlgorithmAfterQueue,
    bool? isProcessingPlayPause,
    bool? isProcessingNext,
    bool? isProcessingPrevious,
    AudioAd? currentAd,
    bool? isPlayingAd,
    // ✅ FIX CRÍTICO: Flags para permitir establecer null explícitamente
    bool clearCurrentAd = false,
    bool clearCurrentSong = false,
    bool clearLastConfirmedSong = false,
  }) {
    return PlaybackState(
      playbackMode: playbackMode ?? this.playbackMode,
      currentQueue: currentQueue ?? this.currentQueue,
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      lastConfirmedSong: clearLastConfirmedSong ? null : (lastConfirmedSong ?? this.lastConfirmedSong),
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      isReplacingQueue: isReplacingQueue ?? this.isReplacingQueue,
      volume: volume ?? this.volume,
      isLoading: isLoading ?? this.isLoading,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      contextId: contextId ?? this.contextId,
      shouldStartAlgorithmAfterQueue: shouldStartAlgorithmAfterQueue ?? this.shouldStartAlgorithmAfterQueue,
      isProcessingPlayPause: isProcessingPlayPause ?? this.isProcessingPlayPause,
      isProcessingNext: isProcessingNext ?? this.isProcessingNext,
      isProcessingPrevious: isProcessingPrevious ?? this.isProcessingPrevious,
      // ✅ FIX CRÍTICO: Usar flag para permitir establecer null explícitamente
      currentAd: clearCurrentAd ? null : (currentAd ?? this.currentAd),
      isPlayingAd: isPlayingAd ?? this.isPlayingAd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaybackState &&
        other.playbackMode == playbackMode &&
        other.currentQueue.length == currentQueue.length &&
        other.currentSong?.id == currentSong?.id &&
        other.lastConfirmedSong?.id == lastConfirmedSong?.id &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isPlayerExpanded == isPlayerExpanded &&
        other.isReplacingQueue == isReplacingQueue &&
        other.volume == volume &&
        other.isLoading == isLoading &&
        other.isShuffled == isShuffled &&
        other.repeatMode == repeatMode &&
        other.contextId == contextId &&
        other.shouldStartAlgorithmAfterQueue == shouldStartAlgorithmAfterQueue &&
        other.isProcessingPlayPause == isProcessingPlayPause &&
        other.isProcessingNext == isProcessingNext &&
        other.isProcessingPrevious == isProcessingPrevious &&
        other.currentAd?.id == currentAd?.id &&
        other.isPlayingAd == isPlayingAd;
  }

  @override
  int get hashCode {
    // Combinar algunos valores para no exceder el límite de 20 argumentos de Object.hash
    return Object.hash(
      playbackMode,
      currentQueue.length,
      currentSong?.id,
      lastConfirmedSong?.id,
      isPlaying,
      isBuffering,
      currentPosition,
      totalDuration,
      isPlayerExpanded,
      isReplacingQueue,
      volume,
      isLoading,
      isShuffled,
      repeatMode,
      contextId,
      shouldStartAlgorithmAfterQueue,
      isProcessingPlayPause,
      isProcessingNext,
      isProcessingPrevious,
      Object.hash(currentAd?.id, isPlayingAd), // Combinar campos de anuncios
    );
  }

  @override
  String toString() {
    return 'PlaybackState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

