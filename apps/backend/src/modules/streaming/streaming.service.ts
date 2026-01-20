import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Song } from '../../common/entities/song.entity';
import { User } from '../../common/entities/user.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';

@Injectable()
export class StreamingService {
  constructor(
    @InjectRepository(Song)
    private readonly songRepository: Repository<Song>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(PlayHistory)
    private readonly playHistoryRepository: Repository<PlayHistory>,
  ) { }

  async getStreamUrl(songId: string, userId: string): Promise<{ streamUrl: string; hlsUrl: string }> {
    const song = await this.songRepository.findOne({ where: { id: songId } });

    if (!song) {
      throw new NotFoundException('Canción no encontrada');
    }

    // ❌ REMOVED: No incrementar totalStreams aquí
    // El conteo correcto se hace en StreamsService.trackProgress()
    // después de validar que se escucharon al menos 30 segundos

    // ℹ️ Solo devolver la URL - el tracking se hace via /streams/track-progress

    return {
      streamUrl: song.fileUrl,
      hlsUrl: song.fileUrl.replace(/\.[^/.]+$/, '.m3u8'),
    };
  }

  async recordPlay(songId: string, userId: string, durationPlayed?: number): Promise<void> {
    const playHistory = this.playHistoryRepository.create({
      songId,
      userId,
      durationPlayed,
      completed: durationPlayed ? durationPlayed >= 30 : false, // Considerar completado si se reproduce al menos 30 segundos
    });

    await this.playHistoryRepository.save(playHistory);
  }

  async getUserPlayHistory(userId: string, page: number = 1, limit: number = 10): Promise<{ history: PlayHistory[]; total: number }> {
    const [history, total] = await this.playHistoryRepository.findAndCount({
      where: { userId },
      relations: ['song', 'song.artist'],
      skip: (page - 1) * limit,
      take: limit,
      order: { playedAt: 'DESC' },
    });

    return { history, total };
  }

  async getRecentlyPlayed(userId: string, limit: number = 10): Promise<Song[]> {
    const recentPlays = await this.playHistoryRepository.find({
      where: { userId },
      relations: ['song', 'song.artist'],
      order: { playedAt: 'DESC' },
      take: limit,
    });

    return recentPlays.map(play => play.song);
  }
}









