import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Song } from '../../common/entities/song.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { SongStatus } from '../../common/entities/song.entity';
import { Not } from 'typeorm';

/**
 * 🎵 SISTEMA DE RECOMENDACIONES ESTILO SPOTIFY
 * 
 * Algoritmos implementados:
 * 1. Content-Based Filtering (géneros, artistas, características)
 * 2. Collaborative Filtering básico (historial de usuarios)
 * 3. Popularity-Based (trending songs)
 * 4. Hybrid Approach (combinación de múltiples algoritmos)
 */
@Injectable()
export class RecommendationService {
  private readonly logger = new Logger(RecommendationService.name);
  
  // Cache en memoria para recomendaciones (en producción usar Redis)
  private readonly recommendationCache = new Map<string, CachedRecommendation>();
  private readonly CACHE_TTL = 2 * 60 * 1000; // 2 minutos (reducido para más variedad)
  
  // Historial de canciones recientes por usuario para evitar repeticiones
  private readonly recentSongsHistory = new Map<string, RecentSongsHistory>();
  private readonly HISTORY_SIZE = 5; // Recordar últimas 5 canciones (reducido para más variedad)
  private readonly HISTORY_TTL = 30 * 60 * 1000; // 30 minutos

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
  ) {
    // Limpiar historial expirado cada 10 minutos
    setInterval(() => {
      this.cleanupExpiredHistory();
    }, 10 * 60 * 1000);
  }

  /**
   * 🎯 ALGORITMO SIMPLE DE RECOMENDACIONES
   * Solo usa: Género + Número de Reproducciones
   */
  async getRecommendedSong(
    currentSongId: string, 
    userId?: string,
    genres?: string[]
  ): Promise<Song | null> {
    const startTime = Date.now();
    this.logger.log(`🎵 [SIMPLE] Iniciando recomendación simple para canción: ${currentSongId}`);

    try {
      // 1. Obtener canción actual
      const currentSong = await this.getCurrentSong(currentSongId);
      if (!currentSong) {
        this.logger.warn(`❌ Canción actual no encontrada: ${currentSongId}`);
        return null;
      }

      // 2. Obtener géneros (de parámetros o de la canción actual)
      const songGenres = genres || currentSong.genres || [];
      if (songGenres.length === 0) {
        this.logger.warn(`❌ No hay géneros disponibles para: ${currentSongId}`);
        // Si no hay géneros, buscar por popularidad general
        return await this.getPopularSongs(currentSongId, userId);
      }

      // 3. Verificar si necesitamos cambiar de género (después de 3 canciones del mismo género)
      const shouldChangeGenre = await this.shouldChangeToDifferentGenre(currentSongId, songGenres, userId);
      
      // 4. Buscar canciones: mismo género o diferente según corresponda
      const recommendation = shouldChangeGenre
        ? await this.getSongsFromDifferentGenre(songGenres, currentSongId, userId)
        : await this.getSongsByGenreAndPopularity(songGenres, currentSongId, userId);
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Recomendación simple completada en ${duration}ms: ${recommendation?.title || 'ninguna'}`);
      
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
   */
  private async getSongsByGenreAndPopularity(
    genres: string[],
    currentSongId: string,
    userId?: string
  ): Promise<Song | null> {
    try {
      // Obtener historial reciente (solo últimas 3 canciones)
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 3); // Solo últimas 3
      
      // Buscar canciones del mismo género, ordenadas por reproducciones
      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      // Filtrar por género usando LIKE (simple-array se guarda como texto)
      if (genres.length > 0) {
        const genreConditions = genres.map((_, index) => 
          `LOWER(song.genres) LIKE :genre${index}`
        ).join(' OR ');
        
        query.andWhere(`(${genreConditions})`);
        genres.forEach((genre, index) => {
          query.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
        });
      }

      // Excluir canciones muy recientes (solo últimas 3)
      if (recentIds.length > 0) {
        query.andWhere('song.id NOT IN (:...recentIds)', { recentIds: recentIds });
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
          .where('song.status = :status', { status: SongStatus.PUBLISHED })
          .andWhere('song.id != :currentId', { currentId: currentSongId })
          .andWhere('song.fileUrl IS NOT NULL')
          .andWhere('song.fileUrl != \'\'')
          .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
          .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

        if (genres.length > 0) {
          const genreConditions = genres.map((_, index) => 
            `LOWER(song.genres) LIKE :relaxedGenre${index}`
          ).join(' OR ');
          
          relaxedQuery.andWhere(`(${genreConditions})`);
          genres.forEach((genre, index) => {
            relaxedQuery.setParameter(`relaxedGenre${index}`, `%${genre.toLowerCase()}%`);
          });
        }

        relaxedQuery.orderBy('song.totalStreams', 'DESC').limit(10);
        songs = await relaxedQuery.getMany();
      }

      // Si aún no hay canciones, buscar cualquier canción popular
      if (songs.length === 0) {
        this.logger.log(`⚠️ No hay canciones del género, buscando cualquier canción popular...`);
        songs = await this.songRepository.find({
          where: {
            status: SongStatus.PUBLISHED,
            id: Not(currentSongId),
            fileUrl: Not(''),
          },
          relations: ['artist', 'album'],
          order: { totalStreams: 'DESC' },
          take: 10,
        });
      }

      if (songs.length === 0) {
        this.logger.warn(`❌ No se encontraron canciones para recomendar`);
        return null;
      }

      // Seleccionar una canción aleatoria de las top (diversidad)
      const topSongs = songs.slice(0, Math.min(5, songs.length)); // Top 5
      const randomSong = topSongs[Math.floor(Math.random() * topSongs.length)];

      this.logger.log(`✅ Recomendación seleccionada: ${randomSong.title} (${randomSong.totalStreams || 0} reproducciones)`);
      
      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones por género: ${error.message}`);
      return null;
    }
  }

  /**
   * 🎵 Buscar canciones populares cuando no hay géneros
   */
  private async getPopularSongs(
    currentSongId: string,
    userId?: string
  ): Promise<Song | null> {
    try {
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 3);

      const query = this.songRepository.createQueryBuilder('song')
        .leftJoinAndSelect('song.artist', 'artist')
        .leftJoinAndSelect('song.album', 'album')
        .where('song.status = :status', { status: SongStatus.PUBLISHED })
        .andWhere('song.id != :currentId', { currentId: currentSongId })
        .andWhere('song.fileUrl IS NOT NULL')
        .andWhere('song.fileUrl != \'\'')
        .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
        .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

      if (recentIds.length > 0) {
        query.andWhere('song.id NOT IN (:...recentIds)', { recentIds: recentIds });
      }

      const songs = await query
        .orderBy('song.totalStreams', 'DESC')
        .limit(10)
        .getMany();

      if (songs.length === 0) {
        return null;
      }

      const topSongs = songs.slice(0, Math.min(5, songs.length));
      const randomSong = topSongs[Math.floor(Math.random() * topSongs.length)];

      this.logger.log(`✅ Recomendación popular seleccionada: ${randomSong.title}`);
      return randomSong;
    } catch (error) {
      this.logger.error(`❌ Error buscando canciones populares: ${error.message}`);
      return null;
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
   * 🎵 Buscar canciones de OTROS géneros (diversidad)
   */
  private async getSongsFromDifferentGenre(
    excludeGenres: string[],
    currentSongId: string,
    userId?: string
  ): Promise<Song | null> {
    try {
      const recentSongs = this.getRecentHistory(userId || 'anonymous');
      const recentIds = recentSongs.slice(0, 3);

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

      // Excluir canciones recientes
      if (recentIds.length > 0) {
        query.andWhere('song.id NOT IN (:...recentIds)', { recentIds: recentIds });
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
          take: 10,
        });
      }

      if (songs.length === 0) {
        this.logger.warn(`❌ No se encontraron canciones de otros géneros`);
        return null;
      }

      // Seleccionar una canción aleatoria de las top 5
      const topSongs = songs.slice(0, Math.min(5, songs.length));
      const randomSong = topSongs[Math.floor(Math.random() * topSongs.length)];

      this.logger.log(`✅ Recomendación de otro género seleccionada: ${randomSong.title} (géneros: ${randomSong.genres?.join(', ') || 'ninguno'})`);
      
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
    genres?: string[]
  ): Promise<Song[]> {
    const strategies = [
      // Estrategia 1: Mismo género (peso alto)
      this.getSameGenreSongs(currentSong, genres),
      
      // Estrategia 2: Mismo artista (peso medio)
      this.getSameArtistSongs(currentSong),
      
      // Estrategia 3: Canciones populares similares (peso medio)
      this.getPopularSimilarSongs(currentSong),
      
      // Estrategia 4: Basado en historial de usuario (peso alto si hay userId)
      userId ? this.getUserBasedRecommendations(userId, currentSong) : Promise.resolve([]),
      
      // Estrategia 5: Trending songs del mismo género (peso bajo)
      this.getTrendingSongs(genres),
    ];

    const results = await Promise.all(strategies);
    
    // Combinar y deduplicar candidatos
    const allCandidates = results.flat();
    const uniqueCandidates = this.deduplicateSongs(allCandidates, currentSong.id);
    
    this.logger.log(`🎯 Candidatos encontrados: ${uniqueCandidates.length}`);
    return uniqueCandidates;
  }

  /**
   * 🎵 ESTRATEGIA 1: CANCIONES DEL MISMO GÉNERO
   */
  private async getSameGenreSongs(currentSong: Song, genres?: string[]): Promise<Song[]> {
    const targetGenres = genres || currentSong.genres || [];
    
    if (targetGenres.length === 0) return [];

    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.id != :currentId', { currentId: currentSong.id })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' });

    // Agregar condiciones de género
    const genreConditions = targetGenres.map((_, index) => 
      `LOWER(song.genres) LIKE :genre${index}`
    ).join(' OR ');
    
    if (genreConditions) {
      query.andWhere(`(${genreConditions})`);
      targetGenres.forEach((genre, index) => {
        query.setParameter(`genre${index}`, `%${genre.toLowerCase()}%`);
      });
    }

    const songs = await query
      .orderBy('song.totalStreams', 'DESC')
      .limit(15)
      .getMany();

    this.logger.log(`🎵 Mismo género: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 👤 ESTRATEGIA 2: CANCIONES DEL MISMO ARTISTA
   */
  private async getSameArtistSongs(currentSong: Song): Promise<Song[]> {
    if (!currentSong.artistId) return [];

    const songs = await this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .where('song.artistId = :artistId', { artistId: currentSong.artistId })
      .andWhere('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.id != :currentId', { currentId: currentSong.id })
      .andWhere('song.fileUrl IS NOT NULL')
      .andWhere('song.fileUrl != \'\'')
      .andWhere('song.fileUrl NOT LIKE :exampleUrl', { exampleUrl: '%example.com%' })
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
      .orderBy('song.totalStreams', 'DESC')
      .limit(10)
      .getMany();

    this.logger.log(`👤 Mismo artista: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 🔥 ESTRATEGIA 3: CANCIONES POPULARES SIMILARES
   */
  private async getPopularSimilarSongs(currentSong: Song): Promise<Song[]> {
    // Buscar canciones con streams similares (+/- 50% del actual)
    const minStreams = Math.max(0, currentSong.totalStreams * 0.5);
    const maxStreams = currentSong.totalStreams * 1.5;

    const songs = await this.songRepository.createQueryBuilder('song')
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
      .andWhere('song.fileUrl NOT LIKE :picsumUrl', { picsumUrl: '%picsum.photos%' })
      .orderBy('song.totalStreams', 'DESC')
      .limit(10)
      .getMany();

    this.logger.log(`🔥 Populares similares: ${songs.length} canciones`);
    return songs;
  }

  /**
   * 📊 ESTRATEGIA 4: BASADO EN HISTORIAL DE USUARIO
   * Collaborative Filtering básico
   */
  private async getUserBasedRecommendations(userId: string, currentSong: Song): Promise<Song[]> {
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
    const songs = await this.getSameGenreSongs(currentSong, topGenres);
    
    this.logger.log(`📊 Basado en usuario: ${songs.length} canciones (géneros: ${topGenres.join(', ')})`);
    return songs;
  }

  /**
   * 📈 ESTRATEGIA 5: CANCIONES TRENDING
   */
  private async getTrendingSongs(genres?: string[]): Promise<Song[]> {
    const query = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .leftJoinAndSelect('song.album', 'album')
      .where('song.status = :status', { status: SongStatus.PUBLISHED })
      .andWhere('song.createdAt >= :recentDate', { 
        recentDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // Últimos 30 días
      })
      .andWhere('song.fileUrl IS NOT NULL');

    if (genres && genres.length > 0) {
      const genreConditions = genres.map((_, index) => 
        `LOWER(song.genres) LIKE :trendGenre${index}`
      ).join(' OR ');
      
      query.andWhere(`(${genreConditions})`);
      genres.forEach((genre, index) => {
        query.setParameter(`trendGenre${index}`, `%${genre.toLowerCase()}%`);
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
   */
  private async applySimilarityScoring(
    currentSong: Song, 
    candidates: Song[], 
    userId?: string
  ): Promise<ScoredSong[]> {
    const scoredSongs: ScoredSong[] = [];

    for (const candidate of candidates) {
      let score = 0;
      const factors: ScoreFactor[] = [];

      // Factor 1: Similitud de género (peso: 40%)
      const genreScore = this.calculateGenreSimilarity(currentSong, candidate);
      score += genreScore * 0.4;
      factors.push({ name: 'género', score: genreScore, weight: 0.4 });

      // Factor 2: Popularidad relativa (peso: 25%)
      const popularityScore = this.calculatePopularityScore(currentSong, candidate);
      score += popularityScore * 0.25;
      factors.push({ name: 'popularidad', score: popularityScore, weight: 0.25 });

      // Factor 3: Mismo artista (peso: 15%)
      const artistScore = currentSong.artistId === candidate.artistId ? 1 : 0;
      score += artistScore * 0.15;
      factors.push({ name: 'artista', score: artistScore, weight: 0.15 });

      // Factor 4: Novedad (peso: 10%)
      const noveltyScore = this.calculateNoveltyScore(candidate);
      score += noveltyScore * 0.1;
      factors.push({ name: 'novedad', score: noveltyScore, weight: 0.1 });

      // Factor 5: Historial de usuario (peso: 10%)
      const userScore = userId ? await this.calculateUserAffinityScore(userId, candidate) : 0.5;
      score += userScore * 0.1;
      factors.push({ name: 'afinidad', score: userScore, weight: 0.1 });

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
   */
  private async calculateUserAffinityScore(userId: string, candidate: Song): Promise<number> {
    // Verificar si el usuario ya escuchó canciones del mismo artista
    const artistPlays = await this.playHistoryRepository.count({
      where: { 
        userId,
        song: { artistId: candidate.artistId }
      }
    });

    // Verificar si el usuario escuchó canciones del mismo género
    let genrePlays = 0;
    if (candidate.genres && candidate.genres.length > 0) {
      // Esta es una consulta simplificada, en producción sería más compleja
      genrePlays = await this.playHistoryRepository.count({
        where: { userId }
      });
    }

    // Combinar factores
    const artistAffinity = Math.min(1, artistPlays / 5); // Normalizar
    const genreAffinity = Math.min(1, genrePlays / 20); // Normalizar
    
    return (artistAffinity * 0.6 + genreAffinity * 0.4);
  }

  /**
   * 🎯 SELECCIONAR MEJOR RECOMENDACIÓN
   * Aplica diversidad y anti-repetición mejorada
   */
  private selectBestRecommendation(scoredSongs: ScoredSong[], userId?: string): Song | null {
    if (scoredSongs.length === 0) return null;

    // Aplicar diversidad: considerar más candidatos para mayor variedad
    const topCandidates = scoredSongs.slice(0, Math.min(8, scoredSongs.length));
    
    // Estrategia de selección más diversa
    const selectionStrategy = Math.random();
    
    if (selectionStrategy < 0.4) {
      // 40% - Weighted random selection (favorece los mejores)
      const weights = topCandidates.map(item => Math.pow(item.score, 1.5)); // Menos agresivo que antes
      const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
      
      if (totalWeight > 0) {
        let random = Math.random() * totalWeight;
        for (let i = 0; i < topCandidates.length; i++) {
          random -= weights[i];
          if (random <= 0) {
            this.logger.log(`🎯 Seleccionada (weighted): ${topCandidates[i].song.title} (posición ${i + 1}, score: ${topCandidates[i].score.toFixed(3)})`);
            return topCandidates[i].song;
          }
        }
      }
    } else if (selectionStrategy < 0.7) {
      // 30% - Selección de los top 3 con igual probabilidad
      const top3 = topCandidates.slice(0, Math.min(3, topCandidates.length));
      const selected = top3[Math.floor(Math.random() * top3.length)];
      this.logger.log(`🎯 Seleccionada (top3 random): ${selected.song.title} (score: ${selected.score.toFixed(3)})`);
      return selected.song;
    } else {
      // 30% - Selección completamente aleatoria de los top 8
      const selected = topCandidates[Math.floor(Math.random() * topCandidates.length)];
      this.logger.log(`🎯 Seleccionada (random): ${selected.song.title} (score: ${selected.score.toFixed(3)})`);
      return selected.song;
    }

    return topCandidates[0].song;
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
   */
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
