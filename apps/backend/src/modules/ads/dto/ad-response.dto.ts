import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AdStatus, AdTargeting } from '../../../common/entities/audio-ad.entity';

export class AdResponseDto {
  @ApiProperty({ description: 'ID del anuncio' })
  id: string;

  @ApiProperty({ description: 'Título del anuncio' })
  title: string;

  @ApiPropertyOptional({ description: 'Descripción del anuncio' })
  description?: string;

  @ApiProperty({ description: 'URL del archivo de audio' })
  audioUrl: string;

  @ApiPropertyOptional({ description: 'URL de la carátula del anuncio' })
  coverImageUrl?: string;

  @ApiProperty({ description: 'Nombre del anunciante' })
  advertiserName: string;

  @ApiPropertyOptional({ description: 'URL a abrir al hacer click en el anuncio' })
  clickThroughUrl?: string;

  @ApiProperty({ description: 'Duración del anuncio en segundos' })
  durationSeconds: number;

  @ApiProperty({ description: 'Tamaño del archivo en bytes' })
  fileSizeBytes: number;

  @ApiProperty({ description: 'Estado del anuncio', enum: AdStatus })
  status: AdStatus;

  @ApiProperty({ description: 'Tipo de targeting', enum: AdTargeting })
  targeting: AdTargeting;

  @ApiPropertyOptional({ description: 'Géneros objetivo', type: [String] })
  targetGenres?: string[];

  @ApiPropertyOptional({ description: 'Artistas objetivo', type: [String] })
  targetArtists?: string[];

  @ApiPropertyOptional({ description: 'Playlists objetivo', type: [String] })
  targetPlaylists?: string[];

  @ApiProperty({ description: 'Frecuencia máxima por hora' })
  frequencyPerHour: number;

  @ApiPropertyOptional({ description: 'Límite máximo de reproducciones por día' })
  maxPlaysPerDay?: number;

  @ApiPropertyOptional({ description: 'Fecha de inicio de la campaña' })
  startDate?: Date;

  @ApiPropertyOptional({ description: 'Fecha de fin de la campaña' })
  endDate?: Date;

  @ApiProperty({ description: 'Prioridad del anuncio (0-100)' })
  priority: number;

  @ApiProperty({ description: 'Si el anuncio puede ser saltado' })
  isSkippable: boolean;

  @ApiProperty({ description: 'Segundos antes de permitir skip' })
  skipAfterSeconds: number;

  @ApiProperty({ description: 'Total de reproducciones' })
  totalPlays: number;

  @ApiProperty({ description: 'Total de clicks' })
  totalClicks: number;

  @ApiProperty({ description: 'Fecha de creación' })
  createdAt: Date;

  @ApiProperty({ description: 'Fecha de actualización' })
  updatedAt: Date;
}









