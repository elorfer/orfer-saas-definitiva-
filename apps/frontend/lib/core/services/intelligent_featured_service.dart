import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../models/user_model.dart';
import 'http_client_service.dart';
import 'spotify_recommendation_service.dart';
import 'home_service.dart';
import 'recommendation_cache_service.dart';
import '../utils/logger.dart';

/// 🧠 SERVICIO DE CANCIONES DESTACADAS INTELIGENTES
/// 
/// Combina:
/// 1. Canciones destacadas estáticas (marcadas por admin)
/// 2. Recomendaciones dinámicas usando tu algoritmo avanzado
/// 3. Personalización basada en historial de usuario
/// 4. Diversidad y frescura en las recomendaciones
class IntelligentFeaturedService {
  final HomeService _homeService;
  final SpotifyRecommendationService _recommendationService;
  final RecommendationCacheService _cacheService = RecommendationCacheService();
  
  // Cache para recomendaciones inteligentes
  final Map<String, CachedFeaturedRecommendations> _cache = {};
  static const int _cacheTtlMs = 3 * 60 * 1000; // 3 minutos para más variedad
  
  // Configuración del algoritmo
  static const int _maxStaticFeatured = 8; // Máximo de canciones destacadas estáticas
  static const int _maxDynamicRecommendations = 12; // Máximo de recomendaciones dinámicas
  static const int _totalFeaturedSongs = 20; // Total de canciones destacadas a mostrar
  
  IntelligentFeaturedService({
    HomeService? homeService,
    SpotifyRecommendationService? recommendationService,
  }) : _homeService = homeService ?? HomeService(),
       _recommendationService = recommendationService ?? SpotifyRecommendationService(HttpClientService());

