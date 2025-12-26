import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Song } from '../../common/entities/song.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { Genre } from '../../common/entities/genre.entity';
import { SongStatus } from '../../common/entities/song.entity';
import { Not } from 'typeorm';

/**
 * 🎛️ RESULTADO DEL BATCH CON METADATA
 * Incluye información sobre cambios de modo Vibe Selector
 */
export interface BatchResult {
  songs: Song[];
  vibeChangedToMix: boolean; // true si se agotó el género y se cambió a MIX
  originalGenre?: string; // Género original que se agotó
}

/**
 * 🎵 SISTEMA DE RECOMENDACIONES ESTILO SPOTIFY
 * 
 * Algoritmos implementados:
 * 1. Content-Based Filtering (géneros, artistas, características)
 * 2. Collaborative Filtering básico (historial de usuarios)
 * 3. Popularity-Based (trending songs)
 * 4. Hybrid Approach (combinación de múltiples algoritmos)
 *
 * TODO Backend: cuando generatePlaylistBatch devuelva 0 nuevas (todas duplicadas),
 * activar modo diversidad en el backend:
 *  - Relajar filtros y mezclar populares/novelty para retornar al menos 3-5 nuevas.
 *  - No devolver la semilla ni seeds previas si ya vienen en excludeIds.
 */
@Injectable()
export class RecommendationService {
  private readonly logger = new Logger(RecommendationService.name);

  // Cache en memoria para recomendaciones (en producción usar Redis)
  private readonly recommendationCache = new Map<string, CachedRecommendation>();
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutos (optimizado para reducir costos AWS)

