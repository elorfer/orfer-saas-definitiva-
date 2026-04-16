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
      // ✅ OPTIMIZACIÓN Adrenalina: Si limit es 1, pedir solo 1 canción estática
      final staticFeatured = await _getStaticFeaturedSongs(limit: limit == 1 ? 1 : _maxStaticFeatured);
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
      } else if (staticFeatured.length < limit && staticFeatured.length < 4) {
        // Solo agregar recomendaciones dinámicas si no llegamos al límite solicitado
        // y hay pocas canciones estáticas para mostrar (modo normal)
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
          debugPrint('🤖 [IntelligentFeatured] Recomendaciones dinámicas para rellenar: ${dynamicRecommendations.length}');
        }
      } else {
        debugPrint('✅ [IntelligentFeatured] Suficientes canciones (${staticFeatured.length}) para cubrir el límite de $limit');
      }

      // 4. Combinar y diversificar
      // 🚀 ANR SHIELD: Ceder el hilo antes de combinaciones pesadas
      await Future.delayed(Duration.zero);
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
  Future<List<FeaturedSong>> _getStaticFeaturedSongs({int? limit}) async {
    try {
      final staticSongs = await _homeService.getFeaturedSongs(
        limit: (limit ?? _maxStaticFeatured) * 2, // Fetch double to have pool for shuffling
        forceRefresh: false,
      );
      
      // SHUFFLE to ensure variety when starting app
      staticSongs.shuffle();
      
      final result = staticSongs.take(limit ?? _maxStaticFeatured).toList();
      
      debugPrint('📌 [IntelligentFeatured] Canciones estáticas obtenidas: ${result.length}');
      return result;
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
    
    // 🚀 FASE 1 OPTIMIZADA: Obtener recomendaciones
    // Estrategia: "Buffer First" -> "Network Batch" -> "Refill Buffer"
    
    // 1. Intentar obtener del Buffer Local (RAM)
    final bufferSongs = _cacheService.getFromBuffer(limit);
    if (bufferSongs.isNotEmpty) {
       for (final song in bufferSongs) {
          if (!usedIds.contains(song.id) && song.isValidForPlayback) {
             recommendations.add(FeaturedSong(
               song: song,
               featuredReason: 'Recomendada por IA • ${_getRecommendationReason(recommendations.length)}',
               rank: recommendations.length + 1,
             ));
             usedIds.add(song.id);
          }
       }
       debugPrint('✅ [IntelligentFeatured] 📦 Buffer Hit: ${recommendations.length} canciones recuperadas sin red');
    }

    final initialCount = limit > 4 ? 4 : limit;
    // Si el buffer llenó todo, genial. Si no, necesitamos buscar más.
    final needsMore = recommendations.length < initialCount;
    List<Song> initialResults = [];
    
    if (needsMore) {
      // Calcular cuánto falta
      final missingCount = initialCount - recommendations.length;
      
      // 🚀 BATCH FETCHING: Pedir siempre un lote grande (ej. 20) para llenar el buffer
      // Si pedimos solo 'missingCount' (ej. 3), desperdiciamos la oportunidad de cachear
      const int kBatchSize = 20; 
      final fetchCount = missingCount < kBatchSize ? kBatchSize : missingCount;
      
      debugPrint('🚀 [IntelligentFeatured] Fase 1: solicitando $fetchCount canciones (Buffer Refill Strategy) para semilla ${currentSongId.substring(0, 8)}...');
      
      try {
        var batchResult = await _recommendationService.generatePlaylistBatch(
          seedSongId: currentSongId,
          count: fetchCount, // Pedir lote grande
          user: user,
          genres: null,
          excludeIds: usedIds.toList(),
          useCache: false, // Forzar fresco
        );
        
        // 🚀 SAFETY NET: Estrategia de Relajación Multinivel
        if (batchResult.songs.isEmpty) {
           debugPrint('⚠️ [IntelligentFeatured] 0 resultados en Fase 1. Iniciando Relajación Multinivel...');
           
           // NIVEL 1: Reducir exclusiones a la mínima expresión (últimas 5 + actual)
           final minimalExclusions = usedIds.toList();
           if (minimalExclusions.length > 5) {
             minimalExclusions.removeRange(0, minimalExclusions.length - 5);
           }
           if (!minimalExclusions.contains(currentSongId)) {
             minimalExclusions.add(currentSongId);
           }
           
           debugPrint('🔄 [IntelligentFeatured] Relajación Nivel 1: Exclusiones reducidas a ${minimalExclusions.length}');
           batchResult = await _recommendationService.generatePlaylistBatch(
              seedSongId: currentSongId,
              count: fetchCount,
              user: user,
              genres: null,
              excludeIds: minimalExclusions,
              useCache: false,
           );

            // ✅ CRÍTICO: Si obtuvimos resultados con relajación, actualizar usedIds
            // para que el filtro final (allFetched) no los descarte
            if (batchResult.songs.isNotEmpty) {
               usedIds = minimalExclusions.toSet();
               debugPrint('✅ [IntelligentFeatured] Relajación Nivel 1 exitosa. usedIds actualizado para permitir backup.');
            }

           // NIVEL 2: Catálogo Agotado. Ignorar exclusiones y buscar populares (Filtro Global)
           if (batchResult.songs.isEmpty) {
              debugPrint('🚨 [IntelligentFeatured] 0 resultados en Nivel 1. Nivel 2: Ignorando exclusiones por agotamiento de catálogo.');
              batchResult = await _recommendationService.generatePlaylistBatch(
                seedSongId: currentSongId,
                count: fetchCount,
                user: user,
                genres: null,
                excludeIds: [currentSongId], // Solo excluir la actual
                useCache: false,
              );

               if (batchResult.songs.isNotEmpty) {
                 usedIds = {currentSongId}; // Relajar filtro final al máximo
                 debugPrint('✅ [IntelligentFeatured] Relajación Nivel 2 exitosa. usedIds reseteado a solo semilla.');
               }
              
              // NIVEL 3: Emergencia Total. Cargar canciones populares estáticas (Failsafe)
              if (batchResult.songs.isEmpty) {
                 debugPrint('🆘 [IntelligentFeatured] EMERGENCIA: 0 resultados tras relajar todo. Buscando canciones populares globales.');
                 final popularSongs = await _homeService.getPopularSongs(limit: fetchCount);
                 if (popularSongs.isNotEmpty) {
                    batchResult = BatchResult(songs: popularSongs);
                    usedIds = {}; // En emergencia total, aceptar TODO (incluso duplicados si es necesario para que no muera la música)
                    debugPrint('✅ [IntelligentFeatured] Recuperación vía popularSongs: ${batchResult.songs.length} canciones. Filtro desactivado.');
                 }
              }
           }
           debugPrint('✅ [IntelligentFeatured] Fallback completado: ${batchResult.songs.length} canciones recuperadas');
        }

        // Separar lo que necesitamos de lo que guardaremos
        final allFetched = batchResult.songs
            .where((song) => !usedIds.contains(song.id) && song.isValidForPlayback)
            .toList();
            
        // Tomar lo que necesitamos
        initialResults = allFetched.take(missingCount).toList();
        
        // El resto al buffer
        final remainingForBuffer = allFetched.skip(missingCount).toList();
        if (remainingForBuffer.isNotEmpty) {
           _cacheService.addToBuffer(remainingForBuffer);
           debugPrint('📥 [IntelligentFeatured] Guardando ${remainingForBuffer.length} canciones sobrantes en Buffer local');
        }
        
        // Cachear semillas (para otros usos)
        if (initialResults.isNotEmpty) {
          _cacheService.cacheSeeds(currentSongId, initialResults);
        }
        
      } catch (error) {
        debugPrint('❌ [IntelligentFeatured] Error en Fase 1 batch: $error');
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
    if (recommendations.length < count) {
      final seedsFromRecommendations = recommendations.map((r) => r.song.id).toList();
      final allObtainedIds = <String>{};
      allObtainedIds.addAll(seedsFromRecommendations);
      for (final song in initialResults) {
        allObtainedIds.add(song.id);
      }
      final seeds = allObtainedIds.toList();
      
      if (seeds.isEmpty) {
        debugPrint('⚠️ [IntelligentFeatured] No hay semillas de la Fase 1, usando canción original como fallback');
        seeds.add(currentSongId);
      }

      final remainingCount = (limit - recommendations.length).clamp(0, limit);
      int seedIndex = 0;
      int totalAttempts = 0;
      int consecutiveFailures = 0;
      const int maxConsecutiveFailures = 1;
      const int absoluteMaxAttempts = 2;
      final maxAttempts = remainingCount > absoluteMaxAttempts ? absoluteMaxAttempts : remainingCount;
      final Map<String, int> seedAttempts = {};
      
      // 🚀 BATCH FASE 2: Evitar waterfall secuencial usando el método de batch paralelo
      if (seeds.isNotEmpty) {
        final missingCount = count - recommendations.length;
        final phase2Songs = await generatePhase2RecommendationsFromSeeds(
          seeds: seeds,
          count: missingCount,
          excludeIds: usedIds,
          user: user,
        );
        
        for (final song in phase2Songs) {
          if (recommendations.length < count && !usedIds.contains(song.id)) {
            recommendations.add(FeaturedSong(
              song: song,
              featuredReason: 'Recomendada por IA • ${_getRecommendationReason(recommendations.length)}',
              rank: recommendations.length + 1,
            ));
            usedIds.add(song.id);
          }
        }
      }
    }
    
    debugPrint('✅ [IntelligentFeatured] Total recomendaciones obtenidas: ${recommendations.length} de $count');
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
    final List<Future<BatchResult>> batchFutures = [];
    
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
          return const BatchResult(songs: []); // Retornar BatchResult vacío en caso de error
        })
      );
    }
    
    // Ejecutar todas las llamadas batch en paralelo
    debugPrint('⚡ [IntelligentFeatured] Fase 2: ejecutando ${batchFutures.length} llamadas batch en paralelo...');
    final batchResults = await Future.wait(batchFutures);

    // Procesar resultados de todos los batches
    for (final batchResult in batchResults) {
      for (final song in batchResult.songs) {
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
      final popularSongs = await _homeService.getPopularSongs(limit: count * 4); // Fetch more for variety
      
      // SHUFFLE popular songs to ensure different sequence every time
      popularSongs.shuffle();
      
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

    // 🎲 SI NO HAY SEMILLA INICIAL (Radio Infinita desde cero), MEZCLAR TODO
    // Esto asegura que la sugerencia inicial sea 100% diferente cada vez que abre la app
    if (dynamicRecommendations.isEmpty || staticFeatured.length >= 4) {
      result.shuffle();
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
    // 🎲 Si no hay semilla, NO CACHEAR para asegurar un arranque fresco siempre
    if (currentSongId == null) {
      return 'NO_CACHE_${DateTime.now().millisecondsSinceEpoch}';
    }
    // Para recomendaciones basadas en canción, cache con TTL de 3 mins
    final timeWindow = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    return '${userId ?? 'anon'}-$currentSongId-$limit-$timeWindow';
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