  /// 🎯 OBTENER CANCIONES DESTACADAS INTELIGENTES
  /// Combina canciones destacadas estáticas con recomendaciones dinámicas
  Future<List<FeaturedSong>> getIntelligentFeaturedSongs({
    int limit = _totalFeaturedSongs,
    User? user,
    String? currentSongId,
    bool forceRefresh = false,
    Set<String> excludeIds = const {}, // Nuevo parámetro para excluir canciones
  }) async {
    final startTime = DateTime.now();
    
    debugPrint('🧠 [IntelligentFeatured] === INICIANDO RECOMENDACIONES INTELIGENTES ===');
    debugPrint('🧠 [IntelligentFeatured] Límite: $limit canciones');
    debugPrint('👤 [IntelligentFeatured] Usuario: ${user?.id ?? 'anónimo'}');
    debugPrint('🎵 [IntelligentFeatured] Canción actual: ${currentSongId ?? 'ninguna'}');

    try {
      // 1. Verificar cache
      if (!forceRefresh) {
        final cacheKey = _generateCacheKey(user?.id, currentSongId, limit);
        final cached = _getCachedRecommendations(cacheKey);
        if (cached != null) {
          debugPrint('⚡ [IntelligentFeatured] Cache hit! Retornando ${cached.length} canciones');
          return cached;
        }
      }

      // 2. Obtener canciones destacadas estáticas (base sólida)
      final staticFeatured = await _getStaticFeaturedSongs();
      debugPrint('📌 [IntelligentFeatured] Canciones estáticas: ${staticFeatured.length}');

      // 3. 🎯 FORZAR RECOMENDACIONES DINÁMICAS SI HAY currentSongId (modo algoritmo)
      // Si hay un currentSongId, significa que estamos en modo algoritmo y necesitamos recomendaciones dinámicas
      List<FeaturedSong> dynamicRecommendations = [];
      
      if (currentSongId != null && currentSongId.isNotEmpty) {
        // 🚨 MODO ALGORITMO: Forzar recomendaciones dinámicas basadas en la canción actual
        // Ignorar las estáticas y obtener solo recomendaciones del algoritmo
        debugPrint('🎯 [IntelligentFeatured] Modo algoritmo detectado (currentSongId: $currentSongId). Forzando recomendaciones dinámicas...');
        
        // 🚨 CRÍTICO: NO excluir canciones estáticas de las recomendaciones dinámicas
        // Las canciones estáticas pueden ser válidas como recomendaciones dinámicas
        // Solo excluir la semilla (currentSongId) y los IDs explícitamente excluidos (cola/historial)
        // La deduplicación final se hará al combinar estáticas + dinámicas
        final combinedExcludeIds = {
          ...excludeIds, // Solo IDs de cola/historial, NO estáticas
        };
        
        // Obtener recomendaciones dinámicas para completar el límite solicitado
        // 🚨 LIMITAR A 15 recomendaciones máximo para evitar demasiadas llamadas HTTP simultáneas
        final dynamicCount = limit > 15 ? 15 : limit;
        debugPrint('🎯 [IntelligentFeatured] Solicitando $dynamicCount recomendaciones dinámicas (límite solicitado: $limit)');
        
        dynamicRecommendations = await _getDynamicRecommendations(
          count: dynamicCount, // Limitar a 15 para evitar demasiadas llamadas HTTP
          user: user,
          currentSongId: currentSongId,
          excludeIds: combinedExcludeIds, // Solo semilla + cola/historial, NO estáticas
        );
        debugPrint('🤖 [IntelligentFeatured] Recomendaciones dinámicas obtenidas: ${dynamicRecommendations.length}');
        
        // Si hay recomendaciones dinámicas, usar solo esas (ignorar estáticas en modo algoritmo)
        if (dynamicRecommendations.isNotEmpty) {
          final finalRecommendations = dynamicRecommendations.take(limit).toList();
          debugPrint('✅ [IntelligentFeatured] Usando ${finalRecommendations.length} recomendaciones dinámicas del algoritmo (solicitadas: $limit)');
          
          // ✅ CRÍTICO: Las recomendaciones vienen ordenadas por score del backend (mejor primero)
          // La primera canción es la mejor recomendación y será la siguiente canción
          if (finalRecommendations.isNotEmpty) {
            debugPrint('🎯 [IntelligentFeatured] SIGUIENTE CANCIÓN (mejor recomendación): ${finalRecommendations.first.song.title}');
          }
          
          // Log de las canciones recomendadas para debugging
          for (int i = 0; i < finalRecommendations.length && i < 5; i++) {
            debugPrint('   ${i + 1}. ${finalRecommendations[i].song.title}');
          }
          
          // ✅ IMPORTANTE: Retornar manteniendo el orden de score (mejor primero)
          // Retornar solo las dinámicas, ignorando las estáticas
          return finalRecommendations;
        } else {
          debugPrint('⚠️ [IntelligentFeatured] No se obtuvieron recomendaciones dinámicas, usando estáticas como fallback');
        }
      } else if (staticFeatured.length < 4) {
        // Solo agregar recomendaciones dinámicas si hay menos de 4 estáticas (modo normal, no algoritmo)
        final remainingSlots = limit - staticFeatured.length;
        if (remainingSlots > 0) {
          // Combinar excludeIds externos con los IDs de canciones estáticas
          final combinedExcludeIds = {
            ...excludeIds,
            ...staticFeatured.map((f) => f.song.id).toSet(),
          };
          
          dynamicRecommendations = await _getDynamicRecommendations(
            count: remainingSlots,
            user: user,
            currentSongId: currentSongId,
            excludeIds: combinedExcludeIds,
          );
          debugPrint('🤖 [IntelligentFeatured] Recomendaciones dinámicas: ${dynamicRecommendations.length}');
        }
      } else {
        debugPrint('✅ [IntelligentFeatured] Suficientes canciones estáticas (${staticFeatured.length}), no agregar dinámicas');
      }

      // 4. Combinar y diversificar
      final combinedResults = _combineAndDiversify(
        staticFeatured: staticFeatured,
        dynamicRecommendations: dynamicRecommendations,
        limit: limit,
      );

      // 5. Cachear resultado
      if (!forceRefresh) {
        final cacheKey = _generateCacheKey(user?.id, currentSongId, limit);
        _cacheRecommendations(cacheKey, combinedResults);
      }

      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [IntelligentFeatured] Completado en ${duration.inMilliseconds}ms');
      debugPrint('🎵 [IntelligentFeatured] Total: ${combinedResults.length} canciones destacadas inteligentes');
      
      return combinedResults;

    } catch (error, stackTrace) {
      AppLogger.error('[IntelligentFeatured] Error en recomendaciones inteligentes', error, stackTrace);
      
      // Fallback: solo canciones destacadas estáticas
      try {
        final fallback = await _getStaticFeaturedSongs();
        debugPrint('🔄 [IntelligentFeatured] Fallback: ${fallback.length} canciones estáticas');
        return fallback.take(limit).toList();
      } catch (fallbackError) {
        AppLogger.error('[IntelligentFeatured] Error en fallback', fallbackError);
        return [];
      }
    }
  }

  /// 📌 OBTENER CANCIONES DESTACADAS ESTÁTICAS
  /// Estas son las canciones marcadas como destacadas por el administrador
  Future<List<FeaturedSong>> _getStaticFeaturedSongs() async {
    try {
      final staticSongs = await _homeService.getFeaturedSongs(
        limit: _maxStaticFeatured,
        forceRefresh: false,
      );
      
      debugPrint('📌 [IntelligentFeatured] Canciones estáticas obtenidas: ${staticSongs.length}');
      return staticSongs;
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo canciones estáticas', error);
      return [];
    }
  }

