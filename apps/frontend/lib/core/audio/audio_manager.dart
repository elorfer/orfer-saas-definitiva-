import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../models/playback_context.dart';
import '../services/professional_audio_service.dart';
import '../services/playback_context_service.dart';
import '../services/spotify_recommendation_service.dart';
import '../services/intelligent_featured_service.dart';
import '../services/http_client_service.dart';
import '../services/image_preloader_service.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';
import '../providers/unified_audio_provider.dart';

/// AudioManager - Controlador global de audio estilo Spotify
/// Singleton que maneja toda la reproducción de audio de la app
class AudioManager {
  // Singleton - Solo una instancia global
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // Servicio de audio profesional (singleton)
  ProfessionalAudioService? _audioService;
  
  // Servicio de contexto de reproducción
  PlaybackContextService? _contextService;
  
  // Streams para UI - Broadcast para múltiples listeners
  final _currentSongController = StreamController<Song?>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  
  // Suscripciones - SOLO UNA POR TIPO
  StreamSubscription<Song?>? _currentSongSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  
  // Estado interno
  bool _isInitialized = false;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Flag para controlar si se debe abrir el reproductor automáticamente
  bool _shouldAutoOpenPlayer = true;
  
  // Sistema de precarga inteligente
  bool _isPreloading = false;
  
  // Fade-in
  Timer? _fadeTimer;
  static const Duration _fadeDuration = Duration(milliseconds: 280);
  static const int _fadeSteps = 20;
  static const double _targetVolume = 0.85;
  
  // Callback para abrir el full player
  VoidCallback? _onOpenFullPlayer;
  
  // Callback para obtener la siguiente canción destacada
  Future<Song?> Function(Song currentSong)? _onGetNextFeaturedSong;
  
  // Container para sincronización de estado
  ProviderContainer? _stateContainer;
  
  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  
  // Streams públicos para UI
  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  
  /// Getter para el contexto actual
  PlaybackContext? get currentContext => _contextService?.currentContext;
  
  /// Stream del contexto actual
  Stream<PlaybackContext?> get contextStream => _contextService?.contextStream ?? const Stream.empty();
  
