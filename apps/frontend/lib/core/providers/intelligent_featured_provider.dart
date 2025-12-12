import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/intelligent_featured_service.dart';
import '../services/spotify_recommendation_service.dart';
import '../services/home_service.dart';
import '../services/http_client_service.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';
import 'unified_audio_provider_fixed.dart';

/// Provider para el servicio de canciones destacadas inteligentes
final intelligentFeaturedServiceProvider = Provider<IntelligentFeaturedService>((ref) {
  return IntelligentFeaturedService(
    homeService: HomeService(),
    recommendationService: SpotifyRecommendationService(HttpClientService()),
  );
});

/// Estado para las canciones destacadas inteligentes
class IntelligentFeaturedState {
  final List<FeaturedSong> featuredSongs;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isInitialized;

  const IntelligentFeaturedState({
    this.featuredSongs = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isInitialized = false,
  });

  IntelligentFeaturedState copyWith({
    List<FeaturedSong>? featuredSongs,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isInitialized,
  }) {
    return IntelligentFeaturedState(
      featuredSongs: featuredSongs ?? this.featuredSongs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get hasError => error != null;
  bool get isEmpty => featuredSongs.isEmpty;
  bool get hasData => featuredSongs.isNotEmpty;
}

/// Notifier para manejar las canciones destacadas inteligentes
class IntelligentFeaturedNotifier extends Notifier<IntelligentFeaturedState> {
  late final IntelligentFeaturedService _service;

  @override
  IntelligentFeaturedState build() {
    _service = ref.read(intelligentFeaturedServiceProvider);
    // ✅ OPTIMIZACIÓN: NO inicializar automáticamente - dejar que los widgets lo hagan cuando lo necesiten
    // Esto evita cargar datos innecesarios al inicio
    return const IntelligentFeaturedState();
  }

  /// 🧠 CARGAR CANCIONES DESTACADAS INTELIGENTES
  /// Usa tu algoritmo avanzado de recomendaciones
  Future<void> loadIntelligentFeaturedSongs({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Obtener información del usuario y canción actual para personalización
      final audioState = ref.read(unifiedAudioProviderFixed);
      final currentSongId = audioState.currentSong?.id;
      
      // Nota: Obtener usuario actual cuando esté implementado el sistema de auth
      User? currentUser;

      // Usar el servicio inteligente con tu algoritmo
      final intelligentSongs = await _service.getIntelligentFeaturedSongs(
        limit: limit,
        user: currentUser,
        currentSongId: currentSongId,
        forceRefresh: forceRefresh,
      );

      state = state.copyWith(
        featuredSongs: intelligentSongs,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
        isInitialized: true,
      );

      // Log de éxito
      final staticCount = intelligentSongs.where((s) => 
        s.featuredReason?.contains('administrador') == true).length;
      final dynamicCount = intelligentSongs.length - staticCount;
      
      debugPrint('🧠 [IntelligentFeatured] Cargadas ${intelligentSongs.length} canciones');
      debugPrint('📌 [IntelligentFeatured] Estáticas: $staticCount, Dinámicas: $dynamicCount');

    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar recomendaciones inteligentes: $error',
        isInitialized: true,
      );
      
      debugPrint('❌ [IntelligentFeatured] Error: $error');
      debugPrint('📍 [IntelligentFeatured] Stack: $stackTrace');
    }
  }

  /// 🔄 REFRESCAR RECOMENDACIONES
  /// Fuerza una actualización completa usando tu algoritmo
  Future<void> refreshIntelligentRecommendations() async {
    await loadIntelligentFeaturedSongs(forceRefresh: true);
  }

  /// 🎵 ACTUALIZAR BASADO EN CANCIÓN ACTUAL
  /// Se llama cuando cambia la canción para obtener nuevas recomendaciones
  /// ✅ OPTIMIZACIÓN: Solo actualiza si han pasado más de 3 minutos desde la última actualización
  Future<void> updateBasedOnCurrentSong() async {
    if (!state.isInitialized || state.isLoading) return;
    
    // ✅ OPTIMIZACIÓN: Aumentado de 2 a 3 minutos para reducir llamadas API
    if (state.lastUpdated != null) {
      final timeSinceUpdate = DateTime.now().difference(state.lastUpdated!);
      if (timeSinceUpdate.inMinutes < 3) return;
    }

    await loadIntelligentFeaturedSongs();
  }

  /// 🧹 LIMPIAR ERROR
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 📊 OBTENER MÉTRICAS DEL ALGORITMO
  Map<String, dynamic> getAlgorithmMetrics() {
    return _service.getMetrics();
  }
}

/// Provider principal para las canciones destacadas inteligentes
final intelligentFeaturedProvider = NotifierProvider<IntelligentFeaturedNotifier, IntelligentFeaturedState>(() {
  return IntelligentFeaturedNotifier();
});

/// 🚀 PROVIDER OPTIMIZADO PARA SOLO LAS CANCIONES
/// 🔥 OPTIMIZACIÓN: Usa selector + keepAlive para memoization y evitar rebuilds innecesarios
final intelligentFeaturedSongsProvider = Provider<List<FeaturedSong>>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(intelligentFeaturedProvider.select((state) => state.featuredSongs));
});

/// 🚀 PROVIDER CON CACHÉ PARA CANCIONES PAGINADAS
/// Implementa paginación virtual para listas grandes
/// 🔥 OPTIMIZACIÓN: keepAlive para memoization
final intelligentFeaturedSongsPaginatedProvider = Provider.family<List<FeaturedSong>, int>((ref, pageSize) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  final allSongs = ref.watch(intelligentFeaturedSongsProvider);
  return allSongs.take(pageSize).toList();
});

/// Provider selector para el estado de carga
/// 🔥 OPTIMIZACIÓN: keepAlive para memoization
final intelligentFeaturedLoadingProvider = Provider<bool>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(intelligentFeaturedProvider.select((state) => state.isLoading));
});

/// Provider selector para errores
/// 🔥 OPTIMIZACIÓN: keepAlive para memoization
final intelligentFeaturedErrorProvider = Provider<String?>((ref) {
  // 🔥 OPTIMIZACIÓN: keepAlive para memoization - evita recálculos innecesarios
  ref.keepAlive();
  return ref.watch(intelligentFeaturedProvider.select((state) => state.error));
});

/// ✅ OPTIMIZACIÓN: Listener de audio desactivado para evitar sobrecarga del home
/// Si se necesita en el futuro, se puede activar manualmente desde widgets específicos
