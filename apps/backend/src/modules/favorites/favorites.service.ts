import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { SongLike } from '../../common/entities/song-like.entity';
import { Song } from '../../common/entities/song.entity';
import { User } from '../../common/entities/user.entity';
import { SongMapper } from '../songs/mappers/song.mapper';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(SongLike)
    private readonly songLikeRepository: Repository<SongLike>,
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  /**
   * Toggle de favorito: agregar o remover canción de favoritos
   * Retorna true si se agregó, false si se removió
   */
  async toggleFavorite(userId: string, songId: string): Promise<{ isFavorite: boolean }> {
    // Verificar que la canción existe
    const song = await this.songRepository.findOne({ where: { id: songId } });
    if (!song) {
      throw new NotFoundException(`Canción con ID ${songId} no encontrada`);
    }

    // Verificar si ya es favorita
    const existingLike = await this.songLikeRepository.findOne({
      where: { userId, songId },
    });

    if (existingLike) {
      // Remover de favoritos
      await this.songLikeRepository.remove(existingLike);
      
      // Decrementar contador de likes en la canción
      song.decrementLikes();
      await this.songRepository.save(song);

      return { isFavorite: false };
    } else {
      // Agregar a favoritos
      const newLike = this.songLikeRepository.create({
        userId,
        songId,
      });
      await this.songLikeRepository.save(newLike);

      // Incrementar contador de likes en la canción
      song.incrementLikes();
      await this.songRepository.save(song);

      return { isFavorite: true };
    }
  }

  /**
   * Obtener todas las canciones favoritas del usuario
   */
  async getMyFavorites(userId: string): Promise<{ songs: any[] }> {
    const likes = await this.songLikeRepository.find({
      where: { userId },
      relations: ['song', 'song.artist', 'song.artist.user', 'song.album', 'song.genre'],
      order: { likedAt: 'DESC' },
    });

    // Mapear a DTOs usando el mapper de canciones
    const songs = likes
      .map((like) => like.song)
      .filter((song) => song != null)
      .map((song) => SongMapper.toDto(song));

    return { songs };
  }

  /**
   * Verificar si una canción es favorita del usuario
   */
  async isFavorite(userId: string, songId: string): Promise<boolean> {
    const like = await this.songLikeRepository.findOne({
      where: { userId, songId },
    });
    return !!like;
  }
}

