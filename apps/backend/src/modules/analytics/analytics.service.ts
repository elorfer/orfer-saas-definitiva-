import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, MoreThanOrEqual } from 'typeorm';

import { Song, SongStatus } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { StreamingStats } from '../../common/entities/streaming-stats.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { Genre } from '../../common/entities/genre.entity';
import { User } from '../../common/entities/user.entity';

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(Artist)
    private readonly artistRepository: Repository<Artist>,
    @InjectRepository(StreamingStats)
    private readonly streamingStatsRepository: Repository<StreamingStats>,
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) { }

  async getGlobalStats(): Promise<any> {
    const totalSongs = await this.songRepository.count();
    const totalArtists = await this.artistRepository.count();

    // Contar usuarios
    const totalUsers = await this.userRepository.count();
    const verifiedUsers = await this.userRepository.count({
      where: { isVerified: true },
    });
    const activeUsers = await this.userRepository.count({
      where: { isActive: true },
    });

    // Contar artistas destacados (contar con cualquiera de los dos campos)
    const featuredArtistsWithIsFeatured = await this.artistRepository.count({
      where: { isFeatured: true },
    });
    const featuredArtistsWithFeatured = await this.artistRepository.count({
      where: { featured: true },
    });
    // Usar el mayor de los dos (por si hay inconsistencias)
    const featuredArtists = Math.max(featuredArtistsWithIsFeatured, featuredArtistsWithFeatured);

    // Contar canciones publicadas
    const publishedSongs = await this.songRepository.count({
      where: { status: SongStatus.PUBLISHED },
    });

    // 🐛 DEBUG: Verificar qué está pasando con totalStreams
    const totalStreamsRaw = await this.songRepository
      .createQueryBuilder('song')
      .select('COALESCE(SUM(song.total_streams), 0)', 'total')
      .getRawOne();

    console.log('[getGlobalStats] totalStreamsRaw:', totalStreamsRaw);

    const totalStreams = parseInt(totalStreamsRaw?.total || '0') || 0;
    console.log('[getGlobalStats] totalStreams parsed:', totalStreams);

    return {
      totalSongs,
      totalArtists,
      totalUsers,
      totalStreams,
      verifiedUsers,
      activeUsers,
      featuredArtists,
      publishedSongs,
    };
  }

  async getArtistAnalytics(artistId: string, startDate?: Date, endDate?: Date): Promise<any> {
    const artist = await this.artistRepository.findOne({ where: { id: artistId } });
    if (!artist) {
      throw new Error('Artista no encontrado');
    }

    const whereCondition: any = { artistId };
    if (startDate && endDate) {
      whereCondition.createdAt = Between(startDate, endDate);
    }

    const songs = await this.songRepository.find({ where: whereCondition });
    const totalStreams = songs.reduce((sum, song) => sum + song.totalStreams, 0);
    const totalLikes = songs.reduce((sum, song) => sum + song.totalLikes, 0);

    return {
      artist,
      totalSongs: songs.length,
      totalStreams,
      totalLikes,
      averageStreamsPerSong: songs.length > 0 ? totalStreams / songs.length : 0,
    };
  }

  async getSongAnalytics(songId: string, startDate?: Date, endDate?: Date): Promise<any> {
    const song = await this.songRepository.findOne({
      where: { id: songId },
      relations: ['artist'],
    });

    if (!song) {
      throw new Error('Canción no encontrada');
    }

    const whereCondition: any = { songId };
    if (startDate && endDate) {
      whereCondition.playedAt = Between(startDate, endDate);
    }

    const playHistory = await this.playHistoryRepository.find({ where: whereCondition });
    const totalPlays = playHistory.length;
    const completedPlays = playHistory.filter(play => play.completed).length;
    const completionRate = totalPlays > 0 ? (completedPlays / totalPlays) * 100 : 0;

    return {
      song,
      totalPlays,
      completedPlays,
      completionRate,
      totalStreams: song.totalStreams,
      totalLikes: song.totalLikes,
    };
  }

  async getTopSongs(limit: number = 10, startDate?: Date, endDate?: Date): Promise<Song[]> {
    const whereCondition: any = {};
    if (startDate && endDate) {
      whereCondition.createdAt = Between(startDate, endDate);
    }

    return this.songRepository.find({
      where: whereCondition,
      relations: ['artist'],
      order: { totalStreams: 'DESC' },
      take: limit,
    });
  }

  async getTopArtists(limit: number = 10): Promise<Artist[]> {
    return this.artistRepository.find({
      relations: ['user'],
      order: { totalStreams: 'DESC' },
      take: limit,
    });
  }

  async getStreamingStatsByDate(songId: string, startDate: Date, endDate: Date): Promise<StreamingStats[]> {
    return this.streamingStatsRepository.find({
      where: {
        songId,
        date: Between(startDate, endDate),
      },
      order: { date: 'ASC' },
    });
  }

  /**
   * Obtener reproducciones diarias de los últimos N días
   * 🔥 FIX: Ahora usa la tabla 'streams' en lugar de 'play_history'
   * para mostrar el conteo correcto (1 stream por canción por sesión)
   */
  async getDailyStreams(days: number = 7): Promise<Array<{ date: string; count: number }>> {
    const now = new Date();
    const startDate = new Date(now);
    startDate.setDate(now.getDate() - (days - 1));
    startDate.setHours(0, 0, 0, 0);

    // 🔥 FIX: Usar tabla 'streams' en lugar de 'play_history'
    // streams = 1 por canción por sesión (conteo correcto)
    // play_history = múltiples checkpoints por sesión (inflado)
    const streamsByDate = await this.playHistoryRepository.manager.query(`
      SELECT DATE(created_at - INTERVAL '5 hours') as date, COUNT(*) as count
      FROM streams 
      GROUP BY DATE(created_at - INTERVAL '5 hours')
      ORDER BY DATE(created_at - INTERVAL '5 hours') ASC
    `);

    // Función auxiliar para formatear fecha (YYYY-MM-DD)
    const formatDate = (date: Date): string => {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    };

    // Crear mapa de fechas para los últimos N días
    const dateMap = new Map<string, number>();
    for (let i = 0; i < days; i++) {
      const date = new Date(startDate);
      date.setDate(startDate.getDate() + i);
      const dateStr = formatDate(date);
      dateMap.set(dateStr, 0);
    }

    // Llenar con datos reales
    streamsByDate.forEach((item: any) => {
      const dbDate = new Date(item.date);
      const dateStr = formatDate(dbDate);
      if (dateMap.has(dateStr)) {
        dateMap.set(dateStr, parseInt(item.count) || 0);
      }
    });

    // Ordenar por fecha
    return Array.from(dateMap.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, count]) => ({
        date,
        count,
      }));
  }

  /**
   * Obtener usuarios activos diarios de los últimos N días
   */
  async getDailyActiveUsers(days: number = 7): Promise<Array<{ date: string; count: number }>> {
    const now = new Date();
    const startDate = new Date(now);
    startDate.setDate(now.getDate() - (days - 1));
    startDate.setHours(0, 0, 0, 0);

    // 🎯 Consulta SQL con ajuste de zona horaria (UTC-5)
    const activeUsers = await this.playHistoryRepository.query(`
      SELECT DATE(played_at - INTERVAL '5 hours') as date, COUNT(DISTINCT user_id) as count
      FROM play_history 
      GROUP BY DATE(played_at - INTERVAL '5 hours')
      ORDER BY DATE(played_at - INTERVAL '5 hours') ASC
    `);

    // Función auxiliar para formatear fecha
    const formatDate = (date: Date): string => {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    };

    // Crear un mapa para todas las fechas del período
    const dateMap = new Map<string, number>();
    for (let i = 0; i < days; i++) {
      const date = new Date(startDate);
      date.setDate(startDate.getDate() + i);
      const dateStr = formatDate(date);
      dateMap.set(dateStr, 0);
    }

    // Llenar con datos reales
    activeUsers.forEach((item: any) => {
      const date = new Date(item.date);
      const dateStr = formatDate(date);
      if (dateMap.has(dateStr)) {
        dateMap.set(dateStr, parseInt(item.count) || 0);
      }
    });

    return Array.from(dateMap.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, count]) => ({
        date,
        count,
      }));
  }

  /**
   * Obtener distribución de reproducciones por género
   */
  async getGenreDistribution(limit: number = 5): Promise<Array<{ genre: string; count: number; percentage: number }>> {
    const songs = await this.songRepository.find({
      where: { status: SongStatus.PUBLISHED },
      relations: ['genre'],
    });

    const genreMap = new Map<string, number>();
    let totalStreams = 0;

    songs.forEach((song) => {
      const streams = song.totalStreams || 0;
      if (streams === 0) return; // Ignorar canciones sin reproducciones

      // Priorizar géneros del array si existe y tiene valores
      if (song.genres && Array.isArray(song.genres) && song.genres.length > 0) {
        const validGenres = song.genres.filter(g => g && g.trim());
        if (validGenres.length > 0) {
          // Si tiene múltiples géneros, distribuir las reproducciones
          const streamsPerGenre = streams / validGenres.length;
          validGenres.forEach((genreName: string) => {
            const normalizedGenre = genreName.trim().toUpperCase();
            genreMap.set(normalizedGenre, (genreMap.get(normalizedGenre) || 0) + streamsPerGenre);
          });
          totalStreams += streams;
          return;
        }
      }

      // Si no hay géneros en el array, usar el género de la relación
      if (song.genre && song.genre.name) {
        const normalizedGenre = song.genre.name.trim().toUpperCase();
        genreMap.set(normalizedGenre, (genreMap.get(normalizedGenre) || 0) + streams);
        totalStreams += streams;
      } else {
        // Solo agregar "Sin género" si realmente no tiene género
        genreMap.set('Sin género', (genreMap.get('Sin género') || 0) + streams);
        totalStreams += streams;
      }
    });

    // Crear distribución inicial con todos los géneros
    let distribution = Array.from(genreMap.entries())
      .map(([genre, count]) => ({
        genre,
        count: Math.round(count * 100) / 100,
        percentage: totalStreams > 0 ? (count / totalStreams) * 100 : 0,
      }))
      .sort((a, b) => b.count - a.count);

    // Filtrar "Sin género" si hay otros géneros con datos
    const hasOtherGenres = distribution.some(item => item.genre !== 'Sin género' && item.count > 0);
    if (hasOtherGenres) {
      // Si hay otros géneros, excluir "Sin género" completamente
      distribution = distribution.filter(item => item.genre !== 'Sin género');
    }

    // Recalcular total después de filtrar
    const filteredTotal = distribution.reduce((sum, item) => sum + item.count, 0);

    // Recalcular porcentajes basados en el total filtrado
    if (filteredTotal > 0) {
      distribution = distribution.map(item => ({
        ...item,
        percentage: (item.count / filteredTotal) * 100,
      }));
    }

    // Limitar resultados
    distribution = distribution.slice(0, limit);

    // Ajustar porcentajes para que sumen exactamente 100%
    const totalPercentage = distribution.reduce((sum, item) => sum + item.percentage, 0);
    if (totalPercentage > 0 && Math.abs(totalPercentage - 100) > 0.01) {
      const adjustmentFactor = 100 / totalPercentage;
      distribution = distribution.map(item => ({
        ...item,
        percentage: Math.round(item.percentage * adjustmentFactor * 10) / 10,
      }));
    }

    return distribution;
  }

  /**
   * Obtener horas pico de actividad
   */
  async getPeakHours(): Promise<Array<{ hour: number; count: number }>> {
    const last30Days = new Date();
    last30Days.setDate(last30Days.getDate() - 30);
    last30Days.setHours(0, 0, 0, 0);

    const hourlyStats = await this.playHistoryRepository
      .createQueryBuilder('ph')
      .select('EXTRACT(HOUR FROM ph.played_at)', 'hour')
      .addSelect('COUNT(*)', 'count')
      .where('ph.played_at >= :last30Days', { last30Days })
      .groupBy('EXTRACT(HOUR FROM ph.played_at)')
      .orderBy('EXTRACT(HOUR FROM ph.played_at)', 'ASC')
      .getRawMany();

    // Crear un mapa para todas las 24 horas
    const hourMap = new Map<number, number>();
    for (let i = 0; i < 24; i++) {
      hourMap.set(i, 0);
    }

    // Llenar con datos reales
    hourlyStats.forEach((item: any) => {
      const hour = parseInt(item.hour);
      hourMap.set(hour, parseInt(item.count) || 0);
    });

    return Array.from(hourMap.entries())
      .map(([hour, count]) => ({
        hour,
        count,
      }))
      .sort((a, b) => a.hour - b.hour);
  }

  /**
   * 🔄 Reiniciar todas las estadísticas del dashboard
   * Esta función elimina todo el historial de reproducciones y reinicia los contadores de streams
   */
  async resetStats(): Promise<{ message: string; details: any }> {
    // Obtener el DataSource para usar transacciones
    const dataSource = this.songRepository.manager.connection;
    const queryRunner = dataSource.createQueryRunner();

    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      console.log('[resetStats] Iniciando reinicio de estadísticas...');

      // 1. Contar registros antes de eliminar
      const playHistoryCount = await this.playHistoryRepository.count();
      const streamingStatsCount = await this.streamingStatsRepository.count();
      const songsCount = await this.songRepository.count();
      const artistsCount = await this.artistRepository.count();

      console.log(`[resetStats] Datos a procesar: PlayHistory=${playHistoryCount}, StreamingStats=${streamingStatsCount}, Songs=${songsCount}, Artists=${artistsCount}`);

      // 2. Eliminar todo el historial de reproducciones usando SQL directo para evitar FK issues
      console.log('[resetStats] Eliminando play_history...');
      await queryRunner.query('DELETE FROM play_history');
      console.log('[resetStats] play_history eliminado');

      // 3. Eliminar estadísticas de streaming usando SQL directo
      console.log('[resetStats] Eliminando streaming_stats...');
      await queryRunner.query('DELETE FROM streaming_stats');
      console.log('[resetStats] streaming_stats eliminado');

      // 4. Reiniciar contadores en todas las canciones
      console.log('[resetStats] Reiniciando contadores de canciones...');
      await queryRunner.query('UPDATE songs SET total_streams = 0, total_likes = 0');
      console.log('[resetStats] Contadores de canciones reiniciados');

      // 5. Reiniciar contadores en todos los artistas
      console.log('[resetStats] Reiniciando contadores de artistas...');
      await queryRunner.query('UPDATE artists SET total_streams = 0');
      console.log('[resetStats] Contadores de artistas reiniciados');

      // Confirmar transacción
      await queryRunner.commitTransaction();
      console.log('[resetStats] Transacción completada exitosamente');

      return {
        message: 'Estadísticas reiniciadas exitosamente',
        details: {
          playHistoryDeleted: playHistoryCount,
          streamingStatsDeleted: streamingStatsCount,
          songsReset: songsCount,
          artistsReset: artistsCount,
        },
      };
    } catch (error) {
      // Rollback en caso de error
      await queryRunner.rollbackTransaction();
      console.error('[resetStats] Error reiniciando estadísticas:', error);
      console.error('[resetStats] Error details:', error.stack || error.message || error);
      throw new Error(`Error al reiniciar las estadísticas: ${error.message || 'Error desconocido'}`);
    } finally {
      // Liberar el queryRunner
      await queryRunner.release();
    }
  }
}









