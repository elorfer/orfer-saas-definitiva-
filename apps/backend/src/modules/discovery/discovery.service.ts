import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Song, SongStatus } from '../../common/entities/song.entity';

/**
 * 🎵 DISCOVERY SERVICE - SIMPLIFICADO
 * 
 * Motor de recomendación basado en etiquetas (género).
 * Simple, rápido y confiable.
 * 
 * Lógica:
 * 1. Buscar canciones del mismo género
 * 2. Ordenar por fecha de subida (más nuevas) o reproducciones
 * 3. Si no hay del mismo género, elegir al azar de toda la biblioteca
 */
@Injectable()
export class DiscoveryService {
  private readonly logger = new Logger(DiscoveryService.name);

  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
  ) {}

  /**
   * 🎯 Obtener siguiente canción para autoplay
   * 
   * @param genreId - ID del género principal (opcional)
   * @param genreNames - Nombres de géneros (array de strings)
   * @param excludeIds - IDs a excluir (canción actual + historial reciente)
   * @param count - Número de canciones a retornar
   */
  async getNextUp(
    genreId: string | undefined,
    genreNames: string[],
    excludeIds: string[],
    count: number = 5,
  ): Promise<Song[]> {
    const excludeSet = new Set(excludeIds);

    // 1. Intentar buscar por género
    let songs: Song[] = [];

    if (genreId || genreNames.length > 0) {
      songs = await this.findByGenre(genreId, genreNames, excludeSet, count);
      this.logger.debug(`🎵 Encontradas ${songs.length} canciones del mismo género`);
    }

    // 2. Si no hay suficientes, completar con canciones populares/aleatorias
    if (songs.length < count) {
      const needed = count - songs.length;
      const existingIds = new Set([...excludeSet, ...songs.map(s => s.id)]);
      
      const fallback = await this.findFallback(existingIds, needed);
      songs = [...songs, ...fallback];
      
      if (fallback.length > 0) {
        this.logger.debug(`🎲 Añadidas ${fallback.length} canciones de fallback`);
      }
    }

    return songs;
  }

  /**
   * 🏷️ Buscar canciones por género
   */
  private async findByGenre(
    genreId: string | undefined,
    genreNames: string[],
    excludeIds: Set<string>,
    limit: number,
  ): Promise<Song[]> {
    const qb = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .where('song.status = :status', { status: SongStatus.PUBLISHED });

    // Excluir canciones
    if (excludeIds.size > 0) {
      qb.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds: Array.from(excludeIds) });
    }

    // Filtrar por género
    if (genreId) {
      qb.andWhere('song.genreId = :genreId', { genreId });
    } else if (genreNames.length > 0) {
      // Buscar en el array de géneros (simple-array en TypeORM)
      // Usar LIKE para buscar coincidencias en el array serializado
      const genreConditions = genreNames.map((_, i) => `song.genres LIKE :genre${i}`);
      qb.andWhere(`(${genreConditions.join(' OR ')})`);
      genreNames.forEach((genre, i) => {
        qb.setParameter(`genre${i}`, `%${genre}%`);
      });
    }

    // Ordenar: primero por fecha de subida (más nuevas), luego por reproducciones
    qb.orderBy('song.createdAt', 'DESC')
      .addOrderBy('song.totalStreams', 'DESC')
      .limit(limit);

    return qb.getMany();
  }

  /**
   * 🎲 Fallback: Canciones populares o aleatorias cuando no hay del mismo género
   */
  private async findFallback(
    excludeIds: Set<string>,
    limit: number,
  ): Promise<Song[]> {
    const qb = this.songRepository.createQueryBuilder('song')
      .leftJoinAndSelect('song.artist', 'artist')
      .where('song.status = :status', { status: SongStatus.PUBLISHED });

    if (excludeIds.size > 0) {
      qb.andWhere('song.id NOT IN (:...excludeIds)', { excludeIds: Array.from(excludeIds) });
    }

    // Mezclar: 50% más populares, 50% más nuevas
    // Usar RANDOM() para añadir variedad
    qb.orderBy('RANDOM()')
      .limit(limit * 2); // Pedir más y mezclar

    const candidates = await qb.getMany();

    // Mezclar y tomar lo necesario
    return candidates.slice(0, limit);
  }
}
