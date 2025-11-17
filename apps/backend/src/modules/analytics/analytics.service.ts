import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';

import { Song } from '../../common/entities/song.entity';
import { Artist } from '../../common/entities/artist.entity';
import { StreamingStats } from '../../common/entities/streaming-stats.entity';
import { PlayHistory } from '../../common/entities/play-history.entity';

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
  ) {}

  async getGlobalStats(): Promise<any> {
    const totalSongs = await this.songRepository.count();
    const totalArtists = await this.artistRepository.count();
    const totalStreams = await this.songRepository
      .createQueryBuilder('song')
      .select('SUM(song.totalStreams)', 'total')
      .getRawOne();

    return {
      totalSongs,
      totalArtists,
      totalStreams: parseInt(totalStreams.total) || 0,
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
}









