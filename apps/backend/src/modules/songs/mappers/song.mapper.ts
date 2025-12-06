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
    const dto: any = {
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
        displayName: song.artist?.stageName || song.artist?.name || 'Artista desconocido',
        avatarUrl: song.artist?.user?.avatarUrl || undefined,
        profilePhotoUrl: song.artist?.profilePhotoUrl || song.artist?.user?.avatarUrl || undefined,
        verificationStatus: song.artist?.verificationStatus ?? false,
        isVerified: song.artist?.isVerified ?? song.artist?.verificationStatus ?? false,
        // Campos en snake_case para compatibilidad con Flutter
        verification_status: song.artist?.verificationStatus ?? false,
        is_verified: song.artist?.isVerified ?? song.artist?.verificationStatus ?? false,
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
      // Asegurar que genres sea siempre un array, incluso si TypeORM lo serializa como string (simple-array)
      genres: this.normalizeGenres(song.genres),
    };
    
    // ✅ CORRECCIÓN: Agregar también snake_case para compatibilidad con Flutter
    // Flutter espera total_streams debido a @JsonSerializable(fieldRename: FieldRename.snake)
    dto.total_streams = dto.totalStreams;
    dto.total_likes = dto.totalLikes;
    dto.total_shares = dto.totalShares;
    
    return dto as SongResponseDto;
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

  /**
   * Normaliza los géneros para asegurar que siempre sea un array de strings
   * Maneja el caso donde TypeORM simple-array puede serializarse como string
   */
  private static normalizeGenres(genres: string[] | string | null | undefined): string[] | undefined {
    if (!genres) {
      return undefined;
    }
    
    if (Array.isArray(genres)) {
      // Si ya es un array, filtrar valores vacíos y retornar
      const filtered = genres.filter(g => g && g.trim().length > 0);
      return filtered.length > 0 ? filtered : undefined;
    }
    
    if (typeof genres === 'string') {
      // Si es un string (simple-array serializado), dividir por comas
      const split = genres.split(',').map(g => g.trim()).filter(g => g.length > 0);
      return split.length > 0 ? split : undefined;
    }
    
    return undefined;
  }
}
