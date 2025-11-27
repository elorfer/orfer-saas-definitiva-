import { Playlist } from '../../../common/entities/playlist.entity';

export interface PlaylistResponseDto {
  id: string;
  userId: string;
  name: string;
  description?: string;
  coverArtUrl?: string;
  visibility: string;
  isFeatured: boolean;
  totalTracks: number;
  totalFollowers: number;
  totalDuration: number;
  createdAt: Date;
  updatedAt: Date;
  user?: {
    id: string;
    email: string;
    username: string;
    firstName: string;
    lastName: string;
    avatarUrl?: string;
  };
  playlistSongs?: Array<{
    id: string;
    playlistId: string;
    songId: string;
    position: number;
    song?: {
      id: string;
      title: string;
      duration: number;
      fileUrl: string;
      coverArtUrl?: string;
      artistId?: string;
      artist?: {
        id: string;
        stageName: string;
        displayName?: string;
        bio?: string;
        avatarUrl?: string;
        totalStreams: number;
      };
      totalStreams: number;
      status: string;
    };
  }>;
}

export class PlaylistMapper {
  private static getBaseUrl(): string {
    return process.env.APP_URL || process.env.BASE_URL || 'http://localhost:3001';
  }

  /**
   * Transforma una entidad Playlist a PlaylistResponseDto
   * Convierte snake_case a camelCase y asegura que las URLs estén correctas
   */
  static toResponseDto(playlist: Playlist): PlaylistResponseDto {
    // Normalizar coverArtUrl si existe
    let coverArtUrl = playlist.coverArtUrl;
    
    // Si coverArtUrl es una ruta relativa, construir URL completa
    if (coverArtUrl && coverArtUrl.trim().length > 0 && !coverArtUrl.startsWith('http://') && !coverArtUrl.startsWith('https://')) {
      const baseUrl = this.getBaseUrl();
      
      // Si ya tiene /uploads/, mantenerlo
      if (coverArtUrl.startsWith('/uploads/')) {
        coverArtUrl = `${baseUrl}${coverArtUrl}`;
      } else if (coverArtUrl.startsWith('/')) {
        coverArtUrl = `${baseUrl}${coverArtUrl}`;
      } else {
        // Si es solo el nombre del archivo, agregar la ruta completa
        coverArtUrl = `${baseUrl}/uploads/covers/${coverArtUrl}`;
      }
    }
    
    // Asegurar que coverArtUrl sea undefined si está vacío o null
    if (!coverArtUrl || coverArtUrl.trim().length === 0) {
      coverArtUrl = undefined;
    }

    // Filtrar solo canciones publicadas y válidas
    const publishedSongs = playlist.playlistSongs
      ?.filter(ps => ps.song != null && ps.song.status === 'published') || [];
    
    // Recalcular totalTracks y totalDuration basados solo en canciones publicadas
    const actualTotalTracks = publishedSongs.length;
    const actualTotalDuration = publishedSongs.reduce(
      (total, ps) => total + (ps.song?.duration || 0),
      0
    );

    // Normalizar nombre: si está vacío, null, o es "Sin nombre", usar null para que el frontend muestre "Playlist"
    const normalizedName = playlist.name?.trim();
    const finalName = (normalizedName && normalizedName.length > 0 && normalizedName.toLowerCase() !== 'sin nombre') 
      ? normalizedName 
      : null; // null será convertido a string vacío o manejado por el frontend

    // Crear objeto DTO directamente en formato camelCase
    const dto: PlaylistResponseDto = {
      id: playlist.id,
      userId: playlist.userId,
      name: finalName || '', // Si es null, usar string vacío para que el frontend lo maneje
      description: playlist.description || undefined,
      coverArtUrl: coverArtUrl || undefined,
      visibility: playlist.visibility,
      isFeatured: playlist.isFeatured === true, // Asegurar que sea boolean explícito
      totalTracks: actualTotalTracks, // Usar el total real de canciones publicadas
      totalFollowers: playlist.totalFollowers ?? 0,
      totalDuration: actualTotalDuration, // Usar la duración real de canciones publicadas
      createdAt: playlist.createdAt,
      updatedAt: playlist.updatedAt,
      user: playlist.user ? {
        id: playlist.user.id,
        email: playlist.user.email,
        username: playlist.user.username,
        firstName: playlist.user.firstName,
        lastName: playlist.user.lastName,
        avatarUrl: playlist.user.avatarUrl,
      } : undefined,
      playlistSongs: publishedSongs.length > 0 ? publishedSongs.map(ps => ({
          id: ps.id,
          playlistId: ps.playlistId,
          songId: ps.songId,
          position: ps.position,
          song: ps.song ? {
            id: ps.song.id,
            title: ps.song.title ?? '',
            duration: ps.song.duration ?? 0,
            fileUrl: ps.song.fileUrl ?? '',
            coverArtUrl: this.normalizeSongCoverUrl(ps.song.coverArtUrl),
            artistId: ps.song.artistId,
            artist: ps.song.artist ? {
              id: ps.song.artist.id,
              stageName: ps.song.artist.stageName ?? '',
              displayName: ps.song.artist.displayName,
              bio: ps.song.artist.bio,
              avatarUrl: (ps.song.artist as any).profilePhotoUrl,
              totalStreams: ps.song.artist.totalStreams ?? 0,
            } : undefined,
            totalStreams: ps.song.totalStreams ?? 0,
            status: ps.song.status,
          } : undefined,
        })).filter(ps => ps.song != null) : [],
    };

    return dto;
  }

  /**
   * Normaliza la URL de portada de una canción
   */
  private static normalizeSongCoverUrl(coverArtUrl?: string): string | undefined {
    if (!coverArtUrl) return undefined;

    // Si ya es una URL completa, devolverla tal cual
    if (coverArtUrl.startsWith('http://') || coverArtUrl.startsWith('https://')) {
      return coverArtUrl;
    }

    // Construir URL completa desde ruta relativa
    const baseUrl = this.getBaseUrl();
    
    if (coverArtUrl.startsWith('/uploads/')) {
      return `${baseUrl}${coverArtUrl}`;
    }
    
    if (coverArtUrl.startsWith('/')) {
      return `${baseUrl}${coverArtUrl}`;
    }

    // Si es solo el nombre del archivo
    return `${baseUrl}/uploads/covers/${coverArtUrl}`;
  }

  /**
   * Transforma un array de playlists a DTOs
   */
  static toResponseDtoArray(playlists: Playlist[]): PlaylistResponseDto[] {
    return playlists.map(playlist => this.toResponseDto(playlist));
  }
}

