import 'package:flutter/widgets.dart' hide RepeatMode;
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
  offline,     // 🛡️ MODO BÚNKER: Solo archivos locales, sin red, sin algoritmo
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
  
  // Flags de UI
  final bool isMiniPlayerVisible; // 🥷 NINJA MODE: Control de visibilidad independiente de la carga de audio
  final bool isSessionActive; // 🏆 SPOTIFY-LEVEL: Sesión de escucha activa (usuario dio play explícitamente)

  // Flags de control optimista
  final bool isProcessingPlayPause;
  final bool isProcessingNext;
  final bool isProcessingPrevious;
  
  // Estado de anuncios
  final AudioAd? currentAd;
  final bool isPlayingAd;
  final bool isInsertingAd; // ✅ FIX: Flag para blindaje de carátula durante inserción
  
  // 🛡️ ANTI-FLICKER: Cache de última carátula válida para evitar parpadeos durante transiciones
  final String? lastKnownCoverUrl;
  
  // ⏳ WAITING: Indica que el usuario debe esperar porque no hay más canciones
  final bool isWaitingForMoreSongs;

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
    this.isMiniPlayerVisible = false, // Default false para arranque limpio
    this.isSessionActive = false, // 🏆 SPOTIFY-LEVEL: Default false hasta que usuario active play
    this.currentAd,
    this.isPlayingAd = false,
    this.isInsertingAd = false,
    this.lastKnownCoverUrl,
    this.isWaitingForMoreSongs = false, // ⏳ WAITING: Default false
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

  /// Obtener el índice de la canción actual en la cola
  int get currentIndex {
    if (currentSong == null || currentQueue.isEmpty) return -1;
    return currentQueue.indexWhere((s) => s.id == currentSong!.id);
  }

  /// Indica si el sistema está generando/solicitando nuevas canciones (autoplay/algoritmo)
  bool get isGeneratingMusic => playbackMode == PlaybackMode.algorithm && isLoading;

  /// 🛡️ BLINDAJE DE CARÁTULA: Getter prioritario para la URL de la portada
  /// Si hay un anuncio reproduciéndose O insertándose, devuelve estrictamente la imagen del anuncio.
  /// Esto evita el "spoiler visual" de la siguiente canción durante la transición.
  /// 🛡️ ANTI-FLICKER: Usa caché para evitar parpadeos durante transiciones rápidas.
  String? get currentCoverUrl {
    String? url;
    
    // Prioridad 1: Anuncio insertándose o reproduciéndose
    if (isInsertingAd && currentAd != null) {
      url = currentAd!.coverImageUrl;
    } else if (isPlayingAd && currentAd != null) {
      url = currentAd!.coverImageUrl;
    } else {
      // Prioridad 2: Canción actual
      url = currentSong?.coverArtUrl;
    }
    
    // 🛡️ ANTI-FLICKER: Si no hay URL válida, usar la última conocida
    // Esto previene parpadeos durante transiciones de estado rápidas en debug mode
    return url ?? lastKnownCoverUrl;
  }

  /// 🛡️ DICTATOR GETTER: Título prioritario
  /// Si hay anuncio, devuelve el título del anuncio.
  String? get currentTitle {
    if ((isPlayingAd || isInsertingAd) && currentAd != null) {
      return currentAd!.title;
    }
    return currentSong?.title;
  }

  /// 🛡️ DICTATOR GETTER: Artista prioritario
  /// Si hay anuncio, devuelve el nombre del anunciante o "Publicidad".
  String? get currentArtist {
    if ((isPlayingAd || isInsertingAd) && currentAd != null) {
      return currentAd!.advertiserName;
    }
    return currentSong?.artist?.stageName;
  }

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
    bool? isMiniPlayerVisible,
    bool? isSessionActive, // 🏆 SPOTIFY-LEVEL: Control de sesión activa
    AudioAd? currentAd,
    bool? isPlayingAd,
    bool? isInsertingAd,
    String? lastKnownCoverUrl,
    bool? isWaitingForMoreSongs, // ⏳ WAITING: Espera de canciones
    // ✅ FIX CRÍTICO: Flags para permitir establecer null explícitamente
    bool clearCurrentAd = false,
    bool clearCurrentSong = false,
    bool clearLastConfirmedSong = false,
  }) {
    // 🛡️ ANTI-FLICKER: Calcular la nueva URL de carátula para el caché
    String? newCoverUrl = lastKnownCoverUrl;
    if (newCoverUrl == null) {
      // Auto-calcular desde los valores nuevos o actuales
      final effectiveSong = clearCurrentSong ? null : (currentSong ?? this.currentSong);
      final effectiveAd = clearCurrentAd ? null : (currentAd ?? this.currentAd);
      final effectiveIsPlayingAd = isPlayingAd ?? this.isPlayingAd;
      final effectiveIsInsertingAd = isInsertingAd ?? this.isInsertingAd;
      
      if ((effectiveIsInsertingAd || effectiveIsPlayingAd) && effectiveAd != null) {
        newCoverUrl = effectiveAd.coverImageUrl;
      } else if (effectiveSong != null) {
        newCoverUrl = effectiveSong.coverArtUrl;
      }
    }
    // Usar la nueva o mantener la anterior si no hay nueva
    newCoverUrl ??= this.lastKnownCoverUrl;
    
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
      isMiniPlayerVisible: isMiniPlayerVisible ?? this.isMiniPlayerVisible,
      isSessionActive: isSessionActive ?? this.isSessionActive, // 🏆 SPOTIFY-LEVEL
      currentAd: clearCurrentAd ? null : (currentAd ?? this.currentAd),
      isPlayingAd: isPlayingAd ?? this.isPlayingAd,
      isInsertingAd: isInsertingAd ?? this.isInsertingAd,
      lastKnownCoverUrl: newCoverUrl, // 🛡️ ANTI-FLICKER: Siempre mantener un caché válido
      isWaitingForMoreSongs: isWaitingForMoreSongs ?? this.isWaitingForMoreSongs, // ⏳ WAITING
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
        other.isMiniPlayerVisible == isMiniPlayerVisible &&
        other.currentAd?.id == currentAd?.id &&
        other.isPlayingAd == isPlayingAd &&
        other.isInsertingAd == isInsertingAd;
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
      Object.hash(isMiniPlayerVisible, currentAd?.id, isPlayingAd, isInsertingAd), // Combinar campos de anuncios y visibilidad
    );
  }

  @override
  String toString() {
    return 'PlaybackState(song: ${currentSong?.title}, playing: $isPlaying, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}