  /// 🤖 OBTENER RECOMENDACIONES DINÁMICAS
  /// Usa tu algoritmo avanzado para generar recomendaciones personalizadas
  Future<List<FeaturedSong>> _getDynamicRecommendations({
    required int count,
    User? user,
    String? currentSongId,
    Set<String> excludeIds = const {},
  }) async {
    if (count <= 0) return [];

    try {
      List<FeaturedSong> recommendations = [];
      Set<String> usedSongIds = Set.from(excludeIds);
      
      // 🚨 IMPORTANTE: Excluir la canción actual (semilla) de las recomendaciones
      // Esto evita que se repita la última canción al iniciar el algoritmo
      if (currentSongId != null) {
        usedSongIds.add(currentSongId);
      }
      
      // Estrategia 1: Si hay canción actual, usar algoritmo de recomendación
      if (currentSongId != null) {
        final recommendedSongs = await _getRecommendationsBasedOnSong(
          currentSongId: currentSongId,
          user: user,
          count: count,
          excludeIds: usedSongIds, // Incluye la semilla en excludeIds
        );
        
        recommendations.addAll(recommendedSongs);
        usedSongIds.addAll(recommendedSongs.map((r) => r.song.id));
        
        debugPrint('🎯 [IntelligentFeatured] Recomendaciones basadas en canción actual: ${recommendedSongs.length} (semilla excluida)');
      }
      
      // Estrategia 2: Si aún necesitamos más, usar canciones populares diversas
      if (recommendations.length < count) {
        final remaining = count - recommendations.length;
        var popularSongs = await _getPopularDiverseSongs(
          count: remaining,
          excludeIds: usedSongIds,
        );
        
        // 🛡️ FALLBACK DE AGOTAMIENTO: Si no hay canciones nuevas, relajar filtros
        if (popularSongs.isEmpty && excludeIds.isNotEmpty) {
          debugPrint('⚠️ [IntelligentFeatured] REPERTORIO AGOTADO. Aplicando relajación de filtros.');
          
          // Opción 1: Solo excluir la canción que está sonando actualmente
          final relaxedExcludeIds = currentSongId != null ? {currentSongId} : <String>{};
          popularSongs = await _getPopularDiverseSongs(
            count: remaining,
            excludeIds: relaxedExcludeIds,
          );
          
          debugPrint('🔄 [IntelligentFeatured] Relajación nivel 1: ${popularSongs.length} canciones obtenidas (solo excluyendo canción actual)');
          
          // Opción 2: Si aún así está vacío, traer todas las canciones disponibles
          if (popularSongs.isEmpty) {
            debugPrint('⚠️ [IntelligentFeatured] Aún sin resultados. Permitiendo todas las canciones disponibles.');
            popularSongs = await _getPopularDiverseSongs(
              count: remaining,
              excludeIds: <String>{}, // Sin exclusiones
            );
            debugPrint('🔄 [IntelligentFeatured] Relajación nivel 2: ${popularSongs.length} canciones obtenidas (sin exclusiones)');
          }
        }
        
        recommendations.addAll(popularSongs);
        debugPrint('🔥 [IntelligentFeatured] Canciones populares diversas: ${popularSongs.length}');
      }

      return recommendations.take(count).toList();
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo recomendaciones dinámicas', error);
      return [];
    }
  }

