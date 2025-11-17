import { ApiProperty } from '@nestjs/swagger';

/**
 * DTO optimizado para respuestas de canciones en la app Flutter
 * Solo incluye los campos necesarios para evitar datos innecesarios
 */
export class SongResponseDto {
  @ApiProperty({ description: 'ID único de la canción' })
  id: string;

  @ApiProperty({ description: 'Título de la canción' })
  title: string;

  @ApiProperty({ description: 'Duración en segundos' })
  duration: number;

  @ApiProperty({ description: 'Duración formateada (MM:SS)' })
  durationFormatted: string;

  @ApiProperty({ description: 'URL del archivo de audio' })
  fileUrl: string;

  @ApiProperty({ description: 'URL de la portada', nullable: true })
  coverArtUrl?: string;

  @ApiProperty({ description: 'Indica si es contenido destacado' })
  featured: boolean;

  @ApiProperty({ description: 'Fecha de lanzamiento', nullable: true })
  releaseDate?: Date;

  @ApiProperty({ description: 'Total de reproducciones' })
  totalStreams: number;

  @ApiProperty({ description: 'Total de likes' })
  totalLikes: number;

  @ApiProperty({ description: 'Total de shares' })
  totalShares: number;

  @ApiProperty({ description: 'Fecha de creación' })
  createdAt: Date;

  @ApiProperty({ description: 'Información del artista' })
  artist: {
    id: string;
    stageName: string;
    avatarUrl?: string;
  };

  @ApiProperty({ description: 'Información del álbum', nullable: true })
  album?: {
    id: string;
    title: string;
    coverArtUrl?: string;
  };

  @ApiProperty({ description: 'Información del género', nullable: true })
  genre?: {
    id: string;
    name: string;
    colorHex?: string;
  };
}

/**
 * DTO para respuesta paginada de canciones
 */
export class PaginatedSongsResponseDto {
  @ApiProperty({ description: 'Lista de canciones', type: [SongResponseDto] })
  songs: SongResponseDto[];

  @ApiProperty({ description: 'Total de canciones disponibles' })
  total: number;

  @ApiProperty({ description: 'Página actual' })
  page: number;

  @ApiProperty({ description: 'Elementos por página' })
  limit: number;

  @ApiProperty({ description: 'Total de páginas' })
  totalPages: number;

  @ApiProperty({ description: 'Indica si hay página siguiente' })
  hasNext: boolean;

  @ApiProperty({ description: 'Indica si hay página anterior' })
  hasPrevious: boolean;
}

/**
 * DTO para el feed del home
 */
export class HomeFeedResponseDto {
  @ApiProperty({ description: 'Canciones destacadas', type: [SongResponseDto] })
  featured: SongResponseDto[];

  @ApiProperty({ description: 'Canciones nuevas', type: [SongResponseDto] })
  newSongs: SongResponseDto[];

  @ApiProperty({ description: 'Información de paginación' })
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
