import 'package:flutter/widgets.dart';
import '../models/song_model.dart';

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
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlayerExpanded;
  final double volume;
  final bool isLoading;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final String? contextId; // ID del contexto actual (playlistId o artistId)
  final bool shouldStartAlgorithmAfterQueue; // Bandera para iniciar algoritmo al finalizar cola fija

  const PlaybackState({
    this.playbackMode = PlaybackMode.none,
    this.currentQueue = const [],
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlayerExpanded = false,
    this.volume = 0.85,
    this.isLoading = false,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.off,
    this.contextId,
    this.shouldStartAlgorithmAfterQueue = false,
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
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isPlayerExpanded,
    double? volume,
    bool? isLoading,
    bool? isShuffled,
    RepeatMode? repeatMode,
    String? contextId,
    bool? shouldStartAlgorithmAfterQueue,
  }) {
    return PlaybackState(
      playbackMode: playbackMode ?? this.playbackMode,
      currentQueue: currentQueue ?? this.currentQueue,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      volume: volume ?? this.volume,
      isLoading: isLoading ?? this.isLoading,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      contextId: contextId ?? this.contextId,
      shouldStartAlgorithmAfterQueue: shouldStartAlgorithmAfterQueue ?? this.shouldStartAlgorithmAfterQueue,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaybackState &&
        other.playbackMode == playbackMode &&
        other.currentQueue.length == currentQueue.length &&
        other.currentSong?.id == currentSong?.id &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.currentPosition == currentPosition &&
        other.totalDuration == totalDuration &&
        other.isPlayerExpanded == isPlayerExpanded &&
        other.volume == volume &&
        other.isLoading == isLoading &&
        other.isShuffled == isShuffled &&
        other.repeatMode == repeatMode &&
        other.contextId == contextId &&
        other.shouldStartAlgorithmAfterQueue == shouldStartAlgorithmAfterQueue;
  }

  @override
  int get hashCode {
    return Object.hash(
      playbackMode,
      currentQueue.length,
      currentSong?.id,
      isPlaying,
      isBuffering,
      currentPosition,
      totalDuration,
      isPlayerExpanded,
      volume,
      isLoading,
      isShuffled,
      repeatMode,
      contextId,
      shouldStartAlgorithmAfterQueue,
    );
  }

  @override
  String toString() {
    return 'PlaybackState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