  // Historial de canciones recientes por usuario para evitar repeticiones
  private readonly recentSongsHistory = new Map<string, RecentSongsHistory>();
  private readonly HISTORY_SIZE = 10; // Recordar últimas 10 canciones (aumentado para reducir repetitividad)
  private readonly HISTORY_TTL = 30 * 60 * 1000; // 30 minutos

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
    @InjectRepository(Genre)
    private readonly genreRepository: Repository<Genre>,
  ) {
    // Limpiar historial expirado cada 10 minutos
    setInterval(() => {
      this.cleanupExpiredHistory();
    }, 10 * 60 * 1000);
  }

  /**
   * 🎯 ALGORITMO AVANZADO DE RECOMENDACIONES CON SCORING MULTI-FACTOR
   * Usa: Género + Popularidad + Artista + Novedad + Afinidad de Usuario
   */
  async getRecommendedSong(
    currentSongId: string,
    userId?: string,
    genres?: string[],
    offset?: number, // 🚨 OFFSET: Para variar cache en llamadas paralelas (no afecta lógica)
    excludeIds: string[] = [], // 🚨 EXCLUDEIDS: IDs a excluir para evitar duplicados en batch
    loopDetected: boolean = false // 🚨 LOOP DETECTION: Flag para ajustar scoring cuando detecta loops
  ): Promise<Song | null> {
    const startTime = Date.now();
    this.logger.log(`🎵 [ADVANCED] Iniciando recomendación avanzada para canción: ${currentSongId}${userId ? ` (usuario: ${userId})` : ''}${offset !== undefined ? ` [offset: ${offset}]` : ''}${excludeIds.length > 0 ? ` [excluyendo ${excludeIds.length} IDs]` : ''}`);

    // 🔍 DEBUG: Log de géneros recibidos
    this.logger.log(`🎛️ [DEBUG GENRES] Géneros recibidos en getRecommendedSong: ${genres ? `[${genres.join(', ')}]` : 'NINGUNO (undefined)'}`);
    if (genres && genres.length > 0) {
      this.logger.log(`🎛️ [DEBUG GENRES] ¡VIBE SELECTOR ACTIVO! Filtrando por: ${genres.join(', ')}`);
    }

    try {
      // 🚨 EXCLUDEIDS: Crear conjunto de IDs excluidos (incluyendo la semilla)
      const excludedSet = new Set<string>([currentSongId, ...excludeIds]);
      if (excludeIds.length > 0) {
        this.logger.log(`🚫 [EXCLUDEIDS] Excluyendo ${excludeIds.length} IDs del batch: ${excludeIds.slice(0, 5).map(id => id.substring(0, 8)).join(', ')}${excludeIds.length > 5 ? '...' : ''}`);
      }

      // ✅ MEJORA #3: CACHE INTELIGENTE CON INVALIDACIÓN
      // Invalidar cache si hay demasiadas exclusiones (probablemente está obsoleto)
      const shouldInvalidateCache = this.shouldInvalidateCache(excludeIds);

      // 1. Verificar cache primero (optimización de costos)
      // 🚨 OFFSET: Incluir offset en la clave de cache para romper cache en llamadas paralelas
      // ✅ MEJORA #3: Incluir cantidad de exclusiones en la clave para mejor granularidad
      const cacheKey = this.generateCacheKey(currentSongId, genres, userId, offset, excludeIds.length);

      // ✅ MEJORA #3: No usar cache si hay demasiadas exclusiones
      if (!shouldInvalidateCache) {
        const cached = this.getCachedRecommendation(cacheKey);
        if (cached) {
          // 🚨 EXCLUDEIDS: Verificar si el resultado del cache está en excludeIds (CRÍTICO)
          if (excludedSet.has(cached.id)) {
            this.logger.warn(`🚫 [CACHE HIT REJECTED] Recomendación desde cache está en excludeIds (${excludeIds.length} IDs), ignorando cache: ${cached.title} (ID: ${cached.id.substring(0, 8)}...)`);
            // NO retornar el cache, continuar con la lógica normal para obtener una alternativa
            // Eliminar del cache para evitar futuros hits incorrectos
            this.recommendationCache.delete(cacheKey);
          } else {
            this.logger.log(`⚡ [CACHE HIT] Recomendación desde cache válida: ${cached.title} (offset: ${offset ?? 'none'}, excludeIds: ${excludeIds.length})`);
            return cached;
          }
        }
      } else {
        this.logger.debug(`🔄 [CACHE] Invalidando cache debido a muchas exclusiones (${excludeIds.length} IDs)`);
      }

      // 2. Obtener canción actual
      const currentSong = await this.getCurrentSong(currentSongId);
      if (!currentSong) {
        this.logger.warn(`❌ Canción actual no encontrada: ${currentSongId}`);
        return null;
      }

      // 3. Obtener géneros (de parámetros o de la canción actual)
      // 🎛️ VIBE SELECTOR: Si genres viene como parámetro, es del Vibe Selector y debe respetarse
      const isVibeSelector = genres && genres.length > 0;
      const songGenres = genres || currentSong.genres || [];

      if (isVibeSelector) {
        this.logger.log(`🎛️ [VIBE SELECTOR] Filtrando por géneros del usuario: ${songGenres.join(', ')}`);
      }

      if (songGenres.length === 0) {
        this.logger.warn(`❌ No hay géneros disponibles para: ${currentSongId}`);
        // Si no hay géneros, buscar por popularidad general
        return await this.getPopularSongs(currentSongId, userId, excludeIds);
      }

      // 4. Verificar si necesitamos cambiar de género (después de 3 canciones del mismo género)
      // 🎛️ VIBE SELECTOR: NO cambiar de género si el usuario lo seleccionó explícitamente
      const shouldChangeGenre = isVibeSelector
        ? false // 🎛️ NUNCA cambiar si es del Vibe Selector
        : await this.shouldChangeToDifferentGenre(currentSongId, songGenres, userId);

      // ✅ MEJORA #1: DETECCIÓN PROACTIVA DE LOOPS
      // Detectar loops ANTES de obtener candidatos para ajustar estrategia
      const detectedLoop = await this.detectPotentialLoop(currentSong, userId);
      const effectiveLoopDetected = loopDetected || detectedLoop;

      if (detectedLoop && !loopDetected) {
        this.logger.warn(`🔄 [LOOP DETECTION] Loop detectado proactivamente para: ${currentSong.title} (artista: ${currentSong.artistId})`);
      }

      // 5. Obtener candidatos usando múltiples estrategias
      // 🚨 LOOP DETECTION: Pasar flag para aumentar límite de candidatos
      // 🎛️ VIBE SELECTOR: Siempre usar songGenres si viene del Vibe Selector
      const genresForCandidates = isVibeSelector ? songGenres : (shouldChangeGenre ? [] : songGenres);
      const candidates = await this.getCandidateSongs(
        currentSong,
        userId,
        genresForCandidates,
        shouldChangeGenre,
        excludeIds, // 🚨 EXCLUDEIDS: Pasar excludeIds para filtrar candidatos
        effectiveLoopDetected // ✅ MEJORA #1: Usar detección proactiva
      );

      // 🚨 EXCLUDEIDS: Filtrar candidatos que están en excludeIds (VALIDACIÓN CRÍTICA)
      const filteredCandidates = candidates.filter(song => {
        const isExcluded = excludedSet.has(song.id);
        if (isExcluded) {
          this.logger.warn(`🚫 [FILTRO FINAL] Eliminando candidato en excludeIds: ${song.title} (ID: ${song.id.substring(0, 8)}...)`);
        }
        return !isExcluded;
      });

      if (filteredCandidates.length === 0) {
        this.logger.warn(`⚠️ No se encontraron candidatos después de filtrar excludeIds (${candidates.length} candidatos antes, ${excludeIds.length} excluidos), usando fallback inteligente`);

        // 🚀 FALLBACK SIMPLE: Permitir repeticiones en géneros específicos
        let fallback = null;

        // 🎛️ VIBE SELECTOR: Si hay género específico, permitir repeticiones
        if (songGenres.length > 0 && isVibeSelector) {
          this.logger.log(`🔄 [FALLBACK GÉNERO] Permitiendo repeticiones para género: ${songGenres.join(', ')}`);
          // Buscar canción del género ignorando excludeIds (permitir repetir)
          fallback = await this.getSongsByGenreDirectly(songGenres, currentSongId);
          if (fallback) {
            this.logger.log(`✅ [FALLBACK GÉNERO] Canción encontrada (puede ser repetida): ${fallback.title}`);
          }
        }

        // Estrategia 1: Buscar por género amplio (para modos no-Vibe)
        if (!fallback && songGenres.length > 0 && !shouldChangeGenre) {
          this.logger.log(`🔄 [FALLBACK 1] Buscando por género amplio (ignorando artista/afinidad)...`);
          fallback = await this.getSongsByGenreAndPopularity(songGenres, currentSongId, userId, excludeIds, false);
        }

        // Estrategia 1b: Si cambiamos género (SOLO si NO es Vibe Selector), buscar otros géneros
        if (!isVibeSelector && shouldChangeGenre && songGenres.length > 0 && !fallback) {
          this.logger.log(`🔄 [FALLBACK 1b] Buscando canciones de otros géneros...`);
          fallback = await this.getSongsFromDifferentGenre(songGenres, currentSongId, userId, excludeIds);
        }

        // Estrategia 2: Buscar canciones populares globales (ignorando género)
        if (!fallback) {
          this.logger.log(`🔄 [FALLBACK 2] Buscando canciones populares globales...`);
          fallback = await this.getPopularSongs(currentSongId, userId, excludeIds);
        }

        // Estrategia 3: Buscar cualquier canción disponible (último recurso)
        if (!fallback) {
          this.logger.log(`🔄 [FALLBACK 3] Buscando cualquier canción disponible...`);
          fallback = await this.getAnyAvailableSong(currentSongId, excludeIds);
        }

        if (fallback) {
          this.cacheRecommendation(cacheKey, fallback);
        }
        return fallback;
      }

      // 6. Aplicar scoring multi-factor (solo en candidatos filtrados)
      // 🚨 LOOP DETECTION: Pasar flag para ajustar pesos dinámicamente
      const scoredSongs = await this.applySimilarityScoring(currentSong, filteredCandidates, userId, effectiveLoopDetected);

      // 7. Seleccionar mejor recomendación con diversidad
      // ✅ MEJORA #2: Pasar historial reciente para diversidad forzada
      const recentHistory = await this.getRecentSongsFromHistory(userId || 'anonymous');
      const recommendation = this.selectBestRecommendation(scoredSongs, userId, recentHistory);

      // 🚨 VALIDACIÓN CRÍTICA: Asegurar que la recomendación final NO esté en excludeIds
      if (recommendation && excludedSet.has(recommendation.id)) {
        this.logger.error(`❌ ERROR CRÍTICO: Recomendación seleccionada está en excludeIds: ${recommendation.title} (ID: ${recommendation.id.substring(0, 8)}...). Buscando alternativa...`);
        // Buscar primera canción que no esté excluida
        const alternative = filteredCandidates.find(song => !excludedSet.has(song.id));
        if (alternative) {
          this.logger.log(`✅ Usando alternativa: ${alternative.title} (ID: ${alternative.id.substring(0, 8)}...)`);
          if (userId) {
            this.addToRecentHistory(userId, currentSongId);
          }
          this.cacheRecommendation(cacheKey, alternative);
          return alternative;
        }
        return null;
      }

      // 8. Actualizar historial y cachear
      if (recommendation) {
        if (userId) {
          this.addToRecentHistory(userId, currentSongId);
        }
        this.cacheRecommendation(cacheKey, recommendation);
      }

      const duration = Date.now() - startTime;
      this.logger.log(`✅ Recomendación avanzada completada en ${duration}ms: ${recommendation?.title || 'ninguna'}`);

      return recommendation;

    } catch (error) {
      this.logger.error(`❌ Error en recomendación: ${error.message}`, error.stack);
      return null;
    }
  }

  /**
   * 🔍 OBTENER CANCIÓN ACTUAL CON TODA LA INFORMACIÓN
   */
  private async getCurrentSong(songId: string): Promise<Song | null> {
    try {
      const song = await this.songRepository.findOne({
        where: { id: songId },
        relations: ['artist', 'album', 'genre'],
      });

      if (song) {
        this.logger.log(`🎵 Canción actual encontrada: ${song.title} (géneros: ${song.genres?.join(', ') || 'ninguno'})`);
      } else {
        this.logger.warn(`❌ Canción no encontrada: ${songId}`);
      }

      return song;
    } catch (error) {
      this.logger.error(`❌ Error obteniendo canción actual: ${error.message}`);
      return null;
    }
  }

  /**
   * 🎵 ALGORITMO SIMPLE: Buscar canciones por género y popularidad
   * @param strictGenre - Si es true (Vibe Selector), NO hace fallback a otros géneros
   */
  private async getSongsByGenreAndPopularity(
    genres: string[],
    currentSongId: string,
    userId?: string,
    excludeIds: string[] = [], // 🚨 EXCLUDEIDS: IDs adicionales a excluir
    strictGenre: boolean = false // 🎛️ VIBE SELECTOR: No hacer fallback a otros géneros
  ): Promise<Song | null> {
    try {
      // Obtener historial reciente (últimas 10 canciones para evitar repetitividad)
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 10); // Últimas 10 canciones excluidas

      // Buscar canciones del mismo género, ordenadas por reproducciones
      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .leftJoinAndSelect('song.genre', 'genre') // 🎛️ Cargar género
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // 🎛️ VIBE SELECTOR: Filtrar por género (array + relación)
      if (genres.length > 0) {
        const genreConditions = genres.map((_, index) =>
          `(LOWER(song.genres) LIKE :genre${index} OR LOWER(genre.name) = :genreName${index})`
        ).join(' OR ');

        query.andWhere(`(${genreConditions})`);
        genres.forEach((genre, index) => {
          query.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
          query.setParameter(`genreName${index}`, genre.toLowerCase());
        });
      }

      // 🚨 EXCLUDEIDS: Combinar recentIds con excludeIds
      const allExcludeIds = [...recentIds, ...excludeIds, currentSongId];
      if (allExcludeIds.length > 0) {
        query.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
      }

      // Ordenar por número de reproducciones (más popular primero)
      query.orderBy('song.totalStreams', 'DESC');
      query.limit(20); // Tomar las 20 más populares

      let songs = await query.getMany();

      // Si no hay suficientes canciones, relajar filtros
      if (songs.length < 5) {
        this.logger.log(`⚠️ Pocas canciones encontradas (${songs.length}), relajando filtros...`);

        // Intentar sin filtrar recientes
        const relaxedQuery = this.songRepository.createQueryBuilder('song')
          .leftJoinAndSelect('song.artist', 'artist')
          .leftJoinAndSelect('song.album', 'album')
          .leftJoinAndSelect('song.genre', 'genre') // 🎛️ Cargar género
          .where('song.status = :status', { status: SongStatus.PUBLISHED })
          .andWhere('song.id != :currentId', { currentId: currentSongId })
          .andWhere('song.fileUrl IS NOT NULL')
          .andWhere('song.fileUrl != \'\'')
          .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
          .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

        if (genres.length > 0) {
          const genreConditions = genres.map((_, index) =>
            `(LOWER(song.genres) LIKE :relaxedGenre${index} OR LOWER(genre.name) = :relaxedGenreName${index})`
          ).join(' OR ');

          relaxedQuery.andWhere(`(${genreConditions})`);
          genres.forEach((genre, index) => {
            relaxedQuery.setParameter(`relaxedGenre${index}`, `%${genre.toLowerCase()}%`);
            relaxedQuery.setParameter(`relaxedGenreName${index}`, genre.toLowerCase());
          });
        }

        // 🚨 EXCLUDEIDS: Mantener excludeIds incluso en consulta relajada
        const relaxedExcludeIds = [...excludeIds, currentSongId];
        if (relaxedExcludeIds.length > 0) {
          relaxedQuery.andWhere('song.id NOT IN (:...relaxedExcludeIds)', { relaxedExcludeIds });
        }

        relaxedQuery.orderBy('song.totalStreams', 'DESC').limit(10);
        songs = await relaxedQuery.getMany();
      }

      // 🎛️ VIBE SELECTOR: Si strictGenre=true y no hay canciones, logueamos y dejamos que cambie a MIX
      if (songs.length === 0 && strictGenre) {
        this.logger.log(`🔀 [VIBE SELECTOR] Se agotaron las canciones del género. Cambiar a MIX.`);
      }

      // Si aún no hay canciones, buscar cualquier canción popular
      // 🎛️ VIBE SELECTOR: Si strictGenre=true, NO hacer este fallback (dejar que el caller maneje)
      if (songs.length === 0 && !strictGenre) {
        this.logger.log(`⚠️ No hay canciones del género, buscando cualquier canción popular...`);
        const finalExcludeIds = [...excludeIds, currentSongId];
        const finalQuery = this.songRepository.createQueryBuilder('song')
          .leftJoinAndSelect('song.artist', 'artist')
          .leftJoinAndSelect('song.album', 'album')
          .where('song.status = :status', { status: SongStatus.PUBLISHED })
          .andWhere('song.fileUrl IS NOT NULL')
          .andWhere('song.fileUrl != \'\'')
          .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
          .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

        if (finalExcludeIds.length > 0) {
          finalQuery.andWhere('song.id NOT IN (:...finalExcludeIds)', { finalExcludeIds });
        }

        songs = await finalQuery
          .orderBy('song.totalStreams', 'DESC')
          .limit(10)
          .getMany();
      }

      if (songs.length === 0) {
        this.logger.warn(`❌ No se encontraron canciones para recomendar`);
        return null;
      }

      // 🎲 Seleccionar una canción aleatoria de las top (diversidad mejorada)
      // Aumentar el rango de selección para más variedad (top 10 en lugar de top 5)
      const topSongs = songs.slice(0, Math.min(10, songs.length)); // Top 10 para más diversidad
      const randomIndex = Math.floor(Math.random() * topSongs.length);
      const randomSong = topSongs[randomIndex];

      this.logger.log(`✅ Recomendación seleccionada: ${randomSong.title} (${randomSong.totalStreams || 0} reproducciones, posición ${randomIndex + 1} de ${topSongs.length})`);

      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones por género: ${error.message}`);
      return null;
    }
  }

  /**
   * �️ VIBE SELECTOR: Buscar canción del género SIN filtros de historial ni excludeIds
   * Usado como último intento antes de cambiar a Mix
   */
  private async getSongsByGenreDirectly(
    genres: string[],
    currentSongId: string,
  ): Promise<Song | null> {
    try {
      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .leftJoinAndSelect('song.genre', 'genre')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // Filtrar por género
      if (genres.length > 0) {
        const genreConditions = genres.map((_, index) =>
          `(LOWER(song.genres) LIKE :genre${index} OR LOWER(genre.name) = :genreName${index})`
        ).join(' OR ');

        query.andWhere(`(${genreConditions})`);
        genres.forEach((genre, index) => {
          query.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
          query.setParameter(`genreName${index}`, genre.toLowerCase());
        });
      }

      // 🔀 SHUFFLE: Ordenar aleatoriamente para loops variados (no siempre las mismas top)
      query.orderBy('RANDOM()').limit(50); // Tomar hasta 50 aleatorias del género

      const songs = await query.getMany();

      if (songs.length === 0) {
        this.logger.warn(`❌ [DIRECT QUERY] No hay canciones del género ${genres.join(', ')} en la BD`);
        return null;
      }

      // Preferir canciones que NO sean la actual, pero PERMITIR repetición si es necesario
      const otherSongs = songs.filter(s => s.id !== currentSongId);
      const songsToSelect = otherSongs.length > 0 ? otherSongs : songs;

      // Seleccionar aleatoriamente de las disponibles
      const randomIndex = Math.floor(Math.random() * songsToSelect.length);
      const randomSong = songsToSelect[randomIndex];

      const repetitionNote = otherSongs.length === 0 ? ' (⚠️ REPITIENDO canción actual)' : '';
      this.logger.log(`✅ [DIRECT QUERY] Canción: ${randomSong.title} (${songsToSelect.length} disponibles${repetitionNote})`);

      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error en getSongsByGenreDirectly: ${error.message}`);
      return null;
    }
  }

  /**
   * �🎵 Buscar canciones populares cuando no hay géneros
   */
  private async getPopularSongs(
    currentSongId: string,
    userId?: string,
    excludeIds: string[] = [] // 🚨 EXCLUDEIDS: IDs adicionales a excluir
  ): Promise<Song | null> {
    try {
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 10); // Últimas 10 canciones excluidas

      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // 🚨 EXCLUDEIDS: Combinar recentIds con excludeIds
      const allExcludeIds = [...recentIds, ...excludeIds, currentSongId];
      if (allExcludeIds.length > 0) {
        query.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
      }

      const songs = await query
        .orderBy('song.totalStreams', 'DESC')
        .limit(10)
        .getMany();

      if (songs.length === 0) {
        return null;
      }

      // 🎲 Seleccionar una canción aleatoria de las top (diversidad mejorada)
      // Aumentar el rango de selección para más variedad (top 10 en lugar de top 5)
      const topSongs = songs.slice(0, Math.min(10, songs.length)); // Top 10 para más diversidad
      const randomIndex = Math.floor(Math.random() * topSongs.length);
      const randomSong = topSongs[randomIndex];

      this.logger.log(`✅ Recomendación popular seleccionada: ${randomSong.title} (posición ${randomIndex + 1} de ${topSongs.length})`);
      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones populares: ${error.message}`);
      return null;
    }
  }

  /**
   * 🚨 ÚLTIMO RECURSO: Obtener cualquier canción disponible (ignorando todo excepto excludeIds)
   */
  private async getAnyAvailableSong(
    currentSongId: string,
    excludeIds: string[] = []
  ): Promise<Song | null> {
    try {
      const allExcludeIds = [...excludeIds, currentSongId];

      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      if (allExcludeIds.length > 0) {
        query.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
      }

      const songs = await query
        .orderBy('song.totalStreams', 'DESC')
        .limit(10)
        .getMany();

      if (songs.length === 0) {
        this.logger.warn(`❌ [FALLBACK 3] No hay canciones disponibles después de excluir ${allExcludeIds.length} IDs`);
        return null;
      }

      const selected = songs[Math.floor(Math.random() * songs.length)];
      this.logger.log(`✅ [FALLBACK 3] Canción disponible seleccionada: ${selected.title}`);
      return selected;
    } catch (error) {
      this.logger.error(`❌ Error en fallback final: ${error.message}`);
      return null;
    }
  }

  /**
   * ✅ MEJORA #1: DETECTAR LOOPS PROACTIVAMENTE
   * Detecta si hay un patrón repetitivo (mismo artista/género) en las últimas canciones
   * Esto permite ajustar el algoritmo ANTES de que el loop se vuelva obvio
   */
  private async detectPotentialLoop(currentSong: Song, userId?: string): Promise<boolean> {
    try {
      const recentSongIds = this.getRecentHistory(userId || 'anonymous');

      // Necesitamos al menos 2 canciones anteriores para detectar un loop
      if (recentSongIds.length < 2) {
        return false;
      }

      // Obtener las últimas 2-3 canciones reproducidas
      const checkCount = Math.min(3, recentSongIds.length);
      const recentSongs = await this.songRepository
        .createQueryBuilder('song')
        .select(['song.id', 'song.artistId', 'song.genres'])
        .where('song.id IN (:...ids)', { ids: recentSongIds.slice(0, checkCount) })
        .getMany();

      // Verificar loop de artista: si las últimas 2-3 canciones son del mismo artista
      const recentArtists = recentSongs.map(s => s.artistId);
      const allSameArtist = recentArtists.every(id => id === currentSong.artistId);

      if (allSameArtist && recentArtists.length >= 2) {
        this.logger.warn(`🔄 [LOOP DETECTION] Loop de artista detectado: ${recentArtists.length + 1} canciones consecutivas del mismo artista (${currentSong.artistId})`);
        return true;
      }

      // Verificar loop de género: si las últimas 2-3 canciones comparten todos los géneros
      if (currentSong.genres && currentSong.genres.length > 0) {
        const currentGenres = new Set(currentSong.genres.map(g => g.toLowerCase()));
        let sameGenreCount = 1; // Empezamos con 1 (la canción actual)

        for (const song of recentSongs) {
          if (song.genres && song.genres.length > 0) {
            const songGenres = new Set(song.genres.map(g => g.toLowerCase()));
            // Verificar si comparten todos los géneros (intersección completa)
            const allGenresMatch = Array.from(currentGenres).every(g => songGenres.has(g)) &&
              Array.from(songGenres).every(g => currentGenres.has(g));

            if (allGenresMatch) {
              sameGenreCount++;
            } else {
              break; // Si encontramos una diferente, paramos
            }
          }
        }

        if (sameGenreCount >= 3) {
          this.logger.warn(`🔄 [LOOP DETECTION] Loop de género detectado: ${sameGenreCount} canciones consecutivas del mismo género`);
          return true;
        }
      }

      return false;
    } catch (error) {
      this.logger.error(`❌ Error detectando loop: ${error.message}`);
      return false;
    }
  }

  /**
   * 🎯 Detectar si debemos cambiar a otro género (después de 3 canciones consecutivas del mismo género)
   */
  private async shouldChangeToDifferentGenre(
    currentSongId: string,
    currentGenres: string[],
    userId?: string
  ): Promise<boolean> {
    try {
      const recentSongIds = this.getRecentHistory(userId || 'anonymous');

      // Necesitamos verificar las últimas 2 canciones (la actual es la tercera)
      if (recentSongIds.length < 2) {
        return false; // No hay suficientes canciones para cambiar
      }

      // Obtener las últimas 2 canciones reproducidas
      const recentSongs = await this.songRepository
        .createQueryBuilder('song')
        .select(['song.id', 'song.genres'])
        .where('song.id IN (:...ids)', { ids: recentSongIds.slice(0, 2) })
        .getMany();

      // Contar cuántas canciones consecutivas tienen el mismo género (incluyendo la actual)
      let sameGenreCount = 1; // Empezamos con 1 (la canción actual)

      // Verificar las últimas 2 canciones
      for (const song of recentSongs) {
        if (song.genres && song.genres.length > 0) {
          // Verificar si comparte algún género con la canción actual
          const hasCommonGenre = song.genres.some(genre =>
            currentGenres.some(currentGenre =>
              genre.toLowerCase() === currentGenre.toLowerCase()
            )
          );

          if (hasCommonGenre) {
            sameGenreCount++;
          } else {
            break; // Si encontramos una diferente, paramos el conteo
          }
        }
      }

      // Si hay 3 o más canciones consecutivas del mismo género (actual + 2 anteriores), cambiar
      if (sameGenreCount >= 3) {
        this.logger.log(`🔄 Cambiando de género después de ${sameGenreCount} canciones consecutivas del mismo género`);
        return true;
      }

      return false;
    } catch (error) {
      this.logger.error(`❌ Error verificando cambio de género: ${error.message}`);
      return false;
    }
  }

  /**
   * 🎵 Buscar canciones de OTROS géneros para scoring (retorna lista)
   */
  private async getSongsFromDifferentGenreForScoring(
    excludeGenres: string[],
    currentSongId: string,
    userId?: string,
    excludeIds: string[] = [] // 🚨 EXCLUDEIDS: IDs adicionales a excluir
  ): Promise<Song[]> {
    try {
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 10); // Últimas 10 canciones excluidas

      // Buscar canciones que NO sean de los géneros excluidos
      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // Excluir géneros actuales (buscar géneros diferentes)
      if (excludeGenres.length > 0) {
        const excludeConditions = excludeGenres.map((_, index) =>
          `LOWER(song.genres) NOT LIKE :excludeGenre${index}`
        ).join(' AND ');

        query.andWhere(`(${excludeConditions})`);
        excludeGenres.forEach((genre, index) => {
          query.setParameter(`excludeGenre${index}`, `%${genre.toLowerCase()}%`);
        });
      }

      // 🚨 EXCLUDEIDS: Combinar excludeIds con recentIds
      const allExcludeIds = [...recentIds, ...excludeIds];
      if (allExcludeIds.length > 0) {
        query.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
      }

      // Ordenar por reproducciones (popular primero)
      query.orderBy('song.totalStreams', 'DESC');
      query.limit(20);

      let songs = await query.getMany();

      // Si no hay canciones de otros géneros, buscar cualquier canción popular
      if (songs.length === 0) {
        this.logger.log(`⚠️ No hay canciones de otros géneros, buscando cualquier canción popular...`);
        songs = await this.songRepository.find({
          where: {
            status: SongStatus.PUBLISHED,
            id: Not(currentSongId),
            fileUrl: Not(''),
          },
          relations: ['artist', 'album'],
          order: { totalStreams: 'DESC' },
          take: 20,
        });
      }

      this.logger.log(`🎵 Canciones de otros géneros encontradas: ${songs.length}`);
      return songs;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones de otros géneros: ${error.message}`);
      return [];
    }
  }

  /**
   * 🎵 Buscar canciones de OTROS géneros (diversidad) - Método legacy para fallback
   */
  private async getSongsFromDifferentGenre(
    excludeGenres: string[],
    currentSongId: string,
    userId?: string,
    excludeIds: string[] = [] // 🚨 EXCLUDEIDS: IDs adicionales a excluir
  ): Promise<Song | null> {
    try {
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 10); // Últimas 10 canciones excluidas

      // Buscar canciones que NO sean de los géneros excluidos
      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // Excluir géneros actuales (buscar géneros diferentes)
      if (excludeGenres.length > 0) {
        const excludeConditions = excludeGenres.map((_, index) =>
          `LOWER(song.genres) NOT LIKE :excludeGenre${index}`
        ).join(' AND ');

        query.andWhere(`(${excludeConditions})`);
        excludeGenres.forEach((genre, index) => {
          query.setParameter(`excludeGenre${index}`, `%${genre.toLowerCase()}%`);
        });
      }

      // 🚨 EXCLUDEIDS: Combinar recentIds con excludeIds
      const allExcludeIds = [...recentIds, ...excludeIds, currentSongId];
      if (allExcludeIds.length > 0) {
        query.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
      }

      // Ordenar por reproducciones (popular primero)
      query.orderBy('song.totalStreams', 'DESC');
      query.limit(20);

      let songs = await query.getMany();

      // Si no hay canciones de otros géneros, buscar cualquier canción popular
      if (songs.length === 0) {
        this.logger.log(`⚠️ No hay canciones de otros géneros, buscando cualquier canción popular...`);
        const fallbackQuery = this.songRepository.createQueryBuilder('song')
          .leftJoinAndSelect('song.artist', 'artist')
          .leftJoinAndSelect('song.album', 'album')
          .where('song.status = :status', { status: SongStatus.PUBLISHED })
          .andWhere('song.fileUrl IS NOT NULL')
          .andWhere('song.fileUrl != \'\'')
          .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
          .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

        if (allExcludeIds.length > 0) {
          fallbackQuery.andWhere('song.id NOT IN (:...allExcludeIds)', { allExcludeIds });
        }

        songs = await fallbackQuery
          .orderBy('song.totalStreams', 'DESC')
          .limit(10)
          .getMany();
      }

      if (songs.length === 0) {
        this.logger.warn(`❌ No se encontraron canciones de otros géneros`);
        return null;
      }

      // 🎲 Seleccionar una canción aleatoria de las top (diversidad mejorada)
      // Aumentar el rango de selección para más variedad (top 10 en lugar de top 5)
      const topSongs = songs.slice(0, Math.min(10, songs.length)); // Top 10 para más diversidad
      const randomIndex = Math.floor(Math.random() * topSongs.length);
      const randomSong = topSongs[randomIndex];

      this.logger.log(`✅ Recomendación de otro género seleccionada: ${randomSong.title} (géneros: ${randomSong.genres?.join(', ') || 'ninguno'}, posición ${randomIndex + 1} de ${topSongs.length})`);

      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones de otros géneros: ${error.message}`);
      return null;
    }
  }

  /**
   * 🎯 OBTENER CANDIDATOS USANDO MÚLTIPLES ESTRATEGIAS
   * Similar a como Spotify combina diferentes fuentes
   */
  private async getCandidateSongs(
    currentSong: Song,
    userId?: string,
    genres?: string[],
    shouldChangeGenre: boolean = false,
    excludeIds: string[] = [], // 🚨 EXCLUDEIDS: IDs adicionales a excluir
    loopDetected: boolean = false // 🚨 LOOP DETECTION: Flag para aumentar límite de candidatos
  ): Promise<Song[]> {
    const strategies = [];

    // 🎛️ VIBE SELECTOR OPTIMIZATION: Detectar si es Vibe Selector para optimizar estrategias
    const isVibeSelector = genres && genres.length > 0;

    if (shouldChangeGenre) {
      // Si debemos cambiar de género, buscar canciones de otros géneros
      strategies.push(
        // Estrategia 1: Canciones de otros géneros (peso alto)
        this.getSongsFromDifferentGenreForScoring(genres || [], currentSong.id, userId, excludeIds),

        // Estrategia 2: Mismo artista (peso medio)
        this.getSameArtistSongs(currentSong, excludeIds),

        // Estrategia 3: Canciones populares similares (peso medio)
        this.getPopularSimilarSongs(currentSong, excludeIds),

        // Estrategia 4: Basado en historial de usuario (peso alto si hay userId)
        userId ? this.getUserBasedRecommendations(userId, currentSong, excludeIds) : Promise.resolve([]),

        // Estrategia 5: Trending songs (peso bajo)
        this.getTrendingSongs([], excludeIds),
      );
    } else if (isVibeSelector) {
      // 🎛️ VIBE SELECTOR OPTIMIZADO: Solo estrategias que respetan el género
      // Esto evita consultas innecesarias a la BD que luego se descartarían
      this.logger.log(`⚡ [VIBE SELECTOR] Modo optimizado: solo estrategias de género (${genres.join(', ')})`);
      strategies.push(
        // Estrategia 1: Mismo género (peso alto) - PRINCIPAL
        this.getSameGenreSongs(currentSong, genres, excludeIds, loopDetected),

        // Estrategia 2: Trending del mismo género (peso medio)
        this.getTrendingSongs(genres, excludeIds),
      );
    } else {
      // Estrategia normal: mismo género + otras fuentes
      strategies.push(
        // Estrategia 1: Mismo género (peso alto)
        // 🚨 LOOP DETECTION: Aumentar límite cuando detecta loops
        this.getSameGenreSongs(currentSong, genres, excludeIds, loopDetected),

        // Estrategia 2: Mismo artista (peso medio)
        this.getSameArtistSongs(currentSong, excludeIds),

        // Estrategia 3: Canciones populares similares (peso medio)
        this.getPopularSimilarSongs(currentSong, excludeIds),

        // Estrategia 4: Basado en historial de usuario (peso alto si hay userId)
        userId ? this.getUserBasedRecommendations(userId, currentSong, excludeIds) : Promise.resolve([]),

        // Estrategia 5: Trending songs del mismo género (peso bajo)
        this.getTrendingSongs(genres, excludeIds),
      );
    }

    const results = await Promise.all(strategies);

    // Combinar y deduplicar candidatos
    const allCandidates = results.flat();
    let uniqueCandidates = this.deduplicateSongs(allCandidates, currentSong.id);

    // 🎛️ VIBE SELECTOR: Filtro de seguridad (solo para modo normal, no optimizado)
    // En modo optimizado (isVibeSelector), las estrategias ya respetan el género
    if (genres && genres.length > 0 && !isVibeSelector) {
      const genreLower = genres.map(g => g.toLowerCase());
      const beforeCount = uniqueCandidates.length;
      uniqueCandidates = uniqueCandidates.filter(song => {
        const songGenres = song.genres || [];
        return songGenres.some(g => genreLower.includes(g.toLowerCase()));
      });
      const afterCount = uniqueCandidates.length;
      if (beforeCount !== afterCount) {
        this.logger.log(`🎛️ [GENRE FILTER] Filtrado: ${beforeCount} → ${afterCount} (eliminados ${beforeCount - afterCount})`);
      }
    }

    // Obtener historial reciente para excluir
    const recentSongs = this.getRecentHistory(userId || 'anonymous');
    // 🚨 FLEXIBILIZAR: Reducir exclusión de 10 a 7 para más candidatos
    const recentIds = recentSongs.slice(0, 7); // Últimas 7 canciones excluidas (antes 10)

    // 🚨 EXCLUDEIDS: Combinar excludeIds con recentIds
    const allExcludeIds = new Set<string>([...recentIds, ...excludeIds]);

    // 🚨 EXCLUDEIDS: Excluir canciones recientes y excludeIds (CRÍTICO: filtrado estricto)
    let filteredCandidates = uniqueCandidates.filter(
      song => {
        const isExcluded = allExcludeIds.has(song.id);
        if (isExcluded && excludeIds.includes(song.id)) {
          this.logger.warn(`🚫 EXCLUSIÓN FORZADA: ${song.title} (ID: ${song.id.substring(0, 8)}...) está en excludeIds del batch`);
        }
        return !isExcluded;
      }
    );

    // 🚨 FLEXIBILIZAR: Si hay muy pocos candidatos después de filtrar, ser menos estricto
    // PERO: NUNCA relajar excludeIds del batch (son críticos para evitar duplicados)
    if (filteredCandidates.length < 5 && uniqueCandidates.length > filteredCandidates.length) {
      this.logger.log(`⚠️ Pocos candidatos después de filtrar (${filteredCandidates.length}), reduciendo exclusión de recientes (pero manteniendo excludeIds del batch)...`);
      // Excluir solo las últimas 5 canciones en lugar de 7, pero mantener TODOS los excludeIds
      const relaxedRecentIds = recentSongs.slice(0, 5);
      const relaxedExcludeIds = new Set<string>([...relaxedRecentIds, ...excludeIds]); // Mantener TODOS los excludeIds
      filteredCandidates = uniqueCandidates.filter(
        song => !relaxedExcludeIds.has(song.id)
      );
    }

    // 🚨 VALIDACIÓN FINAL: Verificar que NO haya ningún candidato en excludeIds
    const invalidCandidates = filteredCandidates.filter(song => excludeIds.includes(song.id));
    if (invalidCandidates.length > 0) {
      this.logger.error(`❌ ERROR CRÍTICO: ${invalidCandidates.length} candidatos están en excludeIds pero pasaron el filtro! Eliminándolos...`);
      filteredCandidates = filteredCandidates.filter(song => !excludeIds.includes(song.id));
    }

    const excludedCount = allExcludeIds.size - excludeIds.length; // Contar solo recentIds excluidos
    this.logger.log(`🎯 Candidatos encontrados: ${filteredCandidates.length} (de ${uniqueCandidates.length} totales, excluidas ${excludedCount} recientes + ${excludeIds.length} de batch)`);
    return filteredCandidates;
  }

  /**
   * 🎵 ESTRATEGIA 1: CANCIONES DEL MISMO GÉNERO
   * 🚨 LOOP DETECTION: Aumenta límite de candidatos cuando detecta loops
   */
  private async getSameGenreSongs(currentSong: Song, genres?: string[], excludeIds: string[] = [], loopDetected: boolean = false): Promise<Song[]> {
    const targetGenres = genres || currentSong.genres || [];

    // 🔍 DEBUG: Log de géneros recibidos
    this.logger.log(`🔍 [SAME GENRE DEBUG] Parámetro genres: ${genres ? `[${genres.join(', ')}]` : 'undefined'}`);
    this.logger.log(`🔍 [SAME GENRE DEBUG] currentSong.genres: ${currentSong.genres ? `[${currentSong.genres.join(', ')}]` : 'undefined'}`);
    this.logger.log(`🔍 [SAME GENRE DEBUG] targetGenres final: [${targetGenres.join(', ')}]`);

    if (targetGenres.length === 0) {
      this.logger.warn(`🔍 [SAME GENRE DEBUG] ¡targetGenres está vacío! Retornando []`);
      return [];
    }

    this.logger.log(`🔍 [SAME GENRE] Buscando canciones con géneros: ${targetGenres.join(', ')}`);

    // 🔍 DEBUG: Primero contar cuántas canciones tienen este género
    const countQuery = this.songRepository.createQueryBuilder('song')
      .leftJoin('song.genre', 'genre')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'');

    // Agregar condición de género para el conteo
    const genreNameLower = targetGenres[0]?.toLowerCase() || '';
    countQuery.andWhere(`(LOWER(song.genres) LIKE :genrePattern OR LOWER(genre.name) = :genreName)`, {
      genrePattern: `%${genreNameLower}%`,
      genreName: genreNameLower
    });

    const totalWithGenre = await countQuery.getCount();
    this.logger.log(`🔍 [SAME GENRE] Total canciones en BD con género "${targetGenres[0]}": ${totalWithGenre}`);

    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre') // 🎛️ Cargar género para filtro adicional
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.id != :currentId', { currentId: currentSong.id })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

    // 🚨 EXCLUDEIDS: Excluir IDs adicionales si se proporcionan
    if (excludeIds.length > 0) {
      query.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds });
    }

    // 🎛️ VIBE SELECTOR: Agregar condiciones de género (array + relación)
    // Buscar en el array 'genres' O en el nombre del género relacionado
    const genreConditions = targetGenres.map((_, index) =>
      `(LOWER(song.genres) LIKE :genre${index} OR LOWER(genre.name) = :genreName${index})`
    ).join(' OR ');

    if (genreConditions) {
      query.andWhere(`(${genreConditions})`);
      targetGenres.forEach((genre, index) => {
        query.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
        query.setParameter(`genreName${index}`, genre.toLowerCase());
      });

      // 🔍 DEBUG: Log la query SQL generada
      this.logger.log(`🔍 [SAME GENRE] Filtro aplicado: ${genreConditions}`);
      this.logger.log(`🔍 [SAME GENRE] Parámetros: ${targetGenres.map((g, i) => `genre${i}=%${g.toLowerCase()}%, genreName${i}=${g.toLowerCase()}`).join(', ')}`);
    }

    // 🚨 FLEXIBILIZAR: Aumentar límite para más candidatos
    // 🚨 LOOP DETECTION: Aumentar límite cuando detecta loops (de 20 a 50)
    const candidateLimit = loopDetected ? 50 : 20; // Aumentar de 20 a 50 cuando detecta loops
    if (loopDetected) {
      this.logger.log(`🔄 [CANDIDATOS] Aumentando límite a ${candidateLimit} debido a detección de loop`);
    }
    let songs = await query
      .orderBy('song.totalStreams', 'DESC')
      .limit(candidateLimit)
      .getMany();

    // 🔍 DEBUG: Log las canciones encontradas y sus géneros
    this.logger.log(`🎵 Mismo género: ${songs.length} canciones encontradas para géneros: ${targetGenres.join(', ')}`);
    if (songs.length > 0) {
      const sampleSongs = songs.slice(0, 3).map(s => `${s.title} (genres: ${s.genres?.join(',') || 'null'}, genreId: ${s.genreId || 'null'})`);
      this.logger.log(`🔍 [SAME GENRE] Muestra de canciones: ${sampleSongs.join(' | ')}`);
    }

    // 🚨 FLEXIBILIZAR: Si no hay suficientes, buscar géneros relacionados
    if (songs.length < 10 && targetGenres.length > 0) {
      this.logger.log(`⚠️ Pocas canciones del mismo género (${songs.length}), buscando géneros relacionados...`);

      // Buscar canciones con géneros similares (géneros que contengan palabras clave)
      const relatedQuery = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .leftJoinAndSelect('song.genre', 'genre') // 🎛️ Cargar género
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSong.id })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // 🚨 EXCLUDEIDS: Excluir IDs adicionales si se proporcionan
      if (excludeIds.length > 0) {
        relatedQuery.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds });
      }

      // 🎛️ VIBE SELECTOR: Buscar géneros relacionados (array + relación)
      const relatedConditions = targetGenres.map((_, index) =>
        `(LOWER(song.genres) LIKE :relatedGenre${index} OR LOWER(genre.name) LIKE :relatedGenreName${index})`
      ).join(' OR ');

      if (relatedConditions) {
        relatedQuery.andWhere(`(${relatedConditions})`);
        targetGenres.forEach((genre, index) => {
          // Buscar géneros que contengan palabras clave del género original
          const keywords = genre.toLowerCase().split(' ');
          const relatedPattern = keywords.length > 0 ? `%${keywords[0]}%` : `%${genre.toLowerCase()}%`;
          relatedQuery.setParameter(`relatedGenre${index}`, relatedPattern);
          relatedQuery.setParameter(`relatedGenreName${index}`, relatedPattern);
        });
      }

      const relatedSongs = await relatedQuery
        .orderBy('song.totalStreams', 'DESC')
        .limit(15)
        .getMany();

      // Combinar y deduplicar
      const allSongs = [...songs, ...relatedSongs];
      const uniqueSongs = allSongs.filter((song, index, self) =>
        index === self.findIndex(s => s.id === song.id)
      );

      songs = uniqueSongs.slice(0, 20);
      this.logger.log(`🎵 Mismo género + relacionados: ${songs.length} canciones`);
    }

    // 🎛️ Si no hay más canciones del género, simplemente retornamos vacío
    // El caller se encargará de cambiar a MIX
    if (songs.length === 0 && totalWithGenre > 0) {
      this.logger.log(`🔀 [SAME GENRE] Se agotaron las ${totalWithGenre} canciones del género. Cambiar a MIX.`);
    }

    return songs;
  }

  /**
   * 👤 ESTRATEGIA 2: CANCIONES DEL MISMO ARTISTA
   */
  private async getSameArtistSongs(currentSong: Song, excludeIds: string[] = []): Promise<Song[]> {
    if (!currentSong.artistId) return [];

    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .where('song.artistId = :artistId', { artistId: currentSong.artistId })
      .andWhere('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.id != :currentId', { currentId: currentSong.id })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

    // 🚨 EXCLUDEIDS: Excluir IDs adicionales si se proporcionan
    if (excludeIds.length > 0) {
      query.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds });
    }

    const songs = await query
      .orderBy('song.totalStreams', 'DESC')
      .limit(15) // 🚨 FLEXIBILIZAR: Aumentado de 10 a 15 para más opciones
      .getMany();

    this.logger.log(`👤 Mismo artista: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 🔥 ESTRATEGIA 3: CANCIONES POPULARES SIMILARES
   */
  private async getPopularSimilarSongs(currentSong: Song, excludeIds: string[] = []): Promise<Song[]> {
    // Buscar canciones con streams similares (+/- 50% del actual)
    // 🚨 CORRECCIÓN CRÍTICA: Convertir a enteros para evitar error de tipo en PostgreSQL
    // PostgreSQL espera INTEGER pero estábamos enviando valores decimales (11.5, 34.5)
    const minStreams = Math.floor(Math.max(0, currentSong.totalStreams * 0.5));
    const maxStreams = Math.floor(currentSong.totalStreams * 1.5);

    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.id != :currentId', { currentId: currentSong.id })
      .andWhere('song.totalStreams BETWEEN :minStreams AND :maxStreams', {
        minStreams,
        maxStreams
      })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

    // 🚨 EXCLUDEIDS: Excluir IDs adicionales si se proporcionan
    if (excludeIds.length > 0) {
      query.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds });
    }

    const songs = await query
      .orderBy('song.totalStreams', 'DESC')
      .limit(15) // 🚨 FLEXIBILIZAR: Aumentado de 10 a 15 para más opciones
      .getMany();

    this.logger.log(`🔥 Populares similares: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 📊 ESTRATEGIA 4: BASADO EN HISTORIAL DE USUARIO
   * Collaborative Filtering básico
   */
  private async getUserBasedRecommendations(userId: string, currentSong: Song, excludeIds: string[] = []): Promise<Song[]> {
    // Obtener géneros más escuchados por el usuario
    const userGenres = await this.playHistoryRepository.createQueryBuilder('history')
      .leftJoin('history.song', 'song')
      .where('history.userId = :userId', { userId })
      .andWhere('song.genres IS NOT NULL')
      .select('song.genres')
      .getRawMany();

    // Extraer y contar géneros
    const genreCount = new Map<string, number>();
    userGenres.forEach(row => {
      if (row.song_genres) {
        const genres = Array.isArray(row.song_genres) ? row.song_genres : [row.song_genres];
        genres.forEach(genre => {
          genreCount.set(genre, (genreCount.get(genre) || 0) + 1);
        });
      }
    });

    // Obtener top 3 géneros del usuario
    const topGenres = Array.from(genreCount.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([genre]) => genre);

    if (topGenres.length === 0) return [];

    // Buscar canciones de los géneros favoritos del usuario
    const songs = await this.getSameGenreSongs(currentSong, topGenres, excludeIds, false); // No detectar loop en fallback

    this.logger.log(`📊 Basado en usuario: ${songs.length} canciones (géneros: ${topGenres.join(', ')})`);
    return songs;
  }

  /**
   * 📈 ESTRATEGIA 5: CANCIONES TRENDING
   */
  private async getTrendingSongs(genres?: string[], excludeIds: string[] = []): Promise<Song[]> {
    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .leftJoinAndSelect('song.genre', 'genre') // 🎛️ Cargar género
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.createdAt >= :recentDate', {
        recentDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // Últimos 30 días
      })
      .andWhere('song.fileUrl IS NOT NULL');

    // 🚨 EXCLUDEIDS: Excluir IDs adicionales si se proporcionan
    if (excludeIds.length > 0) {
      query.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds });
    }

    // 🎛️ VIBE SELECTOR: Filtrar por género (array + relación)
    if (genres && genres.length > 0) {
      const genreConditions = genres.map((_, index) =>
        `(LOWER(song.genres) LIKE :trendGenre${index} OR LOWER(genre.name) = :trendGenreName${index})`
      ).join(' OR ');

      query.andWhere(`(${genreConditions})`);
      genres.forEach((genre, index) => {
        query.setParameter(`trendGenre${index}`, `%${genre.toLowerCase()}%`);
        query.setParameter(`trendGenreName${index}`, genre.toLowerCase());
      });
    }

    const songs = await query
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
      .orderBy('song.totalStreams', 'DESC')
      .limit(5)
      .getMany();

    this.logger.log(`📈 Trending: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 🧮 SCORING INTELIGENTE - EL CORAZÓN DEL ALGORITMO
   * Similar al algoritmo de Spotify que combina múltiples factores
   * 🚨 LOOP DETECTION: Ajusta pesos dinámicamente cuando detecta loops
   */
  private async applySimilarityScoring(
    currentSong: Song,
    candidates: Song[],
    userId?: string,
    loopDetected: boolean = false // 🚨 LOOP DETECTION: Flag para ajustar pesos
  ): Promise<ScoredSong[]> {
    const scoredSongs: ScoredSong[] = [];

    // 🚨 LOOP DETECTION: Ajustar pesos cuando detecta loops
    // Reducir peso de semilla (género/artista) y aumentar peso de diversidad (novedad/diferentes géneros)
    const genreWeight = loopDetected ? 0.15 : 0.30; // Reducir de 30% a 15%
    const popularityWeight = loopDetected ? 0.10 : 0.20; // Reducir de 20% a 10%
    const artistWeight = loopDetected ? 0.05 : 0.10; // Reducir de 10% a 5%
    const noveltyWeight = loopDetected ? 0.40 : 0.20; // Aumentar de 20% a 40%
    const diversityWeight = loopDetected ? 0.30 : 0.20; // Aumentar de 20% a 30% (afinidad + diversidad)

    if (loopDetected) {
      this.logger.warn(`🔄 [SCORING] Modo diversidad activado: Género=${genreWeight}, Popularidad=${popularityWeight}, Artista=${artistWeight}, Novedad=${noveltyWeight}, Diversidad=${diversityWeight}`);
    }

    for (const candidate of candidates) {
      let score = 0;
      const factors: ScoreFactor[] = [];

      // Factor 1: Similitud de género (peso ajustado dinámicamente)
      const genreScore = this.calculateGenreSimilarity(currentSong, candidate);
      score += genreScore * genreWeight;
      factors.push({ name: 'género', score: genreScore, weight: genreWeight });

      // Factor 2: Popularidad relativa (peso ajustado dinámicamente)
      const popularityScore = this.calculatePopularityScore(currentSong, candidate);
      score += popularityScore * popularityWeight;
      factors.push({ name: 'popularidad', score: popularityScore, weight: popularityWeight });

      // Factor 3: Mismo artista (peso ajustado dinámicamente)
      const artistScore = currentSong.artistId === candidate.artistId ? 1 : 0;
      score += artistScore * artistWeight;
      factors.push({ name: 'artista', score: artistScore, weight: artistWeight });

      // Factor 4: Novedad (peso aumentado cuando detecta loops)
      const noveltyScore = this.calculateNoveltyScore(candidate);
      score += noveltyScore * noveltyWeight;
      factors.push({ name: 'novedad', score: noveltyScore, weight: noveltyWeight });

      // Factor 5: Afinidad de usuario + Diversidad (peso aumentado cuando detecta loops)
      const userScore = userId ? await this.calculateUserAffinityScore(userId, candidate) : 0.5;
      // 🚨 DIVERSIDAD: Penalizar canciones del mismo género cuando detecta loops
      const diversityBonus = loopDetected && genreScore > 0.5 ? -0.2 : 0; // Penalizar alta similitud de género
      const finalUserScore = Math.max(0, userScore + diversityBonus);
      score += finalUserScore * diversityWeight;
      factors.push({ name: 'afinidad', score: finalUserScore, weight: diversityWeight });

      scoredSongs.push({
        song: candidate,
        score: Math.min(1, Math.max(0, score)), // Normalizar entre 0 y 1
        factors,
      });
    }

    // Ordenar por score descendente
    scoredSongs.sort((a, b) => b.score - a.score);

    // Log de los top 5
    this.logger.log(`🧮 Top 5 recomendaciones:`);
    scoredSongs.slice(0, 5).forEach((item, index) => {
      const factorDetails = item.factors.map(f => `${f.name}:${(f.score * f.weight).toFixed(2)}`).join(', ');
      this.logger.log(`  ${index + 1}. ${item.song.title} (score: ${item.score.toFixed(3)}) [${factorDetails}]`);
    });

    return scoredSongs;
  }

  /**
   * 🎵 CALCULAR SIMILITUD DE GÉNERO
   */
  private calculateGenreSimilarity(song1: Song, song2: Song): number {
    const genres1 = song1.genres || [];
    const genres2 = song2.genres || [];

    if (genres1.length === 0 || genres2.length === 0) return 0;

    // Calcular intersección de géneros
    const intersection = genres1.filter(g1 =>
      genres2.some(g2 => g2.toLowerCase().includes(g1.toLowerCase()) ||
        g1.toLowerCase().includes(g2.toLowerCase()))
    );

    // Jaccard similarity
    const union = [...new Set([...genres1, ...genres2])];
    return intersection.length / union.length;
  }

  /**
   * 🔥 CALCULAR SCORE DE POPULARIDAD
   */
  private calculatePopularityScore(currentSong: Song, candidate: Song): number {
    const maxStreams = Math.max(currentSong.totalStreams, candidate.totalStreams, 1);
    const minStreams = Math.min(currentSong.totalStreams, candidate.totalStreams);

    // Score más alto para canciones con popularidad similar
    return minStreams / maxStreams;
  }

  /**
   * ✨ CALCULAR SCORE DE NOVEDAD
   */
  private calculateNoveltyScore(song: Song): number {
    if (!song.createdAt) return 0.5;

    const daysSinceCreation = (Date.now() - song.createdAt.getTime()) / (1000 * 60 * 60 * 24);

    // Score más alto para canciones más recientes (últimos 30 días)
    if (daysSinceCreation <= 7) return 1; // Muy nueva
    if (daysSinceCreation <= 30) return 0.8; // Nueva
    if (daysSinceCreation <= 90) return 0.6; // Reciente
    return 0.4; // Antigua
  }

  /**
   * 👤 CALCULAR AFINIDAD DE USUARIO
   * Mejorado para consultar correctamente el historial de reproducciones
   */
  private async calculateUserAffinityScore(userId: string, candidate: Song): Promise<number> {
    try {
      // Verificar si el usuario ya escuchó canciones del mismo artista
      const artistPlays = await this.playHistoryRepository
        .createQueryBuilder('history')
        .leftJoin('history.song', 'song')
        .where('history.userId = :userId', { userId })
        .andWhere('song.artistId = :artistId', { artistId: candidate.artistId })
        .getCount();

      // Verificar si el usuario escuchó canciones del mismo género
      let genrePlays = 0;
      if (candidate.genres && candidate.genres.length > 0) {
        // Buscar canciones con géneros similares en el historial del usuario
        const genreQuery = this.playHistoryRepository
          .createQueryBuilder('history')
          .leftJoin('history.song', 'song')
          .where('history.userId = :userId', { userId });

        const genreConditions = candidate.genres.map((_, index) =>
          `LOWER(song.genres) LIKE :genre${index}`
        ).join(' OR ');

        genreQuery.andWhere(`(${genreConditions})`);

        // Aplicar parámetros de géneros
        candidate.genres.forEach((genre, index) => {
          genreQuery.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
        });

        genrePlays = await genreQuery.getCount();
      }

      // Combinar factores con normalización mejorada
      const artistAffinity = Math.min(1, artistPlays / 5); // Normalizar: 5+ reproducciones = score máximo
      const genreAffinity = Math.min(1, genrePlays / 20); // Normalizar: 20+ reproducciones = score máximo

      const finalScore = (artistAffinity * 0.6 + genreAffinity * 0.4);

      this.logger.log(`👤 Afinidad usuario: artista=${artistPlays} (${artistAffinity.toFixed(2)}), género=${genrePlays} (${genreAffinity.toFixed(2)}), final=${finalScore.toFixed(2)}`);

      return finalScore;
    } catch (error) {
      this.logger.error(`❌ Error calculando afinidad de usuario: ${error.message}`);
      return 0.5; // Score neutro en caso de error
    }
  }

  /**
   * 🎯 SELECCIONAR MEJOR RECOMENDACIÓN
   * ✅ MEJORA #2: Aplica diversidad forzada y anti-repetición mejorada
   */
  private selectBestRecommendation(scoredSongs: ScoredSong[], userId?: string, recentHistory: Song[] = []): Song | null {
    if (scoredSongs.length === 0) return null;

    // Aplicar diversidad: considerar más candidatos para mayor variedad
    const topCandidates = scoredSongs.slice(0, Math.min(8, scoredSongs.length));

    // ✅ MEJORA #2: DIVERSIDAD FORZADA - Penalizar canciones del mismo artista/género que las recientes
    const last2Artists = recentHistory.slice(-2).map(s => s.artistId);
    const last2Genres = recentHistory.slice(-2).flatMap(s => s.genres || []).map(g => g.toLowerCase());

    const diversified = topCandidates.map(scored => {
      const song = scored.song;
      let penalty = 0;

      // Penalizar si es del mismo artista que las últimas 2 canciones
      if (last2Artists.includes(song.artistId)) {
        penalty += 0.3;
        this.logger.debug(`🎯 [DIVERSIDAD] Penalizando ${song.title}: mismo artista que recientes (penalización: +${penalty})`);
      }

      // Penalizar si comparte todos los géneros con las últimas 2 canciones
      if (song.genres && song.genres.length > 0) {
        const songGenres = new Set(song.genres.map(g => g.toLowerCase()));
        const allGenresMatch = last2Genres.length > 0 &&
          Array.from(songGenres).every(g => last2Genres.includes(g)) &&
          last2Genres.every(g => songGenres.has(g));

        if (allGenresMatch) {
          penalty += 0.2;
          this.logger.debug(`🎯 [DIVERSIDAD] Penalizando ${song.title}: mismos géneros que recientes (penalización: +${penalty})`);
        }
      }

      // Crear objeto con score penalizado y original para logging
      const diversifiedItem = {
        song: scored.song,
        score: Math.max(0, scored.score - penalty), // Aplicar penalización
        factors: scored.factors,
        originalScore: scored.score, // Guardar score original para logging
      };
      return diversifiedItem;
    }).sort((a, b) => b.score - a.score); // Re-ordenar después de penalización

    // Estrategia de selección más diversa
    const selectionStrategy = Math.random();

    if (selectionStrategy < 0.6) {
      // 60% - Mejor score después de penalización (favorece diversidad)
      const selected = diversified[0];
      this.logger.log(`🎯 Seleccionada (diversidad forzada): ${selected.song.title} (score: ${selected.originalScore.toFixed(3)} → ${selected.score.toFixed(3)} después de penalización)`);
      return selected.song;
    } else if (selectionStrategy < 0.9) {
      // 30% - Segundo mejor (después de penalización)
      const selected = diversified[1] || diversified[0];
      this.logger.log(`🎯 Seleccionada (segundo mejor diverso): ${selected.song.title} (score: ${selected.originalScore.toFixed(3)} → ${selected.score.toFixed(3)})`);
      return selected.song;
    } else {
      // 10% - Aleatorio del top 5 (después de penalización)
      const top5 = diversified.slice(0, Math.min(5, diversified.length));
      const selected = top5[Math.floor(Math.random() * top5.length)];
      this.logger.log(`🎯 Seleccionada (random diverso): ${selected.song.title} (score: ${selected.originalScore.toFixed(3)} → ${selected.score.toFixed(3)})`);
      return selected.song;
    }
  }

  /**
   * 🔄 DEDUPLICAR CANCIONES
   */
  private deduplicateSongs(songs: Song[], excludeId: string): Song[] {
    const seen = new Set<string>([excludeId]);
    return songs.filter(song => {
      if (seen.has(song.id)) return false;
      seen.add(song.id);
      return true;
    });
  }

  /**
   * 📝 GESTIÓN DE HISTORIAL DE CANCIONES RECIENTES
   */
  private addToRecentHistory(userId: string, songId: string): void {
    const history = this.recentSongsHistory.get(userId) || {
      songs: [],
      lastUpdated: Date.now()
    };

    // Agregar canción al inicio del historial
    history.songs.unshift(songId);

    // Mantener solo las últimas N canciones
    if (history.songs.length > this.HISTORY_SIZE) {
      history.songs = history.songs.slice(0, this.HISTORY_SIZE);
    }

    history.lastUpdated = Date.now();
    this.recentSongsHistory.set(userId, history);

    this.logger.log(`📝 Historial actualizado para ${userId}: ${history.songs.length} canciones recientes`);
  }

  private getRecentHistory(userId: string): string[] {
    const history = this.recentSongsHistory.get(userId);

    if (!history) return [];

    // Verificar si el historial ha expirado
    if (Date.now() - history.lastUpdated > this.HISTORY_TTL) {
      this.recentSongsHistory.delete(userId);
      return [];
    }

    return history.songs;
  }

  /**
   * ✅ MEJORA #2: Obtener canciones completas del historial reciente
   * Para usar en diversidad forzada
   */
  private async getRecentSongsFromHistory(userId: string, limit: number = 3): Promise<Song[]> {
    const recentIds = this.getRecentHistory(userId);
    if (recentIds.length === 0) return [];

    try {
      const songs = await this.songRepository
        .createQueryBuilder('song')
        .select(['song.id', 'song.artistId', 'song.genres', 'song.title'])
        .where('song.id IN (:...ids)', { ids: recentIds.slice(0, limit) })
        .getMany();

      return songs;
    } catch (error) {
      this.logger.error(`❌ Error obteniendo canciones del historial: ${error.message}`);
      return [];
    }
  }

  private cleanupExpiredHistory(): void {
    const now = Date.now();
    for (const [userId, history] of this.recentSongsHistory.entries()) {
      if (now - history.lastUpdated > this.HISTORY_TTL) {
        this.recentSongsHistory.delete(userId);
      }
    }
  }

  /**
   * ⚡ GESTIÓN DE CACHE
   * ✅ MEJORA #3: Cache inteligente con invalidación por exclusión
   */
  private generateCacheKey(currentSongId: string, genres?: string[], userId?: string, offset?: number, excludeCount?: number): string {
    const genresStr = genres?.join(',') || '';
    const userStr = userId || 'anon';
    // 🎲 Agregar factor de variación basado en tiempo (cambia cada minuto)
    // Esto permite que el cache tenga más variedad sin perder eficiencia
    const timeWindow = Math.floor(Date.now() / (60 * 1000)); // Ventana de 1 minuto
    // 🚨 OFFSET: Incluir offset en la clave para romper cache en llamadas paralelas
    // El offset NO afecta la lógica de recomendación, solo la clave de cache
    const offsetStr = offset !== undefined ? `:offset${offset}` : '';
    // ✅ MEJORA #3: Incluir cantidad de exclusiones en la clave (granularidad mejorada)
    // Esto permite tener diferentes caches según el contexto de exclusiones
    const excludeStr = excludeCount !== undefined ? `:ex${Math.min(excludeCount, 20)}` : ''; // Limitar a 20 para no crear demasiadas variantes
    return `rec:${currentSongId}:${genresStr}:${userStr}:${timeWindow}${offsetStr}${excludeStr}`;
  }

  /**
   * ✅ MEJORA #3: Determinar si el cache debe invalidarse
   * Si hay demasiadas exclusiones, el cache probablemente está obsoleto
   */
  private shouldInvalidateCache(excludeIds: string[]): boolean {
    // Si hay más de 20 exclusiones, el cache probablemente está obsoleto
    // Esto es especialmente importante cuando el usuario ha saltado muchas canciones
    return excludeIds.length > 20;
  }

  private getCachedRecommendation(key: string): Song | null {
    const cached = this.recommendationCache.get(key);
    if (!cached) return null;

    if (Date.now() - cached.timestamp > this.CACHE_TTL) {
      this.recommendationCache.delete(key);
      return null;
    }

    return cached.song;
  }

  private cacheRecommendation(key: string, song: Song): void {
    this.recommendationCache.set(key, {
      song,
      timestamp: Date.now(),
    });

    // Limpiar cache antiguo (simple LRU)
    if (this.recommendationCache.size > 1000) {
      const oldestKey = this.recommendationCache.keys().next().value;
      this.recommendationCache.delete(oldestKey);
    }
  }

  /**
   * 🚀 GENERAR BATCH DE RECOMENDACIONES (NUEVO ENDPOINT OPTIMIZADO)
   * Reemplaza múltiples llamadas frontend por una sola llamada backend
   * El backend maneja internamente el batching y la variedad
   * 🎛️ VIBE SELECTOR: Soporte para filtrar por género específico
   * @returns BatchResult con canciones y metadata de cambio a MIX
   */
  async generatePlaylistBatch(
    seedSongId: string,
    count: number = 4,
    userId?: string,
    genres?: string[],
    excludeIds: string[] = [],
    genreId?: string, // 🎛️ Género específico del Vibe Selector
  ): Promise<BatchResult> {
    const startTime = Date.now();

    // 🎛️ VIBE SELECTOR: Rastrear si hubo cambio a MIX
    let vibeChangedToMix = false;
    let originalGenre: string | undefined;

    this.logger.log(`🚀 [BATCH] Generando ${count} recomendaciones para semilla: ${seedSongId}${genreId ? ` (género ID: ${genreId})` : ''}`);
    this.logger.log(`👤 [BATCH] Usuario: ${userId || 'anónimo'}`);
    this.logger.log(`🚫 [BATCH] Excluyendo ${excludeIds.length} IDs: ${excludeIds.slice(0, 5).map(id => id.substring(0, 8)).join(', ')}${excludeIds.length > 5 ? '...' : ''}`);
    this.logger.log(`🎛️ [BATCH] Géneros recibidos: ${genres ? `[${genres.join(', ')}]` : 'NINGUNO'}, genreId: ${genreId || 'NINGUNO'}`);

    // Guardar el género original para detectar cambio a MIX
    if (genreId) {
      originalGenre = genreId;
    }

    // 🎛️ VIBE SELECTOR: If genreId is present, it MUST be a UUID. If it's not a valid UUID
    // (e.g. frontend accidentally sent a name like 'pop'), ignore it and fall back
    // to searching by `genres` (names).
    let effectiveGenres = genres;
    let totalSongsInGenre = 0; // Para threshold dinámico
    if (genreId) {
      if (!this.isValidUuid(genreId)) {
        this.logger.warn(`🎛️ [VIBE SELECTOR] genreId provided is not a valid UUID ('${genreId}'). Ignoring and using genres names instead.`);
        genreId = undefined;
      }
    }
    if (genreId) {
      try {
        const genre = await this.genreRepository.findOne({ where: { id: genreId } });
        if (genre) {
          effectiveGenres = [genre.name];
          originalGenre = genre.name; // Guardar nombre para el log
          this.logger.log(`🎛️ [VIBE SELECTOR] ✅ Género resuelto: ${genre.name} (ID: ${genreId})`);
          this.logger.log(`🎛️ [VIBE SELECTOR] ✅ effectiveGenres ahora es: [${effectiveGenres.join(', ')}]`);

          // 📊 Contar canciones totales del género para threshold adaptativo
          const genreNameLower = genre.name.toLowerCase();
          const countQuery = this.songRepository.createQueryBuilder('song')
            .leftJoin('song.genre', 'genre')
            .where('song.status = :status', { status: 'published' })
            .andWhere('song.fileUrl IS NOT NULL')
            .andWhere('song.fileUrl != \'\'')
            .andWhere(`(LOWER(song.genres) LIKE :genrePattern OR LOWER(genre.name) = :genreName)`, {
              genrePattern: `%${genreNameLower}%`,
              genreName: genreNameLower
            });

          totalSongsInGenre = await countQuery.getCount();
          this.logger.log(`🎛️ [VIBE SELECTOR] 📊 Total canciones en género "${genre.name}": ${totalSongsInGenre}`);
        } else {
          this.logger.warn(`🎛️ [VIBE SELECTOR] ⚠️ Género no encontrado para ID: ${genreId}, usando géneros por defecto`);
        }
      } catch (e) {
        this.logger.error(`🎛️ [VIBE SELECTOR] ❌ Error resolviendo género: ${e.message}`);
      }
    }

    try {
      // 🚨 CATÁLOGO PEQUEÑO: Detectar tamaño del catálogo disponible
      const totalSongs = await this.getTotalAvailableSongs();
      this.logger.log(`📊 [BATCH] Catálogo disponible: ${totalSongs} canciones totales`);

      // 🚨 CATÁLOGO PEQUEÑO: Si el catálogo es pequeño, reducir exclusiones agresivas
      // Estrategia adaptativa basada en el tamaño del catálogo
      const adaptiveExcludeLimit = this.getAdaptiveExcludeLimit(totalSongs, excludeIds.length);

      // Mantener solo los excludeIds más recientes (últimos N) para catálogos pequeños
      const effectiveExcludeIds = excludeIds.slice(-adaptiveExcludeLimit);
      this.logger.log(`🎯 [BATCH] Exclusión adaptativa: ${effectiveExcludeIds.length}/${excludeIds.length} IDs (límite: ${adaptiveExcludeLimit} para catálogo de ${totalSongs})`);

      const recommendations: Song[] = [];
      const usedIds = new Set<string>([seedSongId, ...effectiveExcludeIds]);
      let failedAttempts = 0;
      const maxFailedAttempts = 3; // Intentar 3 veces antes de reducir exclusiones

      // 🚨 DETECCIÓN DE LOOPS: Rastrear canciones devueltas repetidamente
      const returnedSongsCount = new Map<string, number>(); // ID -> número de veces devuelto
      let loopDetected = false;

      // ⚡️ OPTIMIZACIÓN: Estrategia Híbrida de Paralelización
      // Para catálogos grandes: paralelización TOTAL (máxima velocidad - estilo Gemini)
      // Para catálogos medianos: paralelización en LOTES (balance velocidad/variedad)
      // Para catálogos pequeños: secuencial (máxima robustez)
      const shouldParallelizeTotal = totalSongs > 50 && count >= 3; // Catálogo grande: paralelización total
      const shouldParallelizeBatches = totalSongs > 20 && count >= 3; // Catálogo mediano: lotes paralelos

      if (shouldParallelizeTotal) {
        // 🚀 MODO PARALELO TOTAL (Estilo Gemini - Máxima Velocidad)
        this.logger.log(`⚡️ [BATCH] Modo paralelo TOTAL activado (catálogo: ${totalSongs}, count: ${count}) - Máxima velocidad`);
        const parallelResults = await this.generateParallelBatchTotal(
          seedSongId,
          count,
          effectiveExcludeIds,
          usedIds,
          userId,
          effectiveGenres // 🎛️ VIBE SELECTOR: usar géneros filtrados
        );
        recommendations.push(...parallelResults);
      } else if (shouldParallelizeBatches) {
        // 🚀 MODO PARALELO EN LOTES (Balance Velocidad/Variedad)
        this.logger.log(`⚡️ [BATCH] Modo paralelo en LOTES activado (catálogo: ${totalSongs}, count: ${count}) - Balance velocidad/variedad`);
        const parallelResults = await this.generateParallelBatch(
          seedSongId,
          count,
          effectiveExcludeIds,
          usedIds,
          userId,
          effectiveGenres // 🎛️ VIBE SELECTOR: usar géneros filtrados
        );
        recommendations.push(...parallelResults);
      } else {
        // 🔗 MODO SECUENCIAL: Generar recomendaciones en cadena (mejor para catálogos pequeños)
        this.logger.log(`🔗 [BATCH] Modo secuencial activado (catálogo: ${totalSongs}, count: ${count})`);
        let currentSeedId = seedSongId;

        for (let i = 0; i < count; i++) {
          // Convertir usedIds a array para pasarlo como excludeIds
          let currentExcludeIds = Array.from(usedIds);

          // 🚨 CATÁLOGO PEQUEÑO: Reducir exclusiones si hay muchos fallos
          if (failedAttempts >= maxFailedAttempts && currentExcludeIds.length > adaptiveExcludeLimit) {
            // Mantener solo las exclusiones más recientes
            currentExcludeIds = [seedSongId, ...recommendations.slice(-3).map(r => r.id), ...effectiveExcludeIds];
            this.logger.log(`🔄 [BATCH] Reduciendo exclusiones a ${currentExcludeIds.length} (últimas 3 recomendaciones + semilla)`);
            failedAttempts = 0; // Reset contador
          }

          // 🚨 DETECCIÓN DE LOOPS: Verificar si estamos devolviendo las mismas canciones
          // Si una canción se devuelve 2+ veces, activar modo diversidad
          const recentReturned = Array.from(returnedSongsCount.entries())
            .filter(([_, count]) => count >= 2)
            .map(([id, _]) => id);

          if (recentReturned.length >= 2) {
            loopDetected = true;
            this.logger.warn(`🔄 [BATCH] LOOP DETECTADO: ${recentReturned.length} canciones devueltas repetidamente. Activando modo diversidad...`);
          }

          // Obtener una recomendación usando la semilla actual con excludeIds
          // Pasar información de loop para ajustar scoring dinámicamente
          const recommended = await this.getRecommendedSong(
            currentSeedId,
            userId,
            effectiveGenres, // 🎛️ VIBE SELECTOR: usar géneros filtrados
            i, // Usar índice como offset para variar cache (solo afecta cache, no lógica)
            currentExcludeIds, // 🚨 EXCLUDEIDS: Pasar IDs ya usados (ajustados para catálogo pequeño)
            loopDetected // 🚨 LOOP DETECTION: Pasar flag para ajustar scoring
          );

          // 🚨 DETECCIÓN DE LOOPS: Rastrear canciones devueltas
          if (recommended) {
            const currentCount = returnedSongsCount.get(recommended.id) || 0;
            returnedSongsCount.set(recommended.id, currentCount + 1);

            if (currentCount >= 1) {
              this.logger.warn(`🔄 [BATCH] Canción devuelta ${currentCount + 1} veces: ${recommended.title} (ID: ${recommended.id.substring(0, 8)}...)`);
            }
          }

          if (!recommended) {
            failedAttempts++;
            this.logger.warn(`⚠️ [BATCH] No se encontró recomendación ${i + 1}/${count} con excludeIds (${currentExcludeIds.length} excluidos, intento ${failedAttempts}/${maxFailedAttempts})`);

            // Si no hay recomendación, intentar con la semilla original
            if (currentSeedId !== seedSongId) {
              currentSeedId = seedSongId;
              const fallback = await this.getRecommendedSong(
                seedSongId,
                userId,
                effectiveGenres, // 🎛️ VIBE SELECTOR: usar géneros filtrados
                i + 100, // Offset diferente para evitar cache
                currentExcludeIds, // 🚨 EXCLUDEIDS: Mantener excludeIds en fallback
                loopDetected // 🚨 LOOP DETECTION: Pasar flag
              );

              if (fallback && !usedIds.has(fallback.id)) {
                recommendations.push(fallback);
                usedIds.add(fallback.id);
                currentSeedId = fallback.id; // Usar como nueva semilla
                failedAttempts = 0; // Reset contador
                this.logger.log(`✅ [BATCH] Recomendación ${i + 1}/${count} (fallback con semilla original): ${fallback.title} (ID: ${fallback.id.substring(0, 8)}...)`);
                continue;
              }
            }

            // 🚨 CATÁLOGO PEQUEÑO: Si aún no hay resultado, intentar con exclusiones mínimas (solo semilla)
            if (failedAttempts >= maxFailedAttempts) {
              this.logger.log(`🔄 [BATCH] Intentando con exclusión mínima (solo semilla) debido a catálogo pequeño...`);
              const minimalExclude = [seedSongId];
              const minimalFallback = await this.getRecommendedSong(
                currentSeedId,
                userId,
                effectiveGenres, // 🎛️ VIBE SELECTOR: usar géneros filtrados
                i + 200,
                minimalExclude,
                loopDetected // 🚨 LOOP DETECTION: Pasar flag
              );

              if (minimalFallback) {
                // Permitir duplicados si es necesario (mejor que no recomendar nada)
                if (!recommendations.some(r => r.id === minimalFallback.id)) {
                  recommendations.push(minimalFallback);
                  usedIds.add(minimalFallback.id);
                  currentSeedId = minimalFallback.id;
                  failedAttempts = 0;
                  this.logger.log(`✅ [BATCH] Recomendación ${i + 1}/${count} (modo catálogo pequeño): ${minimalFallback.title} (ID: ${minimalFallback.id.substring(0, 8)}...)`);
                  continue;
                }
              }
            }

            // Si aún no hay resultado, saltar esta iteración
            this.logger.warn(`⚠️ [BATCH] No se pudo generar recomendación ${i + 1}/${count} después de todos los intentos`);
            continue;
          }

          failedAttempts = 0; // Reset contador si hay éxito

          // 🚨 VALIDACIÓN CRÍTICA: Verificar que la recomendación NO esté en excludeIds
          if (usedIds.has(recommended.id)) {
            this.logger.error(`❌ [BATCH] ERROR CRÍTICO: Recomendación ${i + 1} está en excludeIds/usedIds: ${recommended.title} (ID: ${recommended.id.substring(0, 8)}...). DESCARTANDO.`);
            // Intentar obtener una alternativa con exclusiones más estrictas
            failedAttempts++;
            const strictExcludeIds = Array.from(usedIds);
            const alternative = await this.getRecommendedSong(
              currentSeedId,
              userId,
              effectiveGenres, // 🎛️ VIBE SELECTOR: usar géneros filtrados
              i + 300, // Offset muy alto para evitar cache
              strictExcludeIds,
              loopDetected // 🚨 LOOP DETECTION: Pasar flag
            );

            if (alternative && !usedIds.has(alternative.id)) {
              recommendations.push(alternative);
              usedIds.add(alternative.id);
              currentSeedId = alternative.id;
              failedAttempts = 0;
              this.logger.log(`✅ [BATCH] Alternativa encontrada para ${i + 1}/${count}: ${alternative.title} (ID: ${alternative.id.substring(0, 8)}...)`);
              continue;
            }

            this.logger.warn(`⚠️ [BATCH] No se pudo encontrar alternativa para ${i + 1}/${count}`);
            continue;
          }

          // Agregar recomendación válida
          recommendations.push(recommended);
          usedIds.add(recommended.id);

          // 🎯 Usar la recomendación como semilla para la siguiente iteración (cadena)
          // Esto garantiza variedad progresiva
          currentSeedId = recommended.id;

          this.logger.log(`✅ [BATCH] Recomendación ${i + 1}/${count}: ${recommended.title} (ID: ${recommended.id.substring(0, 8)}...)`);
        }
      }

      // 🚨 VALIDACIÓN FINAL CRÍTICA: Asegurar que ninguna recomendación esté en excludeIds EFECTIVOS
      // IMPORTANTE: Usar effectiveExcludeIds (reducidos por exclusión adaptativa), NO los originales
      // Esto es crítico porque para catálogos pequeños, la exclusión adaptativa reduce los excludeIds
      // para evitar agotar el catálogo. La validación final debe ser consistente con esta lógica.
      const finalExcludeSet = new Set<string>([seedSongId, ...effectiveExcludeIds]);

      const finalRecommendations = recommendations.filter(song => {
        const isInFinalExcludeSet = finalExcludeSet.has(song.id);

        if (isInFinalExcludeSet) {
          this.logger.error(`❌ [BATCH VALIDACIÓN FINAL] Eliminando canción EXCLUIDA: ${song.title} (ID: ${song.id.substring(0, 8)}...) - está en set final (semilla + effectiveExcludeIds)`);
          return false;
        }
        return true;
      });

      // 🚨 VALIDACIÓN ADICIONAL: Verificar que no haya duplicados en las recomendaciones finales
      const uniqueRecommendations: Song[] = [];
      const seenIds = new Set<string>();
      for (const song of finalRecommendations) {
        if (seenIds.has(song.id)) {
          this.logger.warn(`⚠️ [BATCH VALIDACIÓN FINAL] Duplicado detectado y eliminado: ${song.title} (ID: ${song.id.substring(0, 8)}...)`);
          continue;
        }
        seenIds.add(song.id);
        uniqueRecommendations.push(song);

        // 🎛️ VIBE SELECTOR: Detectar si alguna canción vino del fallback MIX
        if ((song as any).__vibeChangedToMix) {
          vibeChangedToMix = true;
          if ((song as any).__originalGenre) {
            originalGenre = (song as any).__originalGenre;
          }
          // Limpiar las propiedades temporales
          delete (song as any).__vibeChangedToMix;
          delete (song as any).__originalGenre;
        }
      }

      const duration = Date.now() - startTime;
      const eliminatedCount = recommendations.length - uniqueRecommendations.length;
      if (eliminatedCount > 0) {
        this.logger.warn(`⚠️ [BATCH] ${eliminatedCount} recomendaciones eliminadas por validación (duplicados/excluidas)`);
      }

      // 🎛️ SIMPLIFICADO: NO forzar cambio a MIX - permitir repeticiones en géneros
      // El usuario debe cambiar manualmente a MIX si quiere variedad
      // Los géneros específicos pueden repetirse infinitamente
      let shouldSwitchToMix = false;

      if (vibeChangedToMix) {
        this.logger.warn(`🎛️ [BATCH] ⚠️ VIBE CAMBIÓ A MIX: Se agotaron las canciones de "${originalGenre}"`);
      }

      this.logger.log(`🚀 [BATCH] Completado en ${duration}ms: ${uniqueRecommendations.length}/${count} recomendaciones generadas`);

      return {
        songs: uniqueRecommendations.slice(0, count),
        vibeChangedToMix,
        originalGenre,
      };

    } catch (error) {
      this.logger.error(`❌ [BATCH] Error generando batch: ${error.message}`, error.stack);
      return { songs: [], vibeChangedToMix: false };
    }
  }

  /**
   * 📊 OBTENER TOTAL DE CANCIONES DISPONIBLES EN EL CATÁLOGO
   * Usado para ajustar estrategias cuando el catálogo es pequeño
   */
  private async getTotalAvailableSongs(): Promise<number> {
    try {
      const count = await this.songRepository.count({
        where: {
          status: SongStatus.PUBLISHED,
          fileUrl: Not(''),
        },
      });
      return count;
    } catch (error) {
      this.logger.error(`❌ Error contando canciones disponibles: ${error.message}`);
      return 0;
    }
  }

  /**
   * 🎯 CALCULAR LÍMITE ADAPTATIVO DE EXCLUSIONES
   * Ajusta dinámicamente cuántos IDs excluir basándose en el tamaño del catálogo
   */
  private getAdaptiveExcludeLimit(totalSongs: number, requestedExcludes: number): number {
    // Si hay muchas canciones, usar todas las exclusiones solicitadas
    if (totalSongs >= 50) {
      return requestedExcludes;
    }

    // 🚨 PLAN DE CHOQUE: Para catálogos < 50, ser MUY permisivo
    // Excluir solo las últimas 3-5 canciones para permitir que el algoritmo "muerda"
    // canciones anteriores rápidamente (re-comendación circular)
    return Math.min(5, requestedExcludes);
  }

  /**
   * 🔎 Validar UUID simple (acepta versiones hex con guiones)
   */
  private isValidUuid(id?: string): boolean {
    if (!id || typeof id !== 'string') return false;
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
  }

  /**
   * ⚡️ GENERAR BATCH EN PARALELO TOTAL (Estilo Gemini - Máxima Velocidad)
   * Genera TODAS las recomendaciones simultáneamente usando Promise.all()
   * Estrategia: Misma semilla + excludeIds estático + filtrado post-proceso
   * Ideal para catálogos grandes (>50 canciones)
   */
  private async generateParallelBatchTotal(
    seedSongId: string,
    count: number,
    effectiveExcludeIds: string[],
    usedIds: Set<string>,
    userId?: string,
    genres?: string[]
  ): Promise<Song[]> {
    // 🚀 ESTRATEGIA GEMINI: Todo en paralelo con excludeIds estático
    const baseExcludeIds = Array.from(usedIds);

    // Crear array de promesas - todas con la misma semilla y excludeIds
    const recommendationPromises: Promise<Song | null>[] = [];
    for (let i = 0; i < count; i++) {
      recommendationPromises.push(
        this.getRecommendedSong(
          seedSongId, // Misma semilla para todas
          userId,
          genres,
          i, // Offset diferente para variar cache
          baseExcludeIds // ExcludeIds estático (no se actualiza durante la ejecución)
        )
      );
    }

    // ⚡️ Ejecutar TODAS las promesas en paralelo
    const results = await Promise.all(recommendationPromises);

    this.logger.log(`🔍 [BATCH PARALELO TOTAL] Resultados recibidos: ${results.length} (${results.filter(r => r !== null).length} válidos)`);

    // 🔍 Filtrar resultados y manejar duplicados post-proceso
    const finalBatch: Song[] = [];
    const batchExcludeIds = new Set<string>(baseExcludeIds);

    this.logger.log(`🚫 [BATCH PARALELO TOTAL] Excluyendo ${batchExcludeIds.size} IDs: ${Array.from(batchExcludeIds).slice(0, 5).map(id => id.substring(0, 8)).join(', ')}...`);

    for (const song of results) {
      if (!song) {
        this.logger.warn(`⚠️ [BATCH PARALELO TOTAL] Recomendación null recibida`);
        continue;
      }

      if (batchExcludeIds.has(song.id)) {
        this.logger.warn(`🚫 [BATCH PARALELO TOTAL] Recomendación descartada (en excludeIds): ${song.title} (ID: ${song.id.substring(0, 8)}...)`);
        continue;
      }

      finalBatch.push(song);
      batchExcludeIds.add(song.id); // Evitar duplicados dentro del batch
      this.logger.log(`✅ [BATCH PARALELO TOTAL] Recomendación: ${song.title} (ID: ${song.id.substring(0, 8)}...)`);
    }

    // Si hay duplicados o fallos, intentar rellenar secuencialmente
    if (finalBatch.length < count) {
      const remaining = count - finalBatch.length;
      this.logger.log(`🔄 [BATCH PARALELO TOTAL] Rellenando ${remaining} recomendaciones faltantes...`);

      for (let i = 0; i < remaining && finalBatch.length < count; i++) {
        const currentExcludeIds = Array.from(batchExcludeIds);
        const fillRecommendation = await this.getRecommendedSong(
          seedSongId,
          userId,
          genres,
          count + i + 200, // Offset alto para evitar cache
          currentExcludeIds
        );

        if (fillRecommendation && !batchExcludeIds.has(fillRecommendation.id)) {
          finalBatch.push(fillRecommendation);
          batchExcludeIds.add(fillRecommendation.id);
          this.logger.log(`✅ [BATCH PARALELO TOTAL FILL] Recomendación: ${fillRecommendation.title} (ID: ${fillRecommendation.id.substring(0, 8)}...)`);
        }
      }
    }

    return finalBatch.slice(0, count);
  }

  /**
   * ⚡️ GENERAR BATCH EN PARALELO EN LOTES (Balance Velocidad/Variedad)
   * Genera recomendaciones en lotes de 4, usando semillas variadas para mantener variedad
   * Ideal para catálogos medianos (21-50 canciones)
   */
  private async generateParallelBatch(
    seedSongId: string,
    count: number,
    effectiveExcludeIds: string[],
    usedIds: Set<string>,
    userId?: string,
    genres?: string[]
  ): Promise<Song[]> {
    const results: Song[] = [];
    const batchSize = Math.min(4, count); // Procesar máximo 4 en paralelo por lote

    // Estrategia: Dividir en lotes paralelos
    for (let batchStart = 0; batchStart < count; batchStart += batchSize) {
      const batchEnd = Math.min(batchStart + batchSize, count);
      const batchCount = batchEnd - batchStart;

      // 🚀 Generar semillas para este lote (variaciones de la semilla original)
      // Usar las recomendaciones anteriores como semillas adicionales para variedad
      const seeds: string[] = [];
      if (results.length > 0) {
        // Usar las últimas recomendaciones como semillas
        const recentSeeds = results.slice(-Math.min(2, results.length)).map(r => r.id);
        seeds.push(...recentSeeds);
      }

      // Completar con la semilla original si no hay suficientes
      while (seeds.length < batchCount) {
        seeds.push(seedSongId);
      }

      // ⚡️ Generar recomendaciones en paralelo para este lote
      const batchPromises = seeds.slice(0, batchCount).map((seed, index) => {
        const currentExcludeIds = Array.from(usedIds);
        return this.getRecommendedSong(
          seed,
          userId,
          genres,
          batchStart + index, // Offset único para cada recomendación
          currentExcludeIds
        );
      });

      const batchResults = await Promise.all(batchPromises);

      // Filtrar resultados válidos y agregar a la lista
      for (const result of batchResults) {
        if (!result) {
          this.logger.warn(`⚠️ [BATCH PARALELO] Recomendación null recibida`);
          continue;
        }

        if (usedIds.has(result.id)) {
          this.logger.warn(`🚫 [BATCH PARALELO] Recomendación descartada (en usedIds/excludeIds): ${result.title} (ID: ${result.id.substring(0, 8)}...)`);
          continue;
        }

        results.push(result);
        usedIds.add(result.id);
        this.logger.log(`✅ [BATCH PARALELO] Recomendación: ${result.title} (ID: ${result.id.substring(0, 8)}...)`);
      }

      // Si no obtuvimos suficientes, intentar con semilla original
      if (results.length < batchEnd && results.length < count) {
        const remaining = count - results.length;
        const fallbackPromises = Array(remaining).fill(null).map((_, index) => {
          const currentExcludeIds = Array.from(usedIds);
          return this.getRecommendedSong(
            seedSongId,
            userId,
            genres,
            batchStart + batchCount + index + 100, // Offset alto para evitar cache
            currentExcludeIds
          );
        });

        const fallbackResults = await Promise.all(fallbackPromises);
        for (const result of fallbackResults) {
          if (!result) {
            this.logger.warn(`⚠️ [BATCH PARALELO FALLBACK] Recomendación null recibida`);
            continue;
          }

          if (usedIds.has(result.id)) {
            this.logger.warn(`🚫 [BATCH PARALELO FALLBACK] Recomendación descartada (en usedIds/excludeIds): ${result.title} (ID: ${result.id.substring(0, 8)}...)`);
            continue;
          }

          results.push(result);
          usedIds.add(result.id);
          this.logger.log(`✅ [BATCH PARALELO FALLBACK] Recomendación: ${result.title} (ID: ${result.id.substring(0, 8)}...)`);
        }
      }
    }

    return results.slice(0, count); // Asegurar que no excedamos el count solicitado
  }
}

// Interfaces para el sistema de scoring
interface ScoredSong {
  song: Song;
  score: number;
  factors: ScoreFactor[];
}

interface ScoreFactor {
  name: string;
  score: number;
  weight: number;
}

interface CachedRecommendation {
  song: Song;
  timestamp: number;
}

interface RecentSongsHistory {
  songs: string[];
  lastUpdated: number;
}