  /// 🎯 OBTENER RECOMENDACIONES BASADAS EN CANCIÓN
  /// Usa tu algoritmo avanzado de recomendaciones
  /// 🚨 ESTRATEGIA HÍBRIDA: Primero obtener 3-4 recomendaciones en paralelo, luego cadena
  /// Esto combina velocidad (paralelo inicial) con variedad (cadena posterior)
  Future<List<FeaturedSong>> _getRecommendationsBasedOnSong({
    required String currentSongId,
    User? user,
    required int count,
    Set<String> excludeIds = const {},
  }) async {
    final limit = count > 15 ? 15 : count; // Limitar a 15 para evitar demasiadas llamadas
    
    // 🚨 CRÍTICO: Solo excluir la semilla y los IDs explícitamente excluidos
    // NO excluir canciones estáticas aquí, porque pueden ser válidas como recomendaciones dinámicas
    // La deduplicación final se hará al combinar estáticas + dinámicas
    Set<String> usedIds = <String>{};
    if (excludeIds.isNotEmpty) {
      // Solo agregar la semilla y otros IDs críticos, no todas las estáticas
      usedIds.add(currentSongId); // Siempre excluir la semilla
      // Agregar otros IDs excluidos solo si son relevantes (no estáticas)
      usedIds.addAll(excludeIds.where((id) => id != currentSongId));
    } else {
      usedIds.add(currentSongId); // Al menos excluir la semilla
    }
    
    debugPrint('🚫 [IntelligentFeatured] IDs excluidos en Fase 1: ${usedIds.length} (semilla + otros)');
    if (usedIds.length > 1) {
      debugPrint('   Excluidos: ${usedIds.map((id) => id.substring(0, 8)).join(", ")}');
    }
    
    final List<FeaturedSong> recommendations = [];
    
    // 🚀 FASE 1 OPTIMIZADA: Obtener recomendaciones usando nuevo endpoint de batch
    // El backend maneja internamente el batching y garantiza variedad
    final initialCount = limit > 4 ? 4 : limit;
    
    // 🚀 SPOTIFY-LEVEL: Verificar cache de semillas primero
    final cachedSeeds = _cacheService.getCachedSeeds(currentSongId);
    if (cachedSeeds != null && cachedSeeds.length >= initialCount) {
      debugPrint('⚡ [IntelligentFeatured] Cache hit de semillas! Usando ${cachedSeeds.length} semillas cacheadas');
      // Usar semillas cacheadas como base
      for (final seed in cachedSeeds.take(initialCount)) {
        if (!usedIds.contains(seed.id) && seed.isValidForPlayback) {
          recommendations.add(FeaturedSong(
            song: seed,
            featuredReason: 'Recomendada por IA • ${_getRecommendationReason(recommendations.length)}',
            rank: recommendations.length + 1,
          ));
          usedIds.add(seed.id);
        }
      }
      
      // Si tenemos suficientes recomendaciones del cache, saltar Fase 1
      if (recommendations.length >= initialCount) {
        debugPrint('✅ [IntelligentFeatured] Fase 1 completada desde cache: ${recommendations.length} canciones');
      }
    }
    
    final needsMoreSeeds = recommendations.length < initialCount;
    List<Song> initialResults = [];
    
    if (needsMoreSeeds) {
      final seedsToFetch = initialCount - recommendations.length;
      debugPrint('🚀 [IntelligentFeatured] Fase 1: solicitando $seedsToFetch recomendaciones usando batch endpoint para canción ${currentSongId.substring(0, 8)}...');
      debugPrint('🚀 [IntelligentFeatured] ⚠️ VERIFICACIÓN: Este es el NUEVO código usando generatePlaylistBatch()');
      
      try {
        // 🚀 NUEVO: Usar endpoint de batch en lugar de múltiples llamadas paralelas
        // El backend maneja internamente el batching y garantiza variedad
        debugPrint('🚀 [IntelligentFeatured] Llamando a generatePlaylistBatch() con seed=$currentSongId, count=$seedsToFetch');
        
        final batchSongs = await _recommendationService.generatePlaylistBatch(
          seedSongId: currentSongId,
          count: seedsToFetch,
          user: user,
          genres: null, // El backend detectará los géneros automáticamente
          excludeIds: usedIds.toList(),
          useCache: false, // Desactivar cache local para forzar variedad
        );
        
        debugPrint('🚀 [IntelligentFeatured] generatePlaylistBatch() retornó ${batchSongs.length} canciones');
        
        // Filtrar canciones válidas y no duplicadas
        initialResults = batchSongs
            .where((song) => !usedIds.contains(song.id) && song.isValidForPlayback)
            .toList();
        
        debugPrint('🚀 [IntelligentFeatured] Después de filtrar: ${initialResults.length} canciones válidas');
        
        // 🚀 SPOTIFY-LEVEL: Cachear semillas obtenidas
        if (initialResults.isNotEmpty) {
          _cacheService.cacheSeeds(currentSongId, initialResults);
        }
        
        debugPrint('✅ [IntelligentFeatured] Fase 1: ${initialResults.length}/$seedsToFetch recomendaciones recibidas del batch');
      } catch (error, stackTrace) {
        debugPrint('❌ [IntelligentFeatured] Error en Fase 1 batch: $error');
        debugPrint('   Tipo de error: ${error.runtimeType}');
        debugPrint('   Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
        initialResults = [];
      }
    }
    
    // 🚨 PROCESAMIENTO CRÍTICO: Procesar resultados de la Fase 1
    debugPrint('📊 [IntelligentFeatured] Fase 1: ${initialResults.length} respuestas recibidas');
    
    // Procesar resultados iniciales y agregar a recomendaciones
    final Set<String> uniqueSongIds = {}; // Para detectar duplicados
    
    for (int i = 0; i < initialResults.length; i++) {
      final song = initialResults[i];
      
      // 🚨 CRÍTICO: Verificar si es duplicado ANTES de agregar
      if (usedIds.contains(song.id)) {
        final reason = song.id == currentSongId 
            ? 'Es la semilla' 
            : 'Está en excludeIds (probablemente estática)';
        debugPrint('⚠️ [IntelligentFeatured] Fase 1 respuesta ${i + 1}: DUPLICADO - ${song.title} (ID: ${song.id.substring(0, 8)}...) - $reason');
        continue;
      }
      
      // Agregar a recomendaciones
      recommendations.add(FeaturedSong(
        song: song,
        featuredReason: 'Recomendada por IA • ${_getRecommendationReason(recommendations.length)}',
        rank: recommendations.length + 1,
      ));
      usedIds.add(song.id);
      uniqueSongIds.add(song.id);
      
      debugPrint('✅ [IntelligentFeatured] Fase 1 respuesta ${i + 1}: ${song.title} (ID: ${song.id.substring(0, 8)}...)');
    }
    
    debugPrint('📊 [IntelligentFeatured] Fase 1 resumen: ${initialResults.length} recibidas, ${uniqueSongIds.length} únicas agregadas');
    
    // 🚨 VERIFICACIÓN CRÍTICA: Si no tenemos suficientes semillas únicas, usar fallback
    if (uniqueSongIds.length < 2 && initialCount >= 2) {
      debugPrint('⚠️ [IntelligentFeatured] ADVERTENCIA: Solo ${uniqueSongIds.length} semilla(s) única(s) obtenida(s).');
      debugPrint('🔍 [IntelligentFeatured] IDs únicos obtenidos: ${uniqueSongIds.map((id) => id.substring(0, 8)).join(", ")}');
    }
    
    // 🚨 FASE 2: Continuar en CADENA usando las recomendaciones iniciales como semillas
    // ⚡ OPTIMIZADO: Llamadas en LOTES PARALELOS para reducir latencia de 60s a ~24s
    if (recommendations.length < count) {
      // 🚨 SEMILLAS VARIADAS: Extraer TODOS los IDs únicos de las recomendaciones de la Fase 1
      // CRÍTICO: Usar uniqueSongIds (que incluye TODAS las canciones obtenidas) no solo recommendations
      final seedsFromRecommendations = recommendations.map((r) => r.song.id).toList();
      
      // 🚨 CRÍTICO: También incluir las canciones de initialResults que pueden no estar en recommendations
      // (por ejemplo, si fueron duplicadas pero aún son válidas como semillas)
      final allObtainedIds = <String>{};
      allObtainedIds.addAll(seedsFromRecommendations);
      
      // Agregar IDs de todas las respuestas válidas (incluso si fueron duplicadas)
      for (final song in initialResults) {
        allObtainedIds.add(song.id);
      }
      
      // Convertir a lista y eliminar duplicados
      final seeds = allObtainedIds.toList();
      
      // 🚨 VERIFICACIÓN: Si aún no tenemos suficientes semillas, usar la canción original
      if (seeds.isEmpty) {
        debugPrint('⚠️ [IntelligentFeatured] No hay semillas de la Fase 1, usando canción original como fallback');
        seeds.add(currentSongId);
      } else if (seeds.length < initialCount && seeds.length < 4) {
        debugPrint('⚠️ [IntelligentFeatured] Solo ${seeds.length} semilla(s) única(s) obtenida(s) de $initialCount llamadas. Posible problema de duplicados en el backend.');
      }
      
      final remainingCount = (limit - recommendations.length).clamp(0, limit);
      
      // 🚨 LOG DETALLADO: Mostrar todas las semillas
      debugPrint('🔗 [IntelligentFeatured] Fase 2 iniciada con ${seeds.length} semilla(s) única(s):');
      for (int i = 0; i < seeds.length && i < 5; i++) {
        final seedId = seeds[i];
        final isOriginal = seedId == currentSongId;
        debugPrint('   Semilla ${i + 1}: ${seedId.substring(0, 8)}...${isOriginal ? " (ORIGINAL - fallback)" : ""}');
      }
      if (seeds.length > 5) {
        debugPrint('   ... y ${seeds.length - 5} más');
      }
      debugPrint('   Faltan $remainingCount canciones para completar el límite de $limit');
      
      // 🚀 FASE 2 OPTIMIZADA: Usar endpoint de batch para obtener múltiples recomendaciones
      // El backend ahora maneja la detección de loops y ajuste dinámico del scoring
      // El frontend mantiene límites suaves como respaldo de seguridad
      int seedIndex = 0;
      int totalAttempts = 0;
      int consecutiveFailures = 0; // Contador de fallos consecutivos (respaldo)
      const int maxConsecutiveFailures = 1; // Cortar en el primer fallo
      const int absoluteMaxAttempts = 2; // Más bajo aún para máxima velocidad
      final calculatedMaxAttempts = remainingCount; // pedir lo que falta
      final maxAttempts = calculatedMaxAttempts > absoluteMaxAttempts ? absoluteMaxAttempts : calculatedMaxAttempts;
      final Map<String, int> seedAttempts = {}; // Limitar intentos por semilla
      
      while (recommendations.length < count && totalAttempts < maxAttempts && consecutiveFailures < maxConsecutiveFailures) {
        // 🚨 CRÍTICO: Seleccionar semilla de forma circular de la lista de semillas
        final seedId = seeds[seedIndex % seeds.length];
        final seedIndexInList = seedIndex % seeds.length;
        
        // Limitar intentos por semilla a 1 (cortar rápido)
        seedAttempts[seedId] = (seedAttempts[seedId] ?? 0);
        if (seedAttempts[seedId]! >= 1) {
          seedIndex++;
          continue;
        }
        
        // Calcular cuántas recomendaciones necesitamos (pedir de a 1 para minimizar duplicados)
        final needed = 1;
        
        debugPrint('🚀 [IntelligentFeatured] Fase 2: solicitando $needed recomendaciones usando batch endpoint con semilla ${seedId.substring(0, 8)}... (índice $seedIndexInList de ${seeds.length}, intento ${totalAttempts + 1}/$maxAttempts)');
        
        try {
          seedAttempts[seedId] = seedAttempts[seedId]! + 1;
          // 🚀 NUEVO: Usar endpoint de batch en lugar de múltiples llamadas individuales
          final batchSongs = await _recommendationService.generatePlaylistBatch(
            seedSongId: seedId, // ✅ USAR SEMILLA VARIADA (no currentSongId original)
            count: needed,
            user: user,
            genres: null, // El backend detectará los géneros automáticamente
            excludeIds: usedIds.toList(),
            useCache: false, // 🚨 DESACTIVAR CACHE para forzar nuevas recomendaciones
          );
          
          debugPrint('✅ [IntelligentFeatured] Fase 2 batch: ${batchSongs.length}/$needed recomendaciones recibidas');
          
          // Procesar resultados del batch
          int addedInBatch = 0;
          int duplicatesInBatch = 0;
          
          for (final recommendedSong in batchSongs) {
            if (recommendations.length >= count) break;
            
            if (!usedIds.contains(recommendedSong.id) && recommendedSong.isValidForPlayback) {
              final rank = recommendations.length + 1;
              recommendations.add(FeaturedSong(
                song: recommendedSong,
                featuredReason: 'Recomendada por IA • ${_getRecommendationReason(rank - 1)}',
                rank: rank,
              ));
              usedIds.add(recommendedSong.id);
              addedInBatch++;
              
              // 🚨 AGREGAR NUEVA SEMILLA: Cada nueva recomendación se convierte en semilla
              if (!seeds.contains(recommendedSong.id)) {
                seeds.add(recommendedSong.id);
                debugPrint('✅ [IntelligentFeatured] Nueva semilla agregada: ${recommendedSong.title} (${recommendedSong.id.substring(0, 8)}...)');
              }
            } else {
              duplicatesInBatch++;
              debugPrint('⚠️ [IntelligentFeatured] Recomendación duplicada/inválida ignorada: ${recommendedSong.title} (ID: ${recommendedSong.id.substring(0, 8)}...)');
            }
          }
          
          debugPrint('📊 [IntelligentFeatured] Fase 2 batch procesado: $addedInBatch agregadas, $duplicatesInBatch duplicadas/inválidas');
          
          // Si no obtuvimos ninguna recomendación nueva, fallback inmediato y cortar Fase 2
          if (addedInBatch == 0) {
            consecutiveFailures++;
            seedIndex++;
            debugPrint('⚠️ [IntelligentFeatured] Fase 2: Sin nuevas con esta semilla. Corte inmediato a populares.');
            final fallbackNeeded = (count - recommendations.length).clamp(2, 4);
            final fallback = await _getPopularDiverseSongs(
              count: fallbackNeeded,
              excludeIds: usedIds,
            );
            if (fallback.isNotEmpty) {
              int addedFallback = 0;
              for (final fs in fallback) {
                if (recommendations.length >= count) break;
                final song = fs.song;
                if (usedIds.contains(song.id) || !song.isValidForPlayback) continue;
                recommendations.add(FeaturedSong(
                  song: song,
                  featuredReason: fs.featuredReason ?? 'Trending • ${song.totalStreams} reproducciones',
                  rank: recommendations.length + 1,
                ));
                usedIds.add(song.id);
                addedFallback++;
              }
              debugPrint('✅ [IntelligentFeatured] Fallback populares agregó $addedFallback canciones (fallback inmediato).');
            } else {
              debugPrint('⚠️ [IntelligentFeatured] Fallback populares no devolvió canciones (fallback inmediato).');
            }
            break;
          } else {
            // Si obtuvimos recomendaciones, resetear contador de fallos
            consecutiveFailures = 0;
            seedIndex++;
          }
          
          totalAttempts++;
          
          // Si ya tenemos suficientes recomendaciones, salir
            if (recommendations.length >= count) break;
        } catch (error, stackTrace) {
          consecutiveFailures++;
          debugPrint('❌ [IntelligentFeatured] Error en Fase 2 batch (semilla: ${seedId.substring(0, 8)}...): $error');
          debugPrint('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
          // Avanzar a la siguiente semilla en caso de error
          seedIndex++;
          totalAttempts++;
        }
      }
      
      if (totalAttempts >= maxAttempts) {
        debugPrint('⚠️ [IntelligentFeatured] Máximo de intentos alcanzado en Fase 2 ($maxAttempts intentos) - Límite de seguridad del frontend');
      }
      
      if (consecutiveFailures >= maxConsecutiveFailures) {
        debugPrint('⚠️ [IntelligentFeatured] Fase 2: Demasiados fallos consecutivos ($consecutiveFailures/$maxConsecutiveFailures) - Límite de seguridad del frontend. El backend debería haber manejado esto automáticamente.');
      }
      
      debugPrint('✅ [IntelligentFeatured] Fase 2 completada: ${recommendations.length} recomendaciones totales (${recommendations.length - initialCount} de la Fase 2)');
    }
    
    debugPrint('✅ [IntelligentFeatured] Total recomendaciones obtenidas: ${recommendations.length} de $count solicitadas (híbrido: $initialCount paralelo + cadena)');
    return recommendations;
  }

  /// 🔗 GENERAR RECOMENDACIONES FASE 2 USANDO SEMILLAS DIRECTAMENTE
  /// Este método usa las semillas de la Fase 1 para generar más recomendaciones
  /// sin duplicar llamadas a getIntelligentFeaturedSongs
  /// 
  /// [seeds]: Lista de IDs de canciones a usar como semillas
  /// [count]: Número de recomendaciones a obtener
  /// [excludeIds]: IDs de canciones a excluir (ya en cola, historial, etc.)
  /// [user]: Usuario opcional para personalización
  Future<List<Song>> generatePhase2RecommendationsFromSeeds({
    required List<String> seeds,
    required int count,
    required Set<String> excludeIds,
    User? user,
  }) async {
    if (seeds.isEmpty) {
      debugPrint('⚠️ [IntelligentFeatured] Fase 2: No hay semillas disponibles');
      return [];
    }

    debugPrint('🚀 [IntelligentFeatured] Fase 2: Generando $count recomendaciones usando ${seeds.length} semillas con batch endpoint');
    
    final List<Song> recommendations = [];
    final Set<String> usedIds = Set.from(excludeIds);
    
    // 🚀 NUEVA ESTRATEGIA: Usar endpoint de batch para cada semilla
    // Distribución: 40% primera, 30% segunda, 20% tercera, 10% cuarta (si hay 4)
    final seedWeights = _calculateSeedWeights(seeds.length);
    final callsPerSeed = _distributeCallsByWeights(seedWeights, count);
    
    // 🚀 Crear llamadas batch en lugar de llamadas individuales
    final List<Future<List<Song>>> batchFutures = [];
    
    for (int seedIdx = 0; seedIdx < seeds.length; seedIdx++) {
      final batchSizeForThisSeed = callsPerSeed[seedIdx];
      if (batchSizeForThisSeed <= 0) continue;
      
      final seedId = seeds[seedIdx];
      final needed = (count - recommendations.length).clamp(1, batchSizeForThisSeed.clamp(1, 4)); // Máximo 4 por batch
      
      debugPrint('🚀 [IntelligentFeatured] Fase 2 batch ${seedIdx + 1}/${seeds.length}: solicitando $needed recomendaciones con semilla ${seedId.substring(0, 8)}... (peso: ${(seedWeights[seedIdx] * 100).toStringAsFixed(0)}%)');
      
      batchFutures.add(
        _recommendationService.generatePlaylistBatch(
          seedSongId: seedId,
          count: needed,
          user: user,
          genres: null,
          excludeIds: usedIds.toList(),
          useCache: false, // No usar cache para variedad
        ).catchError((error) {
          debugPrint('❌ [IntelligentFeatured] Error en Fase 2 batch (semilla: ${seedId.substring(0, 8)}...): $error');
          return <Song>[]; // Retornar lista vacía en caso de error
        })
      );
    }
    
    // Ejecutar todas las llamadas batch en paralelo
    debugPrint('⚡ [IntelligentFeatured] Fase 2: ejecutando ${batchFutures.length} llamadas batch en paralelo...');
    final batchResults = await Future.wait(batchFutures);
    
    // Procesar resultados de todos los batches
    for (final batchSongs in batchResults) {
      for (final song in batchSongs) {
        if (!usedIds.contains(song.id) && song.isValidForPlayback) {
          recommendations.add(song);
          usedIds.add(song.id);
          
          if (recommendations.length >= count) {
            break;
          }
        }
      }
      
      if (recommendations.length >= count) {
        break;
      }
    }
    
    debugPrint('✅ [IntelligentFeatured] Fase 2: ${recommendations.length} recomendaciones obtenidas de ${batchResults.length} batches');
    return recommendations;
  }

  /// 🎲 CALCULAR PESOS PARA DISTRIBUCIÓN BALANCEADA DE SEMILLAS
  /// Retorna una lista de pesos (0.0 a 1.0) para cada semilla
  List<double> _calculateSeedWeights(int seedCount) {
    if (seedCount == 1) return [1.0];
    if (seedCount == 2) return [0.6, 0.4];
    if (seedCount == 3) return [0.5, 0.3, 0.2];
    // 4 o más: 40%, 30%, 20%, 10% (y el resto distribuido)
    final weights = <double>[];
    final percentages = [0.4, 0.3, 0.2, 0.1];
    for (int i = 0; i < seedCount; i++) {
      if (i < percentages.length) {
        weights.add(percentages[i]);
      } else {
        // Distribuir el resto equitativamente
        final remaining = 1.0 - weights.fold(0.0, (a, b) => a + b);
        weights.add(remaining / (seedCount - i));
      }
    }
    return weights;
  }

  /// 📊 DISTRIBUIR LLAMADAS SEGÚN PESOS
  /// Retorna una lista con el número de llamadas a hacer por cada semilla
  /// Ejemplo: [4, 3, 2, 1] significa 4 llamadas con semilla 1, 3 con semilla 2, etc.
  List<int> _distributeCallsByWeights(List<double> weights, int totalCalls) {
    final callsPerSeed = List<int>.filled(weights.length, 0);
    
    // Calcular llamadas por semilla según pesos
    double remainingCalls = totalCalls.toDouble();
    for (int i = 0; i < weights.length && remainingCalls > 0; i++) {
      final callsForThisSeed = (weights[i] * totalCalls).round();
      callsPerSeed[i] = callsForThisSeed;
      remainingCalls -= callsForThisSeed;
    }
    
    // Distribuir llamadas restantes (por redondeo) a las semillas con más peso
    if (remainingCalls > 0) {
      for (int i = 0; i < weights.length && remainingCalls > 0; i++) {
        callsPerSeed[i]++;
        remainingCalls--;
      }
    }
    
    return callsPerSeed;
  }

  /// 🔥 OBTENER CANCIONES POPULARES DIVERSAS
  /// Fallback para llenar espacios restantes
  Future<List<FeaturedSong>> _getPopularDiverseSongs({
    required int count,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final popularSongs = await _homeService.getPopularSongs(limit: count * 2);
      
      final diverseSongs = popularSongs
          .where((song) => !excludeIds.contains(song.id))
          .take(count)
              .map((song) => FeaturedSong(
                song: song,
                featuredReason: 'Trending • ${song.totalStreams} reproducciones',
                rank: 1,
              ))
          .toList();
      
      return diverseSongs;
    } catch (error) {
      AppLogger.error('[IntelligentFeatured] Error obteniendo canciones populares', error);
      return [];
    }
  }

  /// 🎭 COMBINAR Y DIVERSIFICAR RESULTADOS
  /// Mezcla canciones estáticas y dinámicas para máxima variedad
  /// Si solo hay estáticas suficientes (4+), solo devuelve esas sin agregar dinámicas
  List<FeaturedSong> _combineAndDiversify({
    required List<FeaturedSong> staticFeatured,
    required List<FeaturedSong> dynamicRecommendations,
    required int limit,
  }) {
    // Si hay suficientes canciones estáticas (4 o más), solo devolver esas
    if (staticFeatured.length >= 4 && dynamicRecommendations.isEmpty) {
      debugPrint('✅ [IntelligentFeatured] Solo estáticas suficientes: ${staticFeatured.length} canciones');
      return staticFeatured.take(limit).toList();
    }
    
    // Si no hay dinámicas, solo devolver las estáticas disponibles (sin completar hasta el límite)
    if (dynamicRecommendations.isEmpty) {
      debugPrint('📌 [IntelligentFeatured] Solo estáticas disponibles: ${staticFeatured.length} canciones');
      return staticFeatured;
    }
    
    // Si hay ambas, combinar con estrategia de intercalado
    final List<FeaturedSong> result = [];
    int staticIndex = 0;
    int dynamicIndex = 0;
    bool useStatic = true;
    
    while (result.length < limit && 
           (staticIndex < staticFeatured.length || dynamicIndex < dynamicRecommendations.length)) {
      
      if (useStatic && staticIndex < staticFeatured.length) {
        result.add(staticFeatured[staticIndex]);
        staticIndex++;
      } else if (dynamicIndex < dynamicRecommendations.length) {
        result.add(dynamicRecommendations[dynamicIndex]);
        dynamicIndex++;
      } else if (staticIndex < staticFeatured.length) {
        result.add(staticFeatured[staticIndex]);
        staticIndex++;
      }
      
      useStatic = !useStatic; // Alternar entre estáticas y dinámicas
    }
    
    debugPrint('🎭 [IntelligentFeatured] Combinación final: ${result.length} canciones');
    debugPrint('📌 [IntelligentFeatured] Estáticas usadas: $staticIndex/${staticFeatured.length}');
    debugPrint('🤖 [IntelligentFeatured] Dinámicas usadas: $dynamicIndex/${dynamicRecommendations.length}');
    
    return result;
  }

  /// 🏷️ OBTENER RAZÓN DE RECOMENDACIÓN
  String _getRecommendationReason(int index) {
    final reasons = [
      'Perfecta para ti',
      'Género similar',
      'Artista relacionado',
      'Trending ahora',
      'Descubrimiento',
      'Basada en tu historial',
      'Algoritmo avanzado',
      'Recomendación especial',
    ];
    
    return reasons[index % reasons.length];
  }

  /// ⚡ GESTIÓN DE CACHE
  String _generateCacheKey(String? userId, String? currentSongId, int limit) {
    return '${userId ?? 'anon'}-${currentSongId ?? 'none'}-$limit';
  }

  List<FeaturedSong>? _getCachedRecommendations(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cached.timestamp > _cacheTtlMs) {
      _cache.remove(key);
      return null;
    }
    
    return cached.recommendations;
  }

  void _cacheRecommendations(String key, List<FeaturedSong> recommendations) {
    _cache[key] = CachedFeaturedRecommendations(
      recommendations: recommendations,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    // Limpiar cache antiguo (LRU simple)
    if (_cache.length > 50) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  /// 🧹 LIMPIAR CACHE
  void clearCache() {
    _cache.clear();
    debugPrint('🧹 [IntelligentFeatured] Cache limpiado');
  }

  /// 📊 OBTENER MÉTRICAS
  Map<String, dynamic> getMetrics() {
    return {
      'cacheSize': _cache.length,
      'maxStaticFeatured': _maxStaticFeatured,
      'maxDynamicRecommendations': _maxDynamicRecommendations,
      'totalFeaturedSongs': _totalFeaturedSongs,
      'cacheTtlMinutes': _cacheTtlMs / (60 * 1000),
    };
  }
}

/// 💾 MODELO PARA CACHE DE RECOMENDACIONES
class CachedFeaturedRecommendations {
  final List<FeaturedSong> recommendations;
  final int timestamp;

  CachedFeaturedRecommendations({
    required this.recommendations,
    required this.timestamp,
  });
}
