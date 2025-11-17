import { Song } from '../../../common/entities/song.entity';
import { SongResponseDto } from '../dto/song-response.dto';

/**
 * Mapper para convertir entidades Song a DTOs optimizados para Flutter
 * Elimina datos innecesarios y formatea la respuesta
 */
export class SongMapper {
  /**
   * Convierte una entidad Song a SongResponseDto
   */
  static toDto(song: Song): SongResponseDto {
    return {
      id: song.id,
      title: song.title,
      duration: song.duration,
      durationFormatted: this.formatDuration(song.duration),
      fileUrl: song.fileUrl,
      coverArtUrl: song.coverArtUrl || undefined,
      featured: song.isFeatured,
      releaseDate: song.releaseDate || undefined,
      totalStreams: song.totalStreams || 0,
      totalLikes: song.totalLikes || 0,
      totalShares: song.totalShares || 0,
      createdAt: song.createdAt,
      artist: {
        id: song.artist?.id || song.artistId,
        stageName: song.artist?.stageName || 'Artista desconocido',
        avatarUrl: song.artist?.user?.avatarUrl || undefined,
      },
      album: song.album
        ? {
            id: song.album.id,
            title: song.album.title,
            coverArtUrl: song.album.coverArtUrl || undefined,
          }
        : undefined,
      genre: song.genre
        ? {
            id: song.genre.id,
            name: song.genre.name,
            colorHex: song.genre.colorHex || undefined,
          }
        : undefined,
    };
  }

  /**
   * Convierte un array de entidades Song a array de SongResponseDto
   */
  static toDtoArray(songs: Song[]): SongResponseDto[] {
    return songs.map((song) => this.toDto(song));
  }

  /**
   * Formatea la duración de segundos a MM:SS
   */
  private static formatDuration(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }
}