  /// Inicializar el AudioManager
  Future<void> initialize({bool enableBackground = true}) async {
    if (_isInitialized) {
      AppLogger.info('[AudioManager] Ya está inicializado');
      return;
    }
    
    try {
      // Obtener el servicio de audio (singleton)
      _audioService = ProfessionalAudioService();
      
      // Inicializar el servicio
      await _audioService!.initialize(enableBackground: enableBackground);
      
      // Configurar listeners UNA SOLA VEZ
      _setupListeners();
      
      // Inicializar servicio de contexto
      _contextService = PlaybackContextService();
      
      // Configurar callbacks del contexto
      _contextService!.setCallbacks(
        onGetNextFeaturedSong: _onGetNextFeaturedSong,
      );
      
      _isInitialized = true;
      AppLogger.info('[AudioManager] Inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al inicializar: $e', stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Configurar listeners para sincronizar estado
  void _setupListeners() {
    // Cancelar listeners anteriores si existen
    _disposeListeners();
    
    final controller = _audioService?.controller;
    if (controller == null) {
      AppLogger.warning('[AudioManager] Controller es null');
      return;
    }
    
    // Escuchar cambios en la canción actual (OPTIMIZADO 🚀)
    _currentSongSubscription = controller.currentSongStream.listen(
      (song) {
        // Solo notificar si la canción realmente cambió
        if (_currentSong?.id != song?.id) {
          _currentSong = song;
          if (!_currentSongController.isClosed) {
            _currentSongController.add(song);
          }
          _syncState(); // 🔄 Sincronizar estado
          debugPrint('🎵 [AudioManager] Canción cambió: ${song?.title ?? 'null'}');
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en currentSongStream: $error');
      },
    );
    
    // Escuchar cambios en el estado del reproductor
    _stateSubscription = controller.stateStream.listen(
      (state) {
        final wasPlaying = _isPlaying;
        _isPlaying = state.playing;
        
        if (wasPlaying != _isPlaying && !_isPlayingController.isClosed) {
          _isPlayingController.add(_isPlaying);
          _syncState(); // 🔄 Sincronizar estado
        }
        
        // ⚠️ DESACTIVADO: UnifiedAudioProviderFixed maneja la finalización
        // La lógica de siguiente canción está en UnifiedAudioProviderFixed
        if (state.processingState == ProcessingState.completed) {
          // _handleSongCompletion(); // DESACTIVADO para evitar duplicación
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en stateStream: $error');
      },
    );
    
    // Escuchar cambios en la posición
    _positionSubscription = controller.positionStream.listen(
      (position) {
        _position = position;
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en positionStream: $error');
      },
    );
    
    // Escuchar cambios en la duración
    _durationSubscription = controller.durationStream.listen(
      (duration) {
        if (duration != null) {
          _duration = duration;
          if (!_durationController.isClosed) {
            _durationController.add(duration);
          }
        }
      },
      onError: (error) {
        AppLogger.error('[AudioManager] Error en durationStream: $error');
      },
    );
    
    AppLogger.info('[AudioManager] Listeners configurados');
  }
  
  /// Configurar callback para abrir el full player
  void setOnOpenFullPlayerCallback(VoidCallback? callback) {
    _onOpenFullPlayer = callback;
  }
  
  /// Configurar callback para obtener la siguiente canción destacada
  void setOnGetNextFeaturedSongCallback(Future<Song?> Function(Song currentSong)? callback) {
    _onGetNextFeaturedSong = callback;
  }
  
  /// Configurar container para el provider unificado
  void setContainer(ProviderContainer container) {
    _stateContainer = container;
    AppLogger.info('[AudioManager] 🔗 Container configurado para provider unificado');
  }
  
  /// Configurar sincronización con el estado unificado
  void _setupStateSync(ProviderContainer container) {
    _stateContainer = container;
    debugPrint('[AudioManager] 🔗 Sincronización de estado configurada');
  }
  
  /// Sincronizar estado con el provider unificado
  void _syncState() {
    if (_stateContainer != null) {
      try {
        // Importar el provider dinámicamente para evitar dependencias circulares
        // El provider se actualizará automáticamente a través de los streams
        debugPrint('[AudioManager] 🔄 Estado sincronizado - currentSong: ${_currentSong?.title}, isPlaying: $_isPlaying');
      } catch (e) {
        debugPrint('[AudioManager] ❌ Error sincronizando estado: $e');
      }
    }
  }
  
  /// Configurar si el reproductor debe abrirse automáticamente
  void setAutoOpenPlayer(bool autoOpen) {
    _shouldAutoOpenPlayer = autoOpen;
  }
  
  /// Abrir el reproductor completo
  void openFullPlayer() {
    if (_onOpenFullPlayer != null) {
      _onOpenFullPlayer!();
    }
  }
  
  /// Establecer contexto de canciones destacadas
  void setFeaturedSongsContext(Song currentSong) {
    _contextService?.setFeaturedSongsContext(currentSong);
  }
  
  /// Establecer contexto de playlist
  void setPlaylistContext({
    required String playlistId,
    required String playlistName,
    String? description,
    String? imageUrl,
    required List<Song> songs,
    int startIndex = 0,
    bool shuffle = false,
    bool repeat = false,
  }) {
    _contextService?.setPlaylistContext(
      playlistId: playlistId,
      playlistName: playlistName,
      description: description,
      imageUrl: imageUrl,
      songs: songs,
      startIndex: startIndex,
      shuffle: shuffle,
      repeat: repeat,
    );
  }
  
  /// Establecer contexto de artista destacado
  void setFeaturedArtistContext({
    required String artistId,
    required String artistName,
    String? imageUrl,
    required List<Song> songs,
    int startIndex = 0,
    bool shuffle = false,
  }) {
    _contextService?.setFeaturedArtistContext(
      artistId: artistId,
      artistName: artistName,
      imageUrl: imageUrl,
      songs: songs,
      startIndex: startIndex,
      shuffle: shuffle,
    );
  }
  
  /// Precarga una canción en segundo plano
  Future<void> preloadSong(Song song) async {
    if (!_isInitialized || _audioService == null || _isPreloading) {
      return;
    }
    
    if (_currentSong?.id == song.id) {
      return;
    }
    
    try {
      _isPreloading = true;
      AppLogger.info('[AudioManager] Precargando: ${song.title}');
      
      final tempPlayer = AudioPlayer();
      final normalizedUrl = song.fileUrl != null 
          ? UrlNormalizer.normalizeUrl(song.fileUrl!, enableLogging: false)
          : null;
          
      if (normalizedUrl == null) {
        throw Exception('URL de canción no válida');
      }
      
      await tempPlayer.setUrl(normalizedUrl);
      
      Future.delayed(const Duration(seconds: 30), () {
        tempPlayer.dispose();
      });
      
      AppLogger.info('[AudioManager] Canción precargada: ${song.title}');
    } catch (e) {
      AppLogger.warning('[AudioManager] Error al precargar: $e');
    } finally {
      _isPreloading = false;
    }
  }
  
  /// Reproducir una canción destacada (con siguiente automática)
  Future<void> playFeaturedSong(Song song, {Map<String, dynamic>? metadata}) async {
    AppLogger.info('[AudioManager] 🌟 Reproduciendo canción DESTACADA: ${song.title}');
    return playSong(song, metadata: metadata, isFeatured: true);
  }
  
  /// Reproducir una canción
  Future<void> playSong(Song song, {Map<String, dynamic>? metadata, bool? isFeatured}) async {
    if (!_isInitialized || _audioService == null) {
      throw Exception('AudioManager no está inicializado');
    }
    
    // 🚀 USAR EL PROVIDER UNIFICADO DIRECTAMENTE
    if (_stateContainer != null) {
      try {
        await _stateContainer!.read(unifiedAudioProvider.notifier).playSong(song);
        AppLogger.info('[AudioManager] ✅ Canción enviada al provider unificado');
        return; // El provider unificado maneja todo
      } catch (e) {
        AppLogger.error('[AudioManager] ❌ Error con provider unificado, usando fallback: $e');
        // Continuar con la lógica original como fallback
      }
    }
    
    debugPrint('🔍 Verificando URL: ${song.fileUrl}');
    
    // CORRECCIÓN DE EMERGENCIA: Si la URL es null, reconstruirla desde el backend
    String? finalUrl = song.fileUrl;
    if (finalUrl == null || finalUrl.isEmpty) {
      debugPrint('❌ URL es null o vacía - aplicando corrección de emergencia');
      debugPrint('🔍 Song ID: ${song.id}');
      debugPrint('🔍 Song title: ${song.title}');
      
      // SOLUCIÓN TEMPORAL: Construir URL manualmente basada en el ID de la canción
      // Esto es una solución de emergencia mientras se arregla el mapeo de datos
      if (song.id.isNotEmpty) {
        // Intentar construir la URL basada en el patrón que conocemos
        finalUrl = 'http://10.0.2.2:3001/songs/${song.id}.mp3';
        debugPrint('🔧 URL construida manualmente: $finalUrl');
        
        // Alternativamente, intentar petición al backend
        try {
          final dio = Dio();
          final response = await dio.get('http://10.0.2.2:3001/api/v1/public/songs/${song.id}');
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data as Map<String, dynamic>;
            final backendUrl = data['fileUrl'] as String?;
            if (backendUrl != null && backendUrl.isNotEmpty) {
              finalUrl = backendUrl;
              // Normalizar la URL
              if (finalUrl.contains('localhost:3000')) {
                finalUrl = finalUrl.replaceAll('localhost:3000', '10.0.2.2:3001');
              } else if (finalUrl.contains('localhost:3001')) {
                finalUrl = finalUrl.replaceAll('localhost:3001', '10.0.2.2:3001');
              }
              debugPrint('🔧 URL obtenida del backend: $finalUrl');
            }
          }
        } catch (e) {
          debugPrint('❌ Error al obtener URL del backend, usando URL construida: $e');
          // Mantener la URL construida manualmente como fallback
        }
      }
      
      if (finalUrl == null || finalUrl.isEmpty) {
        throw Exception('La canción no tiene archivo de audio disponible');
      }
    }
    
    // Verificar que la URL sea válida
    if (!finalUrl.startsWith('http')) {
      debugPrint('❌ URL no es válida: $finalUrl');
      throw Exception('URL de archivo no válida: $finalUrl');
    }
    
    debugPrint('✅ URL válida: $finalUrl');
    
    try {
      AppLogger.info('[AudioManager] Reproduciendo: ${song.title}');
      
      // Establecer contexto SOLO si es una canción destacada
      final isActuallyFeatured = isFeatured ?? metadata?['featured'] ?? false;
      debugPrint('🎵 Reproduciendo: ${song.title}');
      debugPrint('⭐ Es destacada: $isActuallyFeatured');
      
      if (isActuallyFeatured) {
        debugPrint('✅ Estableciendo contexto DESTACADAS');
        setFeaturedSongsContext(song);
      } else {
        debugPrint('ℹ️ Canción NORMAL - sin contexto destacadas');
        // No establecer contexto de destacadas para canciones normales
      }
      
      // Cargar y reproducir la canción
      await _loadAndPlaySong(song);
      
      // Abrir full player si está configurado
      if (_shouldAutoOpenPlayer) {
        openFullPlayer();
      }
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al reproducir: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Método privado para cargar y reproducir una canción
  Future<void> _loadAndPlaySong(Song song) async {
    try {
      if (_currentSong?.id == song.id && _isPlaying) {
        return;
      }
      
      final controller = _audioService!.controller;
      if (controller == null) {
        throw Exception('Controller no disponible');
      }
      
      // Detener canción anterior si es diferente
      if (_currentSong != null && _currentSong!.id != song.id && _isPlaying) {
        _fadeTimer?.cancel();
        _fadeTimer = null;
        await _audioService!.pause();
        await controller.player.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Cargar nueva canción
      await _audioService!.loadSong(song);
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Verificar carga
      if (controller.currentSong?.id != song.id) {
        throw Exception('Error al cargar la canción');
      }
      
      // Reproducir con fade-in
      await _playWithFadeIn();
      
      AppLogger.info('[AudioManager] Canción iniciada: ${song.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error al cargar canción: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Reproducir con fade-in suave
  Future<void> _playWithFadeIn() async {
    final controller = _audioService?.controller;
    if (controller == null) return;
    
    final player = controller.player;
    
    // Cancelar fade-in anterior
    _fadeTimer?.cancel();
    
    // Iniciar con volumen 0
    await player.setVolume(0.0);
    await _audioService!.play();
    
    // Fade-in gradual
    int step = 0;
    final stepDuration = _fadeDuration ~/ _fadeSteps;
    final volumeStep = _targetVolume / _fadeSteps;
    
    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      if (step >= _fadeSteps) {
        player.setVolume(_targetVolume);
        timer.cancel();
        _fadeTimer = null;
      } else {
        player.setVolume(volumeStep * step);
      }
    });
  }
  
  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (!_isInitialized || _audioService == null) {
      throw Exception('AudioManager no está inicializado');
    }
    
    try {
      if (_currentSong == null) {
        return;
      }
      
      if (_isPlaying) {
        _fadeTimer?.cancel();
        _fadeTimer = null;
        await _audioService!.pause();
      } else {
        await _audioService!.play();
      }
    } catch (e, stackTrace) {
      AppLogger.error('[AudioManager] Error en togglePlayPause: $e', stackTrace);
      rethrow;
    }
  }
  
  /// Detener la reproducción
  Future<void> stop() async {
    if (!_isInitialized || _audioService == null) return;
    
    try {
      _fadeTimer?.cancel();
      _fadeTimer = null;
      
      await _audioService!.pause();
      
      final controller = _audioService!.controller;
      if (controller != null) {
        await controller.player.stop();
      }
    } catch (e) {
      AppLogger.error('[AudioManager] Error al detener: $e');
    }
  }
  
  /// Cancelar listeners
  void _disposeListeners() {
    _currentSongSubscription?.cancel();
    _currentSongSubscription = null;
    
    _stateSubscription?.cancel();
    _stateSubscription = null;
    
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _durationSubscription?.cancel();
    _durationSubscription = null;
  }
  
  /// DESACTIVADO: Manejar cuando una canción termina - buscar siguiente recomendada
  /// La lógica ahora está en UnifiedAudioProviderFixed para evitar duplicación
  // ignore: unused_element
  void _handleSongCompletion() async {
    try {
      debugPrint('🎵 === INICIO PROCESO SIGUIENTE CANCIÓN ===');
      
      final currentSong = _currentSong;
      if (currentSong == null) {
        debugPrint('❌ FALLO: No hay canción actual');
        return;
      }
      
      debugPrint('✅ Canción actual: ${currentSong.title}');
      
      // VERIFICAR CONTEXTO (AHORA FUNCIONA PARA TODAS LAS CANCIONES)
      final currentContext = _contextService?.currentContext;
      final isFeaturedContext = currentContext?.type == PlaybackContextType.featuredSongs;
      
      debugPrint('🏷️ Contexto: ${currentContext?.type}');
      debugPrint('⭐ Es destacado: $isFeaturedContext');
      
      // ✅ CAMBIO: Ahora funciona para TODAS las canciones, no solo destacadas
      debugPrint('✅ CONTINUANDO: Recomendaciones habilitadas para todas las canciones');
      
      debugPrint('✅ Buscando siguiente canción recomendada...');
      
      debugPrint('🔍 Buscando siguiente canción...');
      final nextSong = await _getRecommendedSong(currentSong.id, currentSong.genres);
      
      if (nextSong != null) {
        debugPrint('✅ SIGUIENTE ENCONTRADA: ${nextSong.title}');
        debugPrint('▶️ Reproduciendo automáticamente...');
        
        // 🧠 ESTABLECER CONTEXTO DE CANCIONES DESTACADAS INTELIGENTES
        // Esto permite que las siguientes canciones también usen el algoritmo
        if (_contextService != null) {
          try {
            debugPrint('🏷️ Estableciendo contexto de canciones destacadas inteligentes');
            _contextService!.setFeaturedSongsContext(nextSong);
            debugPrint('✅ Contexto establecido correctamente');
          } catch (e) {
            debugPrint('⚠️ Error estableciendo contexto: $e');
          }
        }
        
        // Reproducir la canción recomendada
        await playSong(nextSong, isFeatured: true);
        debugPrint('✅ Reproducción completada');
        
        // 🖼️ Precargar carátula de la próxima canción recomendada
        _preloadNextSongCover(nextSong);
      } else {
        debugPrint('❌ No hay siguiente disponible');
      }
      
      debugPrint('🎵 === FIN PROCESO ===');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR CRÍTICO: $e');
      debugPrint('Stack: $stackTrace');
    }
  }
  
  /// Obtener canción recomendada usando el algoritmo inteligente
  Future<Song?> _getRecommendedSong(String currentSongId, List<String>? genres) async {
    try {
      AppLogger.info('[AudioManager] 🧠 Buscando recomendación INTELIGENTE para: $currentSongId');
      AppLogger.info('[AudioManager] 🏷️ Con géneros: ${genres?.join(', ') ?? 'ninguno'}');
      
      // ESTRATEGIA 1: Usar el servicio inteligente de canciones destacadas
      try {
        final intelligentService = IntelligentFeaturedService();
        final intelligentSongs = await intelligentService.getIntelligentFeaturedSongs(
          limit: 10, // Obtener varias opciones
          currentSongId: currentSongId,
          forceRefresh: false, // Usar cache para mejor rendimiento
        );
        
        if (intelligentSongs.isNotEmpty) {
          // Filtrar canciones que no sean la actual
          final availableSongs = intelligentSongs
              .where((featured) => featured.song.id != currentSongId)
              .toList();
          
          if (availableSongs.isNotEmpty) {
            // Seleccionar la primera recomendación inteligente
            final selectedSong = availableSongs.first.song;
            AppLogger.info('[AudioManager] 🧠 Recomendación INTELIGENTE encontrada: ${selectedSong.title}');
            AppLogger.info('[AudioManager] 🏷️ Razón: ${availableSongs.first.featuredReason}');
            AppLogger.info('[AudioManager] 🎵 Géneros: ${selectedSong.genres?.join(', ') ?? 'ninguno'}');
            return selectedSong;
          }
        }
      } catch (e) {
        AppLogger.warning('[AudioManager] ⚠️ Error en servicio inteligente, usando fallback: $e');
      }
      
      // ESTRATEGIA 2: Fallback al servicio de recomendaciones directo
      AppLogger.info('[AudioManager] 🔄 Usando fallback: servicio de recomendaciones directo');
      final recommendationService = SpotifyRecommendationService(HttpClientService());
      final nextSong = await recommendationService.getSmartRecommendation(
        currentSongId: currentSongId,
        genres: genres,
        user: null, // TODO: Pasar usuario actual cuando esté disponible
      );
      
      if (nextSong != null) {
        AppLogger.info('[AudioManager] ✅ Recomendación fallback encontrada: ${nextSong.title}');
        AppLogger.info('[AudioManager] 🏷️ Géneros de la recomendación: ${nextSong.genres?.join(', ') ?? 'ninguno'}');
      } else {
        AppLogger.warning('[AudioManager] ❌ No se encontró recomendación en ninguna estrategia');
      }
      
      return nextSong;
    } catch (e) {
      AppLogger.error('[AudioManager] ❌ Error crítico obteniendo recomendación: $e');
      return null;
    }
  }
  
  /// Precargar carátula de la próxima canción recomendada inteligente
  Future<void> _preloadNextSongCover(Song currentSong) async {
    try {
      debugPrint('🖼️ [AudioManager] Iniciando preload inteligente de próxima carátula...');
      
      // Obtener la próxima canción recomendada usando el algoritmo inteligente
      final nextSong = await _getRecommendedSong(currentSong.id, currentSong.genres);
      
      if (nextSong != null && nextSong.coverArtUrl != null) {
        debugPrint('🖼️ [AudioManager] Precargando carátula inteligente de: ${nextSong.title}');
        // Marcar como precargada en el servicio
        ImagePreloaderService().markAsPreloaded(nextSong.coverArtUrl!);
      } else {
        debugPrint('🖼️ [AudioManager] No hay próxima canción para precargar');
      }
    } catch (e) {
      debugPrint('❌ [AudioManager] Error precargando próxima carátula inteligente: $e');
    }
  }
  
  /// Limpiar recursos
  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    
    _disposeListeners();
    
    // Cerrar streams
    _currentSongController.close();
    _isPlayingController.close();
    _positionController.close();
    _durationController.close();
    
    _isInitialized = false;
    _currentSong = null;
    _audioService = null;
    
    AppLogger.info('[AudioManager] Dispose completado');
  }
}

/// Provider de AudioManager (singleton) con sincronización de estado
final audioManagerProvider = Provider<AudioManager>((ref) {
  final manager = AudioManager();
  
  // 🔥 CONFIGURAR SINCRONIZACIÓN CON EL ESTADO UNIFICADO
  manager._setupStateSync(ref.container);
  
  ref.onDispose(() {
    // Mantener el singleton activo
  });
  
  return manager;
});